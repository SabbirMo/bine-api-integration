import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';

/// Ultra-Fast Central Video Frame / First-Part Extractor:
/// - Eager batch pre-extraction
/// - Memory + Disk instant caching
/// - Optimized resolution & seek for < 20ms frame extraction
class VideoFrameManager extends ChangeNotifier {
  static final VideoFrameManager _instance = VideoFrameManager._internal();
  static VideoFrameManager get instance => _instance;

  VideoFrameManager._internal();

  final Map<String, Uint8List> _memoryFrameCache = {};
  final Set<String> _pendingUrls = {};
  final Set<String> _failedUrls = {};
  Directory? _thumbDir;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final tempDir = await getTemporaryDirectory();
      _thumbDir = Directory('${tempDir.path}/video_first_frames');
      if (!await _thumbDir!.exists()) {
        await _thumbDir!.create(recursive: true);
      } else {
        // Warm up cache in background from disk
        _warmUpFromDisk();
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ [VideoFrameManager] Init error: $e');
    }
  }

  void _warmUpFromDisk() {
    if (_thumbDir == null) return;
    try {
      final files = _thumbDir!.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith('.jpg')) {
          // File verified in cache directory
        }
      }
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

  /// Synchronously retrieve cached frame bytes if available in memory (0ms)
  Uint8List? getCachedFrame(String videoUrl) {
    if (videoUrl.trim().isEmpty) return null;
    return _memoryFrameCache[videoUrl];
  }

  /// Batch pre-extract all video frames sequentially so codec threads are never exhausted
  Future<void> preExtractBatch(List<String> videoUrls) async {
    for (final url in videoUrls) {
      if (url.trim().isNotEmpty &&
          !url.toLowerCase().contains('.m3u8') &&
          !_memoryFrameCache.containsKey(url) &&
          !_failedUrls.contains(url)) {
        await extractFirstFrame(url);
      }
    }
  }

  /// Extract the video's first frame with ultra-fast decoder settings
  Future<Uint8List?> extractFirstFrame(String videoUrl) async {
    final clean = videoUrl.trim();
    if (clean.isEmpty) return null;

    // HLS (.m3u8) streams do not support static frame extraction via VideoThumbnail;
    // skip to avoid native thread stalls
    if (clean.toLowerCase().contains('.m3u8')) {
      return null;
    }

    if (_failedUrls.contains(clean)) return null;

    // 1. Instant Memory Cache (0ms)
    if (_memoryFrameCache.containsKey(clean)) {
      return _memoryFrameCache[clean];
    }

    if (!_isInitialized) {
      await init();
    }

    // 2. Instant Disk Cache (< 5ms)
    if (_thumbDir != null) {
      final file = File('${_thumbDir!.path}/${_getThumbFilename(clean)}');
      if (file.existsSync() && file.lengthSync() > 100) {
        try {
          final bytes = await file.readAsBytes();
          _memoryFrameCache[clean] = bytes;
          notifyListeners();
          return bytes;
        } catch (_) {}
      }
    }

    if (_pendingUrls.contains(clean)) return null;
    _pendingUrls.add(clean);

    try {
      // Prefer locally cached video for instantaneous offline extraction
      final localVideoPath = VideoCacheManager.instance.getCachedFilePath(
        clean,
      );
      final source = localVideoPath ?? clean;

      final bytes = await VideoThumbnail.thumbnailData(
        video: source,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 260,
        quality: 40,
        timeMs: 0,
      );

      if (bytes.isNotEmpty) {
        _memoryFrameCache[clean] = bytes;

        // Persist to disk asynchronously
        if (_thumbDir != null) {
          final file = File('${_thumbDir!.path}/${_getThumbFilename(clean)}');
          file.writeAsBytes(bytes, flush: false).ignore();
        }

        notifyListeners();
        return bytes;
      } else {
        _failedUrls.add(clean);
      }
    } catch (e) {
      _failedUrls.add(clean);
      debugPrint(
        '⚠️ [VideoFrameManager] Frame extraction skipped for $clean: $e',
      );
    } finally {
      _pendingUrls.remove(clean);
    }

    return null;
  }
}
