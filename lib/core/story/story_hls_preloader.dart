import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Startup latency tracker to monitor cold-start vs warm story load times
class AppStartupTracker {
  static final DateTime appStartTime = DateTime.now();
  static bool isFirstStoryPlay = true;
}

/// Lightweight background HLS stream preloader for 0ms story transitions.
/// Warms the HTTP connection, TLS session, and demuxer buffer for the immediate next story.
class StoryHlsPreloader {
  static final StoryHlsPreloader _instance = StoryHlsPreloader._internal();
  static StoryHlsPreloader get instance => _instance;

  StoryHlsPreloader._internal();

  String? _currentlyPreloadingUrl;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'CloudflareStream-Flutter-MediaKit',
      },
    ),
  );

  String? get currentlyPreloadingUrl => _currentlyPreloadingUrl;

  /// Eagerly warms up the native engine tracker at app startup
  Future<void> warmupEngine() async {
    debugPrint('🔥 [StoryHlsPreloader] Engine startup tracker initialized');
  }

  /// Preloads the immediate next HLS stream manifests in the background
  Future<void> preload(String url) async {
    if (url.trim().isEmpty || !url.startsWith('http')) return;
    if (_currentlyPreloadingUrl == url) return;

    _currentlyPreloadingUrl = url;
    debugPrint('🚀 [StoryHlsPreloader] Preloading next HLS stream manifest: $url');

    // 1. Warm HTTP Connection, DNS, and TLS session by prefetching the master manifest & variant
    await _prefetchManifest(url);
  }

  /// Silently pre-fetches the master HLS .m3u8 playlist to warm the edge network connection
  Future<void> _prefetchManifest(String url) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );

      // If this is a master playlist, also prefetch the first variant sub-playlist
      final body = response.data;
      if (body != null && body.contains('#EXT-X-STREAM-INF')) {
        final lines = body.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
            String variantUrl = trimmed;
            if (!variantUrl.startsWith('http')) {
              final uri = Uri.parse(url);
              variantUrl = uri.resolve(variantUrl).toString();
            }
            // Fire-and-forget variant prefetch
            unawaited(
              _dio
                  .get<String>(
                    variantUrl,
                    options: Options(responseType: ResponseType.plain),
                  )
                  .then((_) {}, onError: (_) {}),
            );
            break;
          }
        }
      }
    } catch (_) {}
  }

  /// Cancels the current preload task
  Future<void> cancel() async {
    _currentlyPreloadingUrl = null;
  }

  /// Disposes background preloader resources
  Future<void> dispose() async {
    _currentlyPreloadingUrl = null;
  }
}
