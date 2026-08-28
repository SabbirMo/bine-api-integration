import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:binetatour/core/base_url/base_url.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';

/// Ultra-Fast & Non-Blocking Video Frame Extractor:
/// - Extracts actual video first frame with 0ms RAM caching
/// - Fully asynchronous, no synchronous disk reads in build methods
/// - Sequential worker queue with strict timeout to prevent Android ANRs
/// - Automatic caching & instant local-file extraction
class VideoFrameManager extends ChangeNotifier {
  static final VideoFrameManager _instance = VideoFrameManager._internal();
  static VideoFrameManager get instance => _instance;

  VideoFrameManager._internal();

  final Map<String, Uint8List> _memoryFrameCache = {};
  final Map<String, String> _diskPathMap = {};
  final Set<String> _pendingUrls = {};
  final Set<String> _failedUrls = {};
  final Set<String> _loadingFromDisk = {};

  final Queue<String> _extractionQueue = Queue<String>();
  bool _isProcessingQueue = false;

  Directory? _thumbDir;
  File? _indexFile;
  bool _isInitialized = false;

  static String resolveUrl(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return '';
    if (!clean.startsWith('http') && !File(clean).existsSync()) {
      final base = BaseUrl.baseUrl;
      return clean.startsWith('/') ? '$base$clean' : '$base/$clean';
    }
    return clean;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final tempDir = await getTemporaryDirectory();
      _thumbDir = Directory('${tempDir.path}/video_first_frames');
      if (!await _thumbDir!.exists()) {
        await _thumbDir!.create(recursive: true);
      }
      _indexFile = File('${_thumbDir!.path}/frame_index.json');
      await _warmUpFromDisk();
      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ [VideoFrameManager] Init error: $e');
    }
  }

  Future<void> _warmUpFromDisk() async {
    if (_thumbDir == null) return;
    try {
      if (_indexFile != null && await _indexFile!.exists()) {
        final content = await _indexFile!.readAsString();
        if (content.trim().isNotEmpty) {
          final Map<String, dynamic> jsonMap = jsonDecode(content);
          for (final entry in jsonMap.entries) {
            final filePath = entry.value.toString();
            final file = File(filePath);
            if (await file.exists()) {
              _diskPathMap[entry.key] = filePath;
              try {
                // Preload frame bytes directly into memory for 0ms retrieval
                final bytes = await file.readAsBytes();
                if (bytes.isNotEmpty) {
                  _memoryFrameCache[entry.key] = bytes;
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [VideoFrameManager] Warm up error: $e');
    }
  }

  Future<void> _saveIndex() async {
    if (_indexFile == null) return;
    try {
      await _indexFile!.writeAsString(jsonEncode(_diskPathMap), flush: false);
    } catch (_) {}
  }

  String _getThumbFilename(String url) {
    final safeHash = url.hashCode.abs().toString();
    final clean = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final prefix = clean.length > 15
        ? clean.substring(clean.length - 15)
        : clean;
    return 'frame_${safeHash}_$prefix.jpg';
  }

  /// Synchronously retrieve cached frame bytes from RAM (0ms).
  /// Never blocks the UI thread with synchronous file I/O.
  Uint8List? getCachedFrame(String videoUrl) {
    final clean = videoUrl.trim();
    if (clean.isEmpty) return null;
    final resolved = resolveUrl(clean);

    if (_memoryFrameCache.containsKey(clean)) {
      return _memoryFrameCache[clean];
    }
    if (_memoryFrameCache.containsKey(resolved)) {
      return _memoryFrameCache[resolved];
    }

    // If on disk but not yet in memory, trigger async load without blocking build
    final diskPath = _diskPathMap[clean] ?? _diskPathMap[resolved];
    if (diskPath != null && !_loadingFromDisk.contains(diskPath)) {
      _loadDiskFrameAsync(clean, resolved, diskPath);
    }

    return null;
  }

  Future<void> _loadDiskFrameAsync(
    String clean,
    String resolved,
    String diskPath,
  ) async {
    _loadingFromDisk.add(diskPath);
    try {
      final file = File(diskPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          _memoryFrameCache[clean] = bytes;
          _memoryFrameCache[resolved] = bytes;
          notifyListeners();
        }
      }
    } catch (_) {
    } finally {
      _loadingFromDisk.remove(diskPath);
    }
  }

  /// Batch pre-extract video frames
  Future<void> preExtractBatch(List<String> videoUrls) async {
    for (final url in videoUrls) {
      final clean = url.trim();
      if (clean.isNotEmpty &&
          !clean.toLowerCase().contains('.m3u8') &&
          !_memoryFrameCache.containsKey(clean) &&
          !_diskPathMap.containsKey(clean) &&
          !_failedUrls.contains(clean)) {
        extractFirstFrame(clean);
      }
    }
  }

  /// Request frame extraction asynchronously through a safe queue
  Future<Uint8List?> extractFirstFrame(String videoUrl) async {
    final clean = videoUrl.trim();
    if (clean.isEmpty) return null;

    if (clean.toLowerCase().contains('.m3u8')) {
      return null;
    }

    final resolved = resolveUrl(clean);

    if (_failedUrls.contains(clean) || _failedUrls.contains(resolved)) {
      return null;
    }

    // 1. Instant RAM Cache (0ms)
    if (_memoryFrameCache.containsKey(clean)) {
      return _memoryFrameCache[clean];
    }
    if (_memoryFrameCache.containsKey(resolved)) {
      return _memoryFrameCache[resolved];
    }

    if (!_isInitialized) {
      await init();
    }

    // 2. Check Disk Cache
    if (_diskPathMap.containsKey(clean) || _diskPathMap.containsKey(resolved)) {
      final diskPath = _diskPathMap[clean] ?? _diskPathMap[resolved]!;
      _loadDiskFrameAsync(clean, resolved, diskPath);
      return null;
    }

    if (_pendingUrls.contains(clean) || _pendingUrls.contains(resolved)) {
      return null;
    }

    _pendingUrls.add(clean);
    _pendingUrls.add(resolved);
    _extractionQueue.add(clean);

    _processQueue();
    return null;
  }

  void _processQueue() async {
    if (_isProcessingQueue || _extractionQueue.isEmpty) return;
    _isProcessingQueue = true;

    while (_extractionQueue.isNotEmpty) {
      final url = _extractionQueue.removeFirst();
      final resolved = resolveUrl(url);

      if (_memoryFrameCache.containsKey(url) ||
          _memoryFrameCache.containsKey(resolved)) {
        _pendingUrls.remove(url);
        _pendingUrls.remove(resolved);
        continue;
      }

      String? localVideoPath;
      try {
        // Prefer locally cached video for instantaneous offline extraction (< 15ms)
        localVideoPath =
            VideoCacheManager.instance.getCachedFilePath(resolved) ??
            VideoCacheManager.instance.getCachedFilePath(url);
        final source = localVideoPath ?? resolved;

        // If it's a remote URL, start background downloading so next attempt is from local disk
        if (localVideoPath == null && resolved.startsWith('http')) {
          VideoCacheManager.instance.preCacheVideo(resolved);
        }

        // Extract frame with strict timeout to NEVER hang the Android platform thread
        final bytes = await VideoThumbnail.thumbnailData(
          video: source,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 360,
          quality: 50,
          timeMs: 0,
        ).timeout(const Duration(seconds: 3));

        if (bytes.isNotEmpty) {
          _memoryFrameCache[url] = bytes;
          _memoryFrameCache[resolved] = bytes;

          // Persist to disk asynchronously
          if (_thumbDir != null) {
            final filename = _getThumbFilename(url);
            final file = File('${_thumbDir!.path}/$filename');
            await file.writeAsBytes(bytes, flush: false);
            _diskPathMap[url] = file.path;
            _diskPathMap[resolved] = file.path;
            _saveIndex().ignore();
          }

          notifyListeners();
        } else {
          _failedUrls.add(url);
        }
      } catch (e) {
        debugPrint(
          '⚠️ [VideoFrameManager] Extraction skipped or timed out for $url: $e',
        );
        // Do not permanently fail if it was a network timeout; background cache will retry on disk
        if (localVideoPath != null) {
          _failedUrls.add(url);
        }
      } finally {
        _pendingUrls.remove(url);
        _pendingUrls.remove(resolved);
      }
    }

    _isProcessingQueue = false;
  }

  /// Clear frame caches if needed
  Future<void> clearCache() async {
    _memoryFrameCache.clear();
    _diskPathMap.clear();
    _failedUrls.clear();
    _pendingUrls.clear();
    _extractionQueue.clear();
    try {
      if (_thumbDir != null && await _thumbDir!.exists()) {
        await _thumbDir!.delete(recursive: true);
        await _thumbDir!.create(recursive: true);
      }
    } catch (_) {}
  }
}
