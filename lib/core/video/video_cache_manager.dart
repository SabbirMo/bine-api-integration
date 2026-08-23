import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Central Disk Video Cache Manager for ultra-smooth Shorts playback.
/// Automatically caches remote video files to local disk so they only download
/// once, enabling instant 0ms playback and preventing repeated network buffering.
class VideoCacheManager {
  static final VideoCacheManager _instance = VideoCacheManager._internal();
  static VideoCacheManager get instance => _instance;

  VideoCacheManager._internal();

  Directory? _cacheDir;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 45),
    ),
  );

  final Set<String> _downloadingUrls = {};
  final Map<String, String> _memoryPathCache = {};

  Future<void> init() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory('${tempDir.path}/shorts_video_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
    } catch (e) {
      debugPrint('⚠️ [VideoCacheManager] Failed to init cache dir: $e');
    }
  }

  String _getFileName(String url) {
    // Generate safe alphanumeric filename
    final safeHash = url.hashCode.abs().toString();
    final cleanUrl = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final prefix = cleanUrl.length > 20
        ? cleanUrl.substring(cleanUrl.length - 20)
        : cleanUrl;

    String ext = '.mp4';
    final uri = Uri.tryParse(url);
    if (uri != null && uri.path.contains('.')) {
      final lastDot = uri.path.lastIndexOf('.');
      final candidateExt = uri.path.substring(lastDot);
      if (candidateExt.length <= 5 && candidateExt.startsWith('.')) {
        ext = candidateExt;
      }
    }
    return 'vid_${safeHash}_$prefix$ext';
  }

  Future<File?> _getLocalFile(String url) async {
    if (_cacheDir == null) {
      await init();
    }
    if (_cacheDir == null) return null;
    final filename = _getFileName(url);
    return File('${_cacheDir!.path}/$filename');
  }

  /// Check if the video is already downloaded to local storage
  bool isCached(String url) {
    if (url.trim().isEmpty) return false;
    if (_memoryPathCache.containsKey(url)) {
      final path = _memoryPathCache[url]!;
      return File(path).existsSync();
    }
    if (_cacheDir == null) return false;
    final filename = _getFileName(url);
    final file = File('${_cacheDir!.path}/$filename');
    if (file.existsSync() && file.lengthSync() > 1024) {
      _memoryPathCache[url] = file.path;
      return true;
    }
    return false;
  }

  /// Get the local cached file path if it exists, or null
  String? getCachedFilePath(String url) {
    if (url.trim().isEmpty) return null;
    if (_memoryPathCache.containsKey(url)) {
      final path = _memoryPathCache[url]!;
      if (File(path).existsSync()) return path;
    }
    if (_cacheDir == null) return null;
    final filename = _getFileName(url);
    final file = File('${_cacheDir!.path}/$filename');
    if (file.existsSync() && file.lengthSync() > 1024) {
      _memoryPathCache[url] = file.path;
      return file.path;
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
    if (url.toLowerCase().contains('.m3u8')) return;
    if (isCached(url) || _downloadingUrls.contains(url)) return;

    _downloadingUrls.add(url);

    try {
      final file = await _getLocalFile(url);
      if (file == null) {
        _downloadingUrls.remove(url);
        return;
      }

      final tempFilePath = '${file.path}.tmp';
      final tempFile = File(tempFilePath);

      await _dio.download(url, tempFilePath, deleteOnError: true);

      if (await tempFile.exists() && await tempFile.length() > 1024) {
        await tempFile.rename(file.path);
        _memoryPathCache[url] = file.path;
        debugPrint('✅ [VideoCacheManager] Cached video: $url');
      }
    } catch (e) {
      try {
        final file = await _getLocalFile(url);
        if (file != null) {
          final tempFile = File('${file.path}.tmp');
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      } catch (_) {}
      debugPrint('⚠️ [VideoCacheManager] Error caching video $url: $e');
    } finally {
      _downloadingUrls.remove(url);
    }
  }

  /// Pre-cache a list of product video URLs in background sequentially
  Future<void> preCacheBatch(List<String> urls) async {
    for (final url in urls) {
      if (url.trim().isNotEmpty &&
          url.startsWith('http') &&
          !url.toLowerCase().contains('.m3u8') &&
          !isCached(url)) {
        await preCacheVideo(url);
      }
    }
  }

  /// Clear video cache directory if needed
  Future<void> clearCache() async {
    try {
      _memoryPathCache.clear();
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
    } catch (e) {
      debugPrint('⚠️ [VideoCacheManager] Error clearing cache: $e');
    }
  }
}
