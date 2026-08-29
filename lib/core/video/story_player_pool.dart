import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// A pool of warm, pre-initialized [Player] instances for story videos.
///
/// When a story finishes playing or gets swapped out, its [Player] is donated
/// here instead of being disposed. Next time the same URL is needed, the warm
/// player is returned instantly — **0 ms** cold-start for recently-seen videos.
///
/// LRU eviction keeps memory usage bounded to [maxPoolSize] players.
class StoryPlayerPool {
  StoryPlayerPool._internal();
  static final StoryPlayerPool instance = StoryPlayerPool._internal();

  /// Maximum number of warm players kept alive at once.
  static const int maxPoolSize = 4;

  final Map<String, StoryPoolEntry> _pool = {};

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns a warm [StoryPoolEntry] for [url], or `null` if not cached.
  ///
  /// Calling this updates the entry's LRU timestamp so it survives longer.
  StoryPoolEntry? getWarm(String url) {
    final StoryPoolEntry? entry = _pool[url];
    if (entry == null) return null;
    entry._lastUsed = DateTime.now();
    debugPrint('🟢 [StoryPlayerPool] Cache HIT for: $url');
    return entry;
  }

  /// Donates [player] + [controller] to the pool under [url].
  ///
  /// The player is immediately paused, volume set to 0, and seeked to the
  /// start so it is ready for instant replay. If the pool is full, the
  /// least-recently-used entry is evicted and disposed.
  void donate({
    required String url,
    required Player player,
    required VideoController controller,
  }) {
    if (url.trim().isEmpty) return;

    // If we already have this URL, update in place.
    if (_pool.containsKey(url)) {
      _pool[url]!._lastUsed = DateTime.now();
      return;
    }

    // Evict LRU entries if pool is full.
    while (_pool.length >= maxPoolSize) {
      _evictLRU();
    }

    // Prepare player for instant replay.
    try {
      player.pause();
      player.setVolume(0.0);
      player.seek(Duration.zero);
    } catch (_) {}

    _pool[url] = StoryPoolEntry(
      url: url,
      player: player,
      controller: controller,
    );
    debugPrint(
      '💾 [StoryPlayerPool] Donated player for: $url (pool size: ${_pool.length})',
    );
  }

  /// Removes [url] from the pool WITHOUT disposing the player.
  ///
  /// Call this when promoting the warm player to active use.
  StoryPoolEntry? remove(String url) {
    final entry = _pool.remove(url);
    if (entry != null) {
      debugPrint('⚡ [StoryPlayerPool] Promoted warm player for: $url');
    }
    return entry;
  }

  /// Disposes all pooled players and clears the pool.
  void disposeAll() {
    for (final entry in _pool.values) {
      try {
        entry.player.stop();
        entry.player.dispose();
      } catch (_) {}
    }
    _pool.clear();
    debugPrint('🗑️  [StoryPlayerPool] Pool cleared');
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _evictLRU() {
    if (_pool.isEmpty) return;
    final lruKey = _pool.entries
        .reduce((a, b) => a.value._lastUsed.isBefore(b.value._lastUsed) ? a : b)
        .key;
    final evicted = _pool.remove(lruKey);
    if (evicted != null) {
      try {
        evicted.player.stop();
        evicted.player.dispose();
      } catch (_) {}
      debugPrint('🔴 [StoryPlayerPool] Evicted LRU player for: $lruKey');
    }
  }
}

/// A single entry in the [StoryPlayerPool].
class StoryPoolEntry {
  final String url;
  final Player player;
  final VideoController controller;
  DateTime _lastUsed;

  StoryPoolEntry({
    required this.url,
    required this.player,
    required this.controller,
  }) : _lastUsed = DateTime.now();
}
