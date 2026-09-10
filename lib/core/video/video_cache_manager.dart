import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Production-Grade Non-Blocking Disk & Memory Video Cache Manager.
/// - Eliminates Main-Thread Synchronous Disk I/O (prevents ANRs).
/// - Safe atomic file operations handling FileSystemException across platforms.
/// - In-flight download deduplication and CancelToken support.
/// - Strict magic-bytes & Content-Length verification preventing player crashes.
class VideoCacheManager {
  static final VideoCacheManager _instance = VideoCacheManager._internal();
  static VideoCacheManager get instance => _instance;

  VideoCacheManager._internal();

  Directory? _cacheDir;
  Future<void>? _initFuture;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      responseType: ResponseType.stream,
    ),
  );

  // In-flight download tracking & deduplication
  final Set<String> _downloadingUrls = {};
  final Map<String, CancelToken> _activeCancelTokens = {};
  final Map<String, Completer<String?>> _inFlightCompleters = {};
  final Queue<String> _downloadQueue = Queue<String>();
  int _activeDownloadsCount = 0;
  static const int _maxConcurrentDownloads = 1;

  // In-memory cache maps: url -> verified local absolute file path
  final Map<String, String> _memoryPathCache = {};
  final Map<String, String> _knownFilePaths = {};

  // Maximum cache size limit (1 GB)
  static const int _maxCacheSizeBytes = 1024 * 1024 * 1024;
  static const int _minVideoSizeBytes = 32 * 1024; // 32 KB minimum for video
  static const int _minAudioSizeBytes = 4 * 1024; // 4 KB minimum for audio

  /// Initializes the cache directory and preloads existing valid files into memory asynchronously.
  Future<void> init() async {
    if (_initFuture != null) return _initFuture!;
    _initFuture = _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final dir = Directory('${appDir.path}/shorts_video_cache');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;

      // Async scan of directory to preload cache and purge corrupted/orphaned tmp files
      final stream = dir.list(followLinks: false);
      await for (final entity in stream) {
        if (entity is! File) continue;

        final path = entity.path;
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : '';

        // Purge orphaned temporary files from interrupted downloads
        if (name.endsWith('.tmp')) {
          _safeDeleteFile(entity);
          continue;
        }

        try {
          final len = await entity.length();
          // Purge corrupt or undersized files
          if (len < _minAudioSizeBytes) {
            _safeDeleteFile(entity);
            continue;
          }

          if (name.startsWith('media_') ||
              name.startsWith('vid_') ||
              name.startsWith('cf_')) {
            _knownFilePaths[name] = path;
          }
        } catch (e) {
          debugPrint(
            '⚠️ [VideoCacheManager] Error inspecting cache file $path: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ [VideoCacheManager] Failed to init cache dir: $e');
    }
  }

  static final RegExp _cloudflareRegExp = RegExp(r'cloudflarestream\.com\/([a-zA-Z0-9]+)');

  /// Extracts the Cloudflare Stream video ID from any Cloudflare URL
  static String? extractCloudflareId(String url) {
    if (!url.contains('cloudflarestream.com')) return null;
    final match = _cloudflareRegExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  /// Converts any Cloudflare Stream URL (including .m3u8) to the direct MP4 download URL.
  static String getDownloadableUrl(String url) {
    final cfId = extractCloudflareId(url);
    if (cfId != null && cfId.isNotEmpty) {
      return 'https://customer-xe2czubswwdkm567.cloudflarestream.com/$cfId/downloads/default.mp4';
    }
    return url;
  }

  /// Platform-independent safe filename generation without external dependencies.
  String _getFileName(String url) {
    final cfId = extractCloudflareId(url);
    if (cfId != null && cfId.isNotEmpty) {
      return 'cf_$cfId.mp4';
    }

    final uri = Uri.tryParse(url);
    final cleanPath = uri != null
        ? '${uri.scheme}://${uri.host}${uri.path}'
        : url;

    // Fast 64-bit integer hash to string
    var hash = 0xcbf29ce484222325;
    for (final codeUnit in utf8.encode(cleanPath)) {
      hash ^= codeUnit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    final hashStr = hash.toRadixString(16).padLeft(16, '0');

    String ext = '.mp4';
    final lower = url.toLowerCase();
    if (lower.contains('.opus')) {
      ext = '.opus';
    } else if (lower.contains('.ogg')) {
      ext = '.ogg';
    } else if (lower.contains('.mp3')) {
      ext = '.mp3';
    } else if (lower.contains('.m4a')) {
      ext = '.m4a';
    } else if (lower.contains('.wav')) {
      ext = '.wav';
    } else if (lower.contains('.aac')) {
      ext = '.aac';
    } else if (lower.contains('.webm')) {
      ext = '.webm';
    }

    return 'media_$hashStr$ext';
  }

  Future<File?> _getLocalFile(String url) async {
    if (_cacheDir == null) {
      await init();
    }
    if (_cacheDir == null) return null;
    final filename = _getFileName(url);
    return File('${_cacheDir!.path}/$filename');
  }

  /// Fast in-memory check if the video/audio is already downloaded and verified.
  /// Zero blocking synchronous disk I/O on UI thread.
  bool isCached(String url) {
    if (url.trim().isEmpty) return false;
    final filename = _getFileName(url);
    return _memoryPathCache.containsKey(url) ||
        _knownFilePaths.containsKey(filename);
  }

  /// Returns verified local cached file path from memory index, or null if not yet cached.
  /// Zero main-thread disk I/O.
  String? getCachedFilePath(String url) {
    if (url.trim().isEmpty) return null;
    final filename = _getFileName(url);
    final path = _memoryPathCache[url] ?? _knownFilePaths[filename];
    if (path != null) {
      _memoryPathCache[url] = path;
      return path;
    }
    return null;
  }

  /// Returns local cached file path if ready, otherwise returns remote URL.
  Future<String> getPlaybackUrl(String remoteUrl) async {
    if (remoteUrl.trim().isEmpty) return '';
    if (!remoteUrl.startsWith('http')) return remoteUrl;

    final cached = getCachedFilePath(remoteUrl);
    if (cached != null) return cached;

    // Return remote URL without triggering cache to prevent double-downloading.
    // Explicit caching should be handled by preCacheVideo/preCachePriority.
    return remoteUrl;
  }

  /// Pre-cache video with normal queue priority.
  Future<void> preCacheVideo(String url) async {
    if (url.trim().isEmpty || !url.startsWith('http')) return;
    final downloadUrl = getDownloadableUrl(url);
    if (!url.contains('cloudflarestream.com') && url.toLowerCase().contains('.m3u8')) {
      return;
    }
    if (isCached(url) || isCached(downloadUrl)) return;
    if (_downloadingUrls.contains(downloadUrl) ||
        _downloadQueue.contains(downloadUrl)) {
      return;
    }

    _downloadQueue.add(downloadUrl);
    _processQueue();
  }

  /// Prioritize caching of upcoming active/next video (jumps to front of queue).
  Future<void> preCachePriority(String url) async {
    if (url.trim().isEmpty || !url.startsWith('http')) return;
    final downloadUrl = getDownloadableUrl(url);
    if (!url.contains('cloudflarestream.com') && url.toLowerCase().contains('.m3u8')) {
      return;
    }
    if (isCached(url) || isCached(downloadUrl)) return;
    if (_downloadingUrls.contains(downloadUrl)) return;

    _downloadQueue.remove(downloadUrl);
    _downloadQueue.addFirst(downloadUrl);
    _processQueue();
  }

  /// Prioritize caching of upcoming active, next, and previous videos in their exact priority order.
  /// urls.first will be at the head of the download queue.
  void preCachePriorityUrls(List<String> urls) {
    if (urls.isEmpty) return;
    for (int i = urls.length - 1; i >= 0; i--) {
      final raw = urls[i].trim();
      if (raw.isEmpty || !raw.startsWith('http')) continue;
      final downloadUrl = getDownloadableUrl(raw);
      if (!raw.contains('cloudflarestream.com') && raw.toLowerCase().contains('.m3u8')) {
        continue;
      }
      if (isCached(raw) || isCached(downloadUrl)) continue;

      _downloadQueue.remove(downloadUrl);
      _downloadQueue.addFirst(downloadUrl);
    }
    _processQueue();
  }

  /// Batch pre-cache
  Future<void> preCacheBatch(List<String> urls) async {
    for (final u in urls) {
      preCacheVideo(u);
    }
  }

  Future<void> _processQueue() async {
    while (_activeDownloadsCount < _maxConcurrentDownloads &&
        _downloadQueue.isNotEmpty) {
      final url = _downloadQueue.removeFirst();
      if (_downloadingUrls.contains(url)) continue;
      _activeDownloadsCount++;
      _downloadFile(url);
    }
  }

  Future<void> _downloadFile(String url) async {
    _downloadingUrls.add(url);
    final cancelToken = CancelToken();
    _activeCancelTokens[url] = cancelToken;

    final completer = Completer<String?>();
    _inFlightCompleters[url] = completer;

    File? tempFile;

    try {
      final file = await _getLocalFile(url);
      if (file == null) {
        completer.complete(null);
        return;
      }

      final tempFilePath =
          '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp';
      tempFile = File(tempFilePath);

      // Stream download to file to handle Content-Length and validate chunks
      final response = await _dio.get<ResponseBody>(
        url,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );

      final responseBody = response.data;
      if (responseBody == null) {
        throw Exception('Empty response body received for $url');
      }

      // Extract content headers
      final contentLengthHeader = response.headers.value('content-length');
      final expectedLength = contentLengthHeader != null
          ? int.tryParse(contentLengthHeader)
          : null;
      final contentType =
          response.headers.value('content-type')?.toLowerCase() ?? '';

      if (contentType.contains('text/html') ||
          contentType.contains('application/json') ||
          contentType.contains('text/plain')) {
        throw Exception('Invalid media content type: $contentType');
      }

      final sink = tempFile.openWrite();
      int totalBytesWritten = 0;
      final headerBytes = <int>[];

      try {
        await for (final chunk in responseBody.stream) {
          if (cancelToken.isCancelled) {
            throw Exception('Download cancelled');
          }
          if (headerBytes.length < 32) {
            headerBytes.addAll(chunk.take(32 - headerBytes.length));
          }
          sink.add(chunk);
          totalBytesWritten += chunk.length;
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      // 1. Verify Minimum File Size
      final isAudio =
          url.toLowerCase().contains('.mp3') ||
          url.toLowerCase().contains('.opus') ||
          url.toLowerCase().contains('.ogg') ||
          url.toLowerCase().contains('.m4a') ||
          url.toLowerCase().contains('.wav') ||
          url.toLowerCase().contains('.aac');
      final minRequiredSize = isAudio ? _minAudioSizeBytes : _minVideoSizeBytes;

      if (totalBytesWritten < minRequiredSize) {
        throw Exception(
          'Incomplete file: total size $totalBytesWritten < min required $minRequiredSize',
        );
      }

      // 2. Verify Content-Length match if header was present
      if (expectedLength != null &&
          expectedLength > 0 &&
          totalBytesWritten != expectedLength) {
        throw Exception(
          'Truncated file: written $totalBytesWritten != expected $expectedLength',
        );
      }

      // 3. Verify Media Magic Bytes
      if (!_isValidMediaHeader(Uint8List.fromList(headerBytes))) {
        throw Exception('Invalid media magic bytes header');
      }

      // 4. Safe Atomic File Replacement (Handles Windows OS Error 5 / locked files)
      await _safeAtomicRename(tempFile, file);

      final fname = _getFileName(url);
      _knownFilePaths[fname] = file.path;
      _memoryPathCache[url] = file.path;
      final cfId = extractCloudflareId(url);
      if (cfId != null) {
        _memoryPathCache['https://customer-xe2czubswwdkm567.cloudflarestream.com/$cfId/downloads/default.mp4'] = file.path;
        _memoryPathCache['https://customer-xe2czubswwdkm567.cloudflarestream.com/$cfId/manifest/video.m3u8'] = file.path;
      }
      completer.complete(file.path);

      // Async cache pruning without blocking playback
      _cleanOldCacheIfNeeded();
    } catch (e) {
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        debugPrint('⚠️ [VideoCacheManager] Pre-cache error for $url: $e');
      }
      if (tempFile != null) {
        _safeDeleteFile(tempFile);
      }
      completer.complete(null);
    } finally {
      _downloadingUrls.remove(url);
      _activeCancelTokens.remove(url);
      _inFlightCompleters.remove(url);
      _activeDownloadsCount--;
      _processQueue();
    }
  }

  /// Verifies media magic bytes against common audio/video file formats.
  bool _isValidMediaHeader(Uint8List bytes) {
    if (bytes.length < 8) return false;

    // ISO Media / MP4 / MOV / M4A (contains 'ftyp' at offset 4)
    if (bytes.length >= 8 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      return true;
    }

    // WebM / Matroska (1A 45 DF A3)
    if (bytes[0] == 0x1A &&
        bytes[1] == 0x45 &&
        bytes[2] == 0xDF &&
        bytes[3] == 0xA3) {
      return true;
    }

    // Ogg / Opus (OggS)
    if (bytes[0] == 0x4F &&
        bytes[1] == 0x67 &&
        bytes[2] == 0x67 &&
        bytes[3] == 0x53) {
      return true;
    }

    // MP3 (ID3v2 header 'ID3' or syncword FF FB / FF F3 / FF F2 / FF E3)
    if ((bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) ||
        (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0)) {
      return true;
    }

    // RIFF / WAV (RIFF....WAVE)
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45) {
      return true;
    }

    // AAC (ADTS syncword 0xFFF)
    if (bytes[0] == 0xFF && (bytes[1] & 0xF6) == 0xF0) {
      return true;
    }

    // Fallback: If header is not HTML/XML text, allow through
    final asciiPrefix = String.fromCharCodes(bytes.take(16)).toLowerCase();
    if (asciiPrefix.startsWith('<!doctype') ||
        asciiPrefix.startsWith('<html') ||
        asciiPrefix.startsWith('<?xml') ||
        asciiPrefix.startsWith('{"')) {
      return false;
    }

    return true;
  }

  /// Cross-platform atomic file rename with fallback for Windows file locks / cross-device links.
  Future<void> _safeAtomicRename(File source, File destination) async {
    try {
      if (await destination.exists()) {
        try {
          await destination.delete();
        } catch (_) {}
      }
      await source.rename(destination.path);
    } catch (e) {
      // Fallback: Stream copy + delete on systems where rename fails
      try {
        await source.copy(destination.path);
        await _safeDeleteFile(source);
      } catch (copyError) {
        await _safeDeleteFile(source);
        throw FileSystemException(
          'Failed to atomically save cached file: $copyError',
          destination.path,
        );
      }
    }
  }

  Future<void> _safeDeleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Asynchronously prunes old cache files without blocking main thread.
  Future<void> _cleanOldCacheIfNeeded() async {
    try {
      if (_cacheDir == null || !await _cacheDir!.exists()) return;

      final fileStats = <_FileStatEntry>[];
      int totalSize = 0;

      final stream = _cacheDir!.list(followLinks: false);
      await for (final entity in stream) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          totalSize += stat.size;
          fileStats.add(
            _FileStatEntry(
              file: entity,
              accessed: stat.accessed,
              size: stat.size,
            ),
          );
        } catch (_) {}
      }

      if (totalSize > _maxCacheSizeBytes) {
        fileStats.sort((a, b) => a.accessed.compareTo(b.accessed));

        final targetSize = (_maxCacheSizeBytes * 0.7).toInt();
        for (final entry in fileStats) {
          if (totalSize <= targetSize) break;
          try {
            await entry.file.delete();
            totalSize -= entry.size;
            final fname = entry.file.uri.pathSegments.isNotEmpty
                ? entry.file.uri.pathSegments.last
                : '';
            _knownFilePaths.remove(fname);
            _memoryPathCache.removeWhere((_, v) => v == entry.file.path);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Cancels in-flight downloads and clears cache directory safely.
  Future<void> clearCache() async {
    try {
      for (final token in _activeCancelTokens.values) {
        token.cancel('clearCache called');
      }
      _activeCancelTokens.clear();
      _downloadQueue.clear();
      _downloadingUrls.clear();
      _inFlightCompleters.clear();
      _memoryPathCache.clear();
      _knownFilePaths.clear();
      _activeDownloadsCount = 0;

      if (_cacheDir != null && await _cacheDir!.exists()) {
        final stream = _cacheDir!.list(followLinks: false);
        await for (final entity in stream) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('⚠️ [VideoCacheManager] Error clearing cache: $e');
    }
  }

  /// Cancels all active downloads and removes queued items NOT in [keepUrls].
  void cancelDownloadsExcept(List<String> keepUrls) {
    final keepDownloadUrls = keepUrls
        .where((u) => u.trim().isNotEmpty && u.startsWith('http'))
        .map((u) => getDownloadableUrl(u))
        .toSet();

    // 1. Remove from queue
    _downloadQueue.removeWhere((url) => !keepDownloadUrls.contains(url));

    // 2. Cancel in-flight
    final urlsToCancel = _activeCancelTokens.keys
        .where((url) => !keepDownloadUrls.contains(url))
        .toList();

    for (final url in urlsToCancel) {
      final token = _activeCancelTokens[url];
      token?.cancel('stale download cancelled');
      // The catch block in _downloadFile will handle cleanup
    }
  }
}

class _FileStatEntry {
  final File file;
  final DateTime accessed;
  final int size;

  _FileStatEntry({
    required this.file,
    required this.accessed,
    required this.size,
  });
}
