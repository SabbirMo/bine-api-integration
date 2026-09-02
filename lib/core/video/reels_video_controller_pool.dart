import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:binetatour/core/video/feed_video_manager.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';

/// State of an individual player in the Reels pre-streaming pool.
class ReelsPlayerSlot {
  final int index;
  Player player;
  VideoController videoController;

  String? currentUrl;
  int? currentItemIndex;

  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isBuffering = ValueNotifier<bool>(false);
  final ValueNotifier<bool> hasFirstFrame = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  void setPlaying(bool val) => _safeUpdate(isPlaying, val);
  void setBuffering(bool val) => _safeUpdate(isBuffering, val);
  void setHasFirstFrame(bool val) => _safeUpdate(hasFirstFrame, val);
  void setError(String? val) => _safeUpdate(error, val);

  void _safeUpdate<T>(ValueNotifier<T> notifier, T val) {
    if (notifier.value == val) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        WidgetsBinding.instance.buildOwner?.debugBuilding == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.value = val;
      });
    } else {
      notifier.value = val;
    }
  }

  final List<StreamSubscription> _subscriptions = [];

  ReelsPlayerSlot({
    required this.index,
    required this.player,
    required this.videoController,
  }) {
    _setupSubscriptions();
  }

  void reattach(Player newPlayer, VideoController newController) {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    if (player != newPlayer) {
      try {
        player.stop();
        player.dispose();
      } catch (_) {}
    }
    player = newPlayer;
    videoController = newController;
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    void checkFirstFrameReady() {
      if (hasFirstFrame.value) return;

      final pos = player.state.position;
      // Truly ready when position advanced
      if (pos > Duration.zero) {
        setHasFirstFrame(true);
        setBuffering(false);
      }
    }

    _subscriptions.add(
      player.stream.playing.listen((p) {
        setPlaying(p);
        if (p) checkFirstFrameReady();
      }),
    );
    _subscriptions.add(
      player.stream.buffering.listen((b) {
        // Suppress buffering spinner on instant seamless loops back to time 0
        if (b && hasFirstFrame.value && player.state.position < const Duration(milliseconds: 400)) {
          return;
        }
        setBuffering(b);
        if (!b) {
          checkFirstFrameReady();
        }
      }),
    );
    _subscriptions.add(
      player.stream.videoParams.listen((params) {
        if (params.w != null && params.w! > 0) {
          checkFirstFrameReady();
        }
      }),
    );
    _subscriptions.add(
      player.stream.position.listen((pos) {
        if (pos > Duration.zero) {
          checkFirstFrameReady();
        }
      }),
    );
    videoController.waitUntilFirstFrameRendered.then((_) {
      if (!player.state.buffering) {
        setHasFirstFrame(true);
        setBuffering(false);
      }
    }).catchError((_) {});

    _subscriptions.add(
      player.stream.error.listen((err) {
        final errStr = err.toString().toLowerCase();
        // Filter harmless errors from slot recycling and audio device
        if (errStr.contains('audio device') ||
            errStr.contains('no sound') ||
            errStr.contains('loading cancelled') ||
            errStr.contains('quitting') ||
            errStr.isEmpty) {
          return;
        }
        debugPrint('⚠️ [ReelsVideoControllerPool] Slot $index error: $err');
        setError(err.toString());
        setBuffering(false);
      }),
    );
  }

  void reset() {
    try {
      player.stop();
    } catch (_) {}
    currentUrl = null;
    currentItemIndex = null;
    setPlaying(false);
    setBuffering(false);
    setHasFirstFrame(false);
    setError(null);
  }

  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    try {
      player.stop();
      player.dispose();
    } catch (_) {}
    isPlaying.dispose();
    isBuffering.dispose();
    hasFirstFrame.dispose();
    error.dispose();
  }
}

/// Central circular pre-streaming pool for Reels / Product Details.
///
/// Features:
/// - Maintains 3 persistent native players (Current Active, Next Upcoming, Previous)
/// - Zero decoder recreation during swipe transitions
/// - Synchronous slot assignment for 0ms initial frame attachment
/// - Pre-streams next video to frame 0 in the background with adaptive bitrate (HLS / MP4)
/// - Instant 0ms playback transition when scrolling to next product/reel
/// - Prevents Android OMX / iOS hardware decoder exhaustion
class ReelsVideoControllerPool extends ChangeNotifier {
  static final ReelsVideoControllerPool _instance =
      ReelsVideoControllerPool._internal();
  static ReelsVideoControllerPool get instance => _instance;

  ReelsVideoControllerPool._internal();

  static const int poolSize = 4;
  final List<ReelsPlayerSlot> _slots = [];
  bool _initialized = false;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  int? _activeProductIndex;
  int? get activeProductIndex => _activeProductIndex;

  String? _activeUrl;
  String? get activeUrl => _activeUrl;

  bool _isGloballyPaused = false;
  bool get isGloballyPaused => _isGloballyPaused;

  void init() {
    if (_initialized) return;
    _initialized = true;

    for (int i = 0; i < poolSize; i++) {
      final player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 2 * 1024 * 1024, // 2MB lightweight buffer
          logLevel: MPVLogLevel.warn,
        ),
      );

      final controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );

      _applyMpvProperties(player);

      try {
        player.setPlaylistMode(PlaylistMode.none);
        player.setVolume(_isMuted ? 0.0 : 100.0);
      } catch (_) {}

      _slots.add(
        ReelsPlayerSlot(
          index: i,
          player: player,
          videoController: controller,
        ),
      );
    }
  }

  Future<void> _applyMpvProperties(Player player) async {
    try {
      final platform = player.platform;
      if (platform == null) return;
      final p = platform as dynamic;
      await Future.wait(<Future<dynamic>>[
        p.setProperty('hwdec', 'auto-safe'),
        // Auto adaptive bitrate: dynamically adjusts quality based on network throughput
        p.setProperty('hls-bitrate', 'auto'),
        p.setProperty('cache', 'yes'),
        p.setProperty('cache-secs', '10'),
        p.setProperty('demuxer-lavf-analyzeduration', '0'),
        p.setProperty('demuxer-lavf-probesize', '1048576'),
        p.setProperty('cache-pause', 'no'),
        p.setProperty('cache-pause-wait', '0'),
        p.setProperty('cache-pause-initial', 'no'),
        p.setProperty('demuxer-readahead-secs', '5'),
        p.setProperty('demuxer-max-bytes', '25MiB'),
        // Retain past demuxed packets in memory so rewinding and looping back to 0 is 0ms instant!
        p.setProperty('demuxer-max-back-bytes', '25MiB'),
        // Native infinite file loop: avoids Dart playlist reload & network re-fetching on loop!
        p.setProperty('loop-file', 'inf'),
        p.setProperty('network-timeout', '10'),
        p.setProperty('user-agent', 'CloudflareStream-Flutter-MediaKit'),
        p.setProperty('vd-lavc-fast', 'yes'),
        p.setProperty('vd-lavc-skiploopfilter', 'all'),
      ]);
    } catch (_) {}
  }

  /// Get slot mapped to a specific product index and URL
  ReelsPlayerSlot? getSlotForIndex(int itemIndex, String url) {
    if (!_initialized) return null;
    for (final slot in _slots) {
      if (slot.currentItemIndex == itemIndex && slot.currentUrl == url) {
        return slot;
      }
    }
    return null;
  }

  ReelsPlayerSlot? get activeSlot {
    for (final slot in _slots) {
      if (slot.currentItemIndex == _activeProductIndex) {
        return slot;
      }
    }
    return _slots.isNotEmpty ? _slots.first : null;
  }

  /// Adopts an active feed player (already playing on home feed) into the Reels pool.
  /// Eliminates any loading spinner, black flash, or reload when entering product details.
  ReelsPlayerSlot adoptFeedPlayer({
    required FeedPlayerState feedPlayer,
    required int itemIndex,
    required String url,
  }) {
    if (!_initialized) {
      init();
    }

    final slot = _slots.first;
    slot.reattach(feedPlayer.player, feedPlayer.videoController);
    slot.currentItemIndex = itemIndex;
    slot.currentUrl = url;
    slot.setHasFirstFrame(true);
    slot.setBuffering(false);
    slot.setPlaying(true);

    _activeProductIndex = itemIndex;
    _activeUrl = url;
    _isGloballyPaused = false;

    // Pause other slots if any
    for (int i = 1; i < _slots.length; i++) {
      try {
        _slots[i].player.pause();
      } catch (_) {}
    }

    // Unmute for full screen reels
    try {
      slot.player.setVolume(_isMuted ? 0.0 : 100.0);
    } catch (_) {}

    return slot;
  }

  /// Synchronous active playback request for current visible product/reel
  ReelsPlayerSlot activateVideo({
    required int itemIndex,
    required String url,
    List<String>? nextUrls,
    String? prevUrl,
    String? secondPrevUrl,
    Duration? initialPosition,
  }) {
    if (!_initialized) {
      init();
    }

    if (url.trim().isEmpty) {
      return _slots.first;
    }

    _activeProductIndex = itemIndex;
    _activeUrl = url;
    _isGloballyPaused = false;

    // 1. Check if ANY slot already has this video
    ReelsPlayerSlot? activeSlot;
    for (final slot in _slots) {
      if (slot.currentItemIndex == itemIndex && slot.currentUrl == url) {
        activeSlot = slot;
        break;
      }
    }

    // 2. If not found, assign the best slot and immediately open
    if (activeSlot == null) {
      activeSlot = _findBestSlotFor(itemIndex);
      _loadMediaIntoSlot(
        activeSlot,
        itemIndex,
        url,
        autoPlay: true,
        initialPosition: initialPosition,
      );
    } else {
      // Slot already has this media - play immediately
      activeSlot.player.setVolume(_isMuted ? 0.0 : 100.0);
      try {
        activeSlot.player.play();
      } catch (_) {}
    }

    // 3. Pause all other slots
    for (final slot in _slots) {
      if (slot != activeSlot) {
        try {
          slot.player.pause();
        } catch (_) {}
      }
    }

    // 4. Pre-warm BOTH Next and Previous videos in background for seamless bidirectional swiping
    _prewarmSurroundingVideos(
      currentItemIndex: itemIndex,
      nextUrls: nextUrls,
      prevUrl: prevUrl,
      secondPrevUrl: secondPrevUrl,
    );

    return activeSlot;
  }

  /// Pre-streams BOTH next and previous videos into idle slots so they are ready at frame 0.
  /// Preserves the ideal [previous, active, next] distribution across the 3 pool slots.
  void _prewarmSurroundingVideos({
    required int currentItemIndex,
    required List<String>? nextUrls,
    required String? prevUrl,
    String? secondPrevUrl,
  }) {
    final int nextIndex = currentItemIndex + 1;
    final String? nextUrl = (nextUrls != null && nextUrls.isNotEmpty)
        ? nextUrls.first.trim()
        : null;

    final int prevIndex = currentItemIndex - 1;
    final String? pUrl = (prevUrl != null && prevUrl.trim().isNotEmpty && currentItemIndex > 0)
        ? prevUrl.trim()
        : null;

    final wantedTargets = <int, String>{};
    if (nextUrl != null && nextUrl.isNotEmpty) {
      wantedTargets[nextIndex] = nextUrl;
    }
    if (pUrl != null && pUrl.isNotEmpty) {
      wantedTargets[prevIndex] = pUrl;
      // If at the end of the feed (no next video), pre-warm second previous video to keep all slots warm
      if (nextUrl == null && secondPrevUrl != null && secondPrevUrl.trim().isNotEmpty && currentItemIndex > 1) {
        wantedTargets[currentItemIndex - 2] = secondPrevUrl.trim();
      }
    } else if (nextUrls != null && nextUrls.length > 1) {
      final secondNextUrl = nextUrls[1].trim();
      if (secondNextUrl.isNotEmpty) {
        wantedTargets[currentItemIndex + 2] = secondNextUrl;
      }
    }

    for (final entry in wantedTargets.entries) {
      final targetIdx = entry.key;
      final targetUrl = entry.value;

      // 1. Check if already loaded in any slot
      final alreadyLoaded = _slots.any(
        (s) => s.currentUrl == targetUrl && s.currentItemIndex == targetIdx,
      );
      if (alreadyLoaded) continue;

      // 2. Find a candidate slot that is NOT activeIndex AND NOT another target already loaded
      ReelsPlayerSlot? candidate;

      // Prefer empty slot first
      for (final slot in _slots) {
        if (slot.currentUrl == null) {
          candidate = slot;
          break;
        }
      }

      // If no empty slot, pick a slot that doesn't hold activeIndex or another wanted target
      if (candidate == null) {
        for (final slot in _slots) {
          if (slot.currentItemIndex == currentItemIndex) continue;
          final isOtherWantedTarget = wantedTargets.keys.any(
            (k) => k != targetIdx && slot.currentItemIndex == k,
          );
          if (isOtherWantedTarget) continue;

          candidate = slot;
          break;
        }
      }

      // Fallback: any non-active slot
      if (candidate == null) {
        for (final slot in _slots) {
          if (slot.currentItemIndex != currentItemIndex) {
            candidate = slot;
            break;
          }
        }
      }

      if (candidate != null) {
        _loadMediaIntoSlot(candidate, targetIdx, targetUrl, autoPlay: false);
      }
    }
  }

  ReelsPlayerSlot _findBestSlotFor(int targetIndex) {
    // 1. Look for an empty slot
    for (final slot in _slots) {
      if (slot.currentUrl == null) {
        return slot;
      }
    }

    // 2. Look for a slot furthest away from targetIndex
    ReelsPlayerSlot bestSlot = _slots.first;
    int maxDist = -1;

    for (final slot in _slots) {
      if (slot.currentItemIndex == null) return slot;
      final dist = (slot.currentItemIndex! - targetIndex).abs();
      if (dist > maxDist) {
        maxDist = dist;
        bestSlot = slot;
      }
    }

    return bestSlot;
  }

  void _loadMediaIntoSlot(
    ReelsPlayerSlot slot,
    int itemIndex,
    String url, {
    required bool autoPlay,
    Duration? initialPosition,
  }) {
    if (slot.currentUrl == url && slot.currentItemIndex == itemIndex) {
      if (autoPlay && !slot.player.state.playing) {
        slot.player.setVolume(_isMuted ? 0.0 : 100.0);
        if (initialPosition != null && initialPosition > Duration.zero) {
          try {
            slot.player.seek(initialPosition);
          } catch (_) {}
        }
        try {
          slot.player.play();
        } catch (_) {}
      }
      return;
    }

    slot.currentItemIndex = itemIndex;
    slot.currentUrl = url;
    slot.setHasFirstFrame(false);
    slot.setBuffering(true);
    slot.setError(null);

    final cachedPath = VideoCacheManager.instance.getCachedFilePath(url);
    final playUrl = cachedPath ?? url;

    try {
      slot.player.setVolume(autoPlay ? (_isMuted ? 0.0 : 100.0) : 0.0);
      final startPos =
          (initialPosition != null && initialPosition > Duration.zero)
              ? initialPosition
              : null;
      slot.player.open(Media(playUrl, start: startPos), play: autoPlay);
      // Note: player.open(play: false) already pauses at frame 0 natively.
      // Do NOT call slot.player.pause() here — it races with the async loadfile
      // command and can cause state desynchronization in libmpv.
    } catch (e) {
      debugPrint('⚠️ [ReelsVideoControllerPool] Error opening $url: $e');
    }

    // If not cached, trigger background caching with top priority
    if (cachedPath == null && url.startsWith('http')) {
      VideoCacheManager.instance.preCachePriority(url);
    }
  }

  void _applyVolumeToSlots() {
    for (final slot in _slots) {
      if (slot.currentItemIndex == _activeProductIndex) {
        try {
          slot.player.setVolume(_isMuted ? 0.0 : 100.0);
        } catch (_) {}
      } else {
        try {
          slot.player.setVolume(0.0);
        } catch (_) {}
      }
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _applyVolumeToSlots();
    notifyListeners();
  }

  void setMuted(bool muted) {
    if (_isMuted != muted) {
      _isMuted = muted;
      _applyVolumeToSlots();
      notifyListeners();
    }
  }

  void pauseAll() {
    _isGloballyPaused = true;
    for (final slot in _slots) {
      try {
        slot.player.pause();
      } catch (_) {}
    }
    notifyListeners();
  }

  void resume() {
    _isGloballyPaused = false;
    if (_activeProductIndex != null && _activeUrl != null) {
      final slot = getSlotForIndex(_activeProductIndex!, _activeUrl!);
      if (slot != null) {
        try {
          slot.player.setVolume(_isMuted ? 0.0 : 100.0);
          slot.player.play();
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  void releaseSession() {
    _isGloballyPaused = true;
    _activeProductIndex = null;
    _activeUrl = null;
    for (final slot in _slots) {
      slot.reset();
    }
    notifyListeners();
  }

  bool _isNotificationScheduled = false;

  @override
  void notifyListeners() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        WidgetsBinding.instance.buildOwner?.debugBuilding == true) {
      if (!_isNotificationScheduled) {
        _isNotificationScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isNotificationScheduled = false;
          super.notifyListeners();
        });
      }
    } else {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final slot in _slots) {
      slot.dispose();
    }
    _slots.clear();
    _initialized = false;
    super.dispose();
  }
}
