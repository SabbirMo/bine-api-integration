import 'dart:io';
import 'dart:collection';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Central Disk & Memory Video Cache Manager for ultra-smooth Shorts playback.
/// Automatically caches remote video files to local disk so they only download
/// once, enabling instant 0ms playback and preventing repeated network buffering.
/// It uses a strict sequential queue to prevent bandwidth starvation.
class VideoCacheManager {
  static final VideoCacheManager _instance = VideoCacheManager._internal();
  static VideoCacheManager get instance => _instance;

  VideoCacheManager._internal();

  Directory? _cacheDir;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  final Set<String> _downloadingUrls = {};
  final Queue<String> _downloadQueue = Queue<String>();
  bool _isDownloading = false;

  final Map<String, String> _memoryPathCache = {};
  final Map<String, String> _knownFilePaths = {};

  Future<void> init() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      _cacheDir = Directory('${appDir.path}/shorts_video_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      } else {
        // Fast async preload of existing cached files into memory
        final entities = await _cacheDir!.list().toList();
        for (final entity in entities) {
          if (entity is File) {
            final len = entity.lengthSync();
            // Purge corrupt or empty files
            if (len < 50 * 1024) {
              try {
                entity.deleteSync();
              } catch (_) {}
              continue;
            }
            final name = entity.uri.pathSegments.isNotEmpty
                ? entity.uri.pathSegments.last
                : '';
            if (name.startsWith('vid_') && !name.endsWith('.tmp')) {
              _knownFilePaths[name] = entity.path;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [VideoCacheManager] Failed to init cache dir: $e');
    }
  }

  String _getFileName(String url) {
    final safeHash = url.hashCode.abs().toString();
    final cleanUrl = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final prefix = cleanUrl.length > 20
        ? cleanUrl.substring(cleanUrl.length - 20)
        : cleanUrl;

    return 'vid_${safeHash}_$prefix.mp4';
  }

  Future<File?> _getLocalFile(String url) async {
    if (_cacheDir == null) {
      await init();
    }
    if (_cacheDir == null) return null;
    final filename = _getFileName(url);
    return File('${_cacheDir!.path}/$filename');
  }

  /// Check if the video is already downloaded and verified on disk
  bool isCached(String url) {
    if (url.trim().isEmpty) return false;
    final path = _memoryPathCache[url] ?? _knownFilePaths[_getFileName(url)];
    if (path != null) {
      final f = File(path);
      if (f.existsSync() && f.lengthSync() > 50 * 1024) {
        _memoryPathCache[url] = path;
        return true;
      } else {
        _memoryPathCache.remove(url);
        _knownFilePaths.remove(_getFileName(url));
      }
    }
    return false;
  }

  /// Get verified local cached file path, or null if not yet cached
  String? getCachedFilePath(String url) {
    if (url.trim().isEmpty) return null;
    final path = _memoryPathCache[url] ?? _knownFilePaths[_getFileName(url)];
    if (path != null) {
      final f = File(path);
      if (f.existsSync() && f.lengthSync() > 50 * 1024) {
        _memoryPathCache[url] = path;
        return path;
      } else {
        _memoryPathCache.remove(url);
        _knownFilePaths.remove(_getFileName(url));
      }
    }
    return null;
  }

  /// Returns the local cached file path if ready, otherwise returns the remote URL
  /// and starts caching in the background.
  Future<String> getPlaybackUrl(String remoteUrl) async {
    if (remoteUrl.trim().isEmpty) return '';
    if (!remoteUrl.startsWith('http')) return remoteUrl;

    final cached = getCachedFilePath(remoteUrl);
    if (cached != null) {
      return cached;
    }

    // Trigger background cache download
    preCacheVideo(remoteUrl);

    return remoteUrl;
  }

  /// Pre-cache a video in the background without blocking the UI
  Future<void> preCacheVideo(String url) async {
    if (url.trim().isEmpty || !url.startsWith('http')) return;
    if (isCached(url) || _downloadingUrls.contains(url) || _downloadQueue.contains(url)) return;
    
    // Don't download m3u8 manually
    if (url.toLowerCase().contains('.m3u8')) return;

    _downloadQueue.add(url);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isDownloading || _downloadQueue.isEmpty) return;
    _isDownloading = true;

    final url = _downloadQueue.removeFirst();
    _downloadingUrls.add(url);

    try {
      final file = await _getLocalFile(url);
      if (file == null) {
        _downloadingUrls.remove(url);
        _isDownloading = false;
        _processQueue();
        return;
      }

      final tempFilePath = '${file.path}.tmp';
      final tempFile = File(tempFilePath);

      // Download file to a temporary location first
      final response = await _dio.download(
        url,
        tempFilePath,
        deleteOnError: true,
        options: Options(
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
      );

      final contentType = response.headers.value('content-type')?.toLowerCase() ?? '';
      final bool isHtmlOrJson = contentType.contains('text/html') ||
          contentType.contains('application/json') ||
          contentType.contains('text/plain');

      // Valid video files must be at least 50 KB and not HTML error pages
      if (!isHtmlOrJson &&
          await tempFile.exists() &&
          await tempFile.length() > 50 * 1024) {
        await tempFile.rename(file.path);
        final fname = _getFileName(url);
        _knownFilePaths[fname] = file.path;
        _memoryPathCache[url] = file.path;
        debugPrint('✅ [VideoCacheManager] Cached video sequentially: $url');
        _cleanOldCacheIfNeeded();
      } else {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      debugPrint('⚠️ [VideoCacheManager] Sequential pre-cache error for $url: $e');
      try {
        final f = await _getLocalFile(url);
        if (f != null) {
          final t = File('${f.path}.tmp');
          if (t.existsSync()) t.deleteSync();
        }
      } catch (_) {}
    } finally {
      _downloadingUrls.remove(url);
      _isDownloading = false;
      _processQueue();
    }
  }

  /// Start background caching for a list of URLs
  Future<void> preCacheBatch(List<String> urls) async {
    for (var u in urls) {
      preCacheVideo(u);
    }
  }

  /// Automatically prune oldest cached videos if cache exceeds 150 MB
  Future<void> _cleanOldCacheIfNeeded() async {
    try {
      if (_cacheDir == null || !await _cacheDir!.exists()) return;
      final files = _cacheDir!.listSync().whereType<File>().toList();
      int totalSize = 0;
      for (final f in files) {
        try {
          totalSize += f.lengthSync();
        } catch (_) {}
      }

      const int maxCacheBytes = 150 * 1024 * 1024; // 150 MB safety limit
      if (totalSize > maxCacheBytes) {
        files.sort((a, b) {
          try {
            return a.lastModifiedSync().compareTo(b.lastModifiedSync());
          } catch (_) {
            return 0;
          }
        });

        for (final f in files) {
          if (totalSize <= (maxCacheBytes * 0.7).toInt()) break;
          try {
            totalSize -= f.lengthSync();
            f.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Clear video cache directory if needed
  Future<void> clearCache() async {
    try {
      _memoryPathCache.clear();
      _knownFilePaths.clear();
      _downloadQueue.clear();
      _downloadingUrls.clear();
      _isDownloading = false;
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
    } catch (e) {
      debugPrint('⚠️ [VideoCacheManager] Error clearing cache: $e');
    }
  }
}
