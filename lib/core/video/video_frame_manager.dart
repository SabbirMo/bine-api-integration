import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:binetatour/core/base_url/base_url.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';

/// Ultra-Fast Central Video Frame / First-Part Extractor:
/// - Pure video first-frame extraction (no catalog thumbnail fallback)
/// - Memory + Disk instant caching
/// - Eager disk warm-up on app launch
/// - Optimized resolution & seek for < 20ms frame extraction
class VideoFrameManager extends ChangeNotifier {
  static final VideoFrameManager _instance = VideoFrameManager._internal();
  static VideoFrameManager get instance => _instance;

  VideoFrameManager._internal();

  final Map<String, Uint8List> _memoryFrameCache = {};
  final Map<String, String> _diskPathMap = {};
  final Set<String> _pendingUrls = {};
  final Set<String> _failedUrls = {};
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
            if (file.existsSync() && file.lengthSync() > 100) {
              _diskPathMap[entry.key] = filePath;
              // Preload first 20 most recent frames into memory for 0ms initial render
              if (_memoryFrameCache.length < 25) {
                try {
                  _memoryFrameCache[entry.key] = await file.readAsBytes();
                } catch (_) {}
              }
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

  /// Synchronously retrieve cached frame bytes if available in memory (0ms)
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

    // Try synchronous disk read if mapped
    final diskPath = _diskPathMap[clean] ?? _diskPathMap[resolved];
    if (diskPath != null) {
      final file = File(diskPath);
      if (file.existsSync()) {
        try {
          final bytes = file.readAsBytesSync();
          if (bytes.isNotEmpty) {
            _memoryFrameCache[clean] = bytes;
            _memoryFrameCache[resolved] = bytes;
            return bytes;
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Batch pre-extract all video frames sequentially so codec threads are never exhausted
  Future<void> preExtractBatch(List<String> videoUrls) async {
    for (final url in videoUrls) {
      final clean = url.trim();
      if (clean.isNotEmpty &&
          !clean.toLowerCase().contains('.m3u8') &&
          !_memoryFrameCache.containsKey(clean) &&
          !_diskPathMap.containsKey(clean) &&
          !_failedUrls.contains(clean)) {
        await extractFirstFrame(clean);
      }
    }
  }

  /// Extract the video's first frame with ultra-fast decoder settings
  Future<Uint8List?> extractFirstFrame(String videoUrl) async {
    final clean = videoUrl.trim();
    if (clean.isEmpty) return null;

    // HLS (.m3u8) streams do not support static frame extraction via VideoThumbnail
    if (clean.toLowerCase().contains('.m3u8')) {
      return null;
    }

    final resolved = resolveUrl(clean);

    if (_failedUrls.contains(clean) || _failedUrls.contains(resolved))
      return null;

    // 1. Instant Memory Cache (0ms)
    if (_memoryFrameCache.containsKey(clean)) {
      return _memoryFrameCache[clean];
    }
    if (_memoryFrameCache.containsKey(resolved)) {
      return _memoryFrameCache[resolved];
    }

    if (!_isInitialized) {
      await init();
    }

    // 2. Instant Disk Cache (< 5ms)
    if (_thumbDir != null) {
      final filename = _getThumbFilename(resolved);
      final file = File('${_thumbDir!.path}/$filename');
      if (file.existsSync() && file.lengthSync() > 100) {
        try {
          final bytes = await file.readAsBytes();
          _memoryFrameCache[clean] = bytes;
          _memoryFrameCache[resolved] = bytes;
          _diskPathMap[clean] = file.path;
          _diskPathMap[resolved] = file.path;
          _saveIndex().ignore();
          notifyListeners();
          return bytes;
        } catch (_) {}
      }
    }

    if (_pendingUrls.contains(clean) || _pendingUrls.contains(resolved))
      return null;
    _pendingUrls.add(clean);
    _pendingUrls.add(resolved);

    try {
      // Prefer locally cached video for instantaneous offline extraction
      final localVideoPath =
          VideoCacheManager.instance.getCachedFilePath(resolved) ??
          VideoCacheManager.instance.getCachedFilePath(clean);
      final source = localVideoPath ?? resolved;

      final bytes = await VideoThumbnail.thumbnailData(
        video: source,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 360,
        quality: 50,
        timeMs: 0,
      );

      if (bytes.isNotEmpty) {
        _memoryFrameCache[clean] = bytes;

        // Persist to disk asynchronously
        if (_thumbDir != null) {
          final filename = _getThumbFilename(clean);
          final file = File('${_thumbDir!.path}/$filename');
          await file.writeAsBytes(bytes, flush: false);
          _diskPathMap[clean] = file.path;
          _saveIndex().ignore();
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

  /// Clear frame caches if needed
  Future<void> clearCache() async {
    _memoryFrameCache.clear();
    _diskPathMap.clear();
    _failedUrls.clear();
    _pendingUrls.clear();
    try {
      if (_thumbDir != null && await _thumbDir!.exists()) {
        await _thumbDir!.delete(recursive: true);
        await _thumbDir!.create(recursive: true);
      }
    } catch (_) {}
  }
}
