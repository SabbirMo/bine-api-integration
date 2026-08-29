import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Pre-warms a [Player] for the first video of a nearby story category
/// so that switching categories feels instant — like Facebook Stories.
///
/// Architecture:
///   • [StoryDetailScreen] calls [warmUpCategory] for adjacent groups (±1, ±2)
///   • When [StoryDetailProvider] needs a player and the URL matches a warm
///     entry, it calls [consumeWarmPlayer] to grab it instantly.
///   • Max 3 warm entries to keep memory bounded.
class CategoryPreloadManager {
  CategoryPreloadManager._internal();
  static final CategoryPreloadManager instance =
      CategoryPreloadManager._internal();

  static const int _maxWarm = 3;

  /// categoryId → warm player entry
  final Map<int, _WarmEntry> _warm = {};

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Pre-initialise a [Player] for [categoryId] and silently start buffering
  /// [firstVideoUrl]. Safe to call multiple times for the same category.
  void warmUpCategory({
    required int categoryId,
    required String firstVideoUrl,
    bool isMuted = false,
  }) {
    if (firstVideoUrl.trim().isEmpty) return;
    if (_warm.containsKey(categoryId)) return; // already warm

    // Evict oldest if full
    while (_warm.length >= _maxWarm) {
      _evictOldest();
    }

    debugPrint(
      '🔥 [CategoryPreload] Warming category $categoryId → $firstVideoUrl',
    );

    final player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
        logLevel: MPVLogLevel.error,
      ),
    );
    final controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    // Apply HLS properties
    _applyMpvProperties(player);

    player.setVolume(0.0); // always silent while pre-warming
    player.open(Media(firstVideoUrl), play: false); // start buffering silently without decoding frames

    _warm[categoryId] = _WarmEntry(
      categoryId: categoryId,
      videoUrl: firstVideoUrl,
      player: player,
      controller: controller,
      isMuted: isMuted,
    );
  }

  /// Returns a warm [_WarmEntry] for [categoryId] and removes it from the pool.
  /// Returns `null` if not pre-warmed (caller must create a fresh player).
  WarmPlayerEntry? consumeWarmPlayer(int categoryId) {
    final entry = _warm.remove(categoryId);
    if (entry == null) return null;
    debugPrint(
      '⚡ [CategoryPreload] Consumed warm player for category $categoryId',
    );
    return WarmPlayerEntry(
      player: entry.player,
      controller: entry.controller,
      videoUrl: entry.videoUrl,
    );
  }

  /// Discard the warm entry for [categoryId] (e.g. user skipped it).
  void invalidate(int categoryId) {
    final entry = _warm.remove(categoryId);
    if (entry != null) {
      try {
        entry.player.stop();
        entry.player.dispose();
      } catch (_) {}
    }
  }

  /// Dispose all pre-warmed players (call on app lifecycle pause / full cleanup).
  void disposeAll() {
    for (final e in _warm.values) {
      try {
        e.player.stop();
        e.player.dispose();
      } catch (_) {}
    }
    _warm.clear();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _evictOldest() {
    if (_warm.isEmpty) return;
    final oldest = _warm.entries.reduce(
      (a, b) => a.value.createdAt.isBefore(b.value.createdAt) ? a : b,
    );
    try {
      oldest.value.player.stop();
      oldest.value.player.dispose();
    } catch (_) {}
    _warm.remove(oldest.key);
    debugPrint(
      '🗑️ [CategoryPreload] Evicted category ${oldest.key}',
    );
  }

  Future<void> _applyMpvProperties(Player player) async {
    try {
      final platform = player.platform;
      if (platform == null) return;
      final p = platform as dynamic;
      await p.setProperty('hls-bitrate', 'auto');
      await p.setProperty('cache', 'yes');
      await p.setProperty('cache-secs', '3'); // Only buffer 3 seconds in background
      await p.setProperty('demuxer-readahead-secs', '3'); // Prevent network saturation
      await p.setProperty('demuxer-max-bytes', '32MiB');
      await p.setProperty('network-timeout', '10');
      await p.setProperty(
        'user-agent',
        'CloudflareStream-Flutter-MediaKit',
      );
    } catch (_) {}
  }
}

/// Internal warm entry (private)
class _WarmEntry {
  final int categoryId;
  final String videoUrl;
  final Player player;
  final VideoController controller;
  final bool isMuted;
  final DateTime createdAt;

  _WarmEntry({
    required this.categoryId,
    required this.videoUrl,
    required this.player,
    required this.controller,
    required this.isMuted,
  }) : createdAt = DateTime.now();
}

/// Public result returned by [CategoryPreloadManager.consumeWarmPlayer].
class WarmPlayerEntry {
  final Player player;
  final VideoController controller;
  final String videoUrl;

  const WarmPlayerEntry({
    required this.player,
    required this.controller,
    required this.videoUrl,
  });
}
