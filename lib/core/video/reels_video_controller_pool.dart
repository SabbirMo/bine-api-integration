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
  final ValueNotifier<bool> isLandscape = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isCompleted = ValueNotifier<bool>(false);

  void setPlaying(bool val) => _safeUpdate(isPlaying, val);
  void setBuffering(bool val) => _safeUpdate(isBuffering, val);
  void setHasFirstFrame(bool val) => _safeUpdate(hasFirstFrame, val);
  void setError(String? val) => _safeUpdate(error, val);
  void setIsLandscape(bool val) => _safeUpdate(isLandscape, val);
  void setCompleted(bool val) => _safeUpdate(isCompleted, val);

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
    setIsLandscape(false);
    setCompleted(false);
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

    void checkCompletion(bool fromCompletedStream) {
      final pos = player.state.position;
      final dur = player.state.duration;

      // Genuine completion check:
      // Video must have valid duration (> 3 seconds), must have rendered first frame,
      // and position must genuinely be near the end (within 500ms of duration).
      // This strictly prevents iOS VideoToolbox premature EOF events on initial chunk load/seek.
      if (dur > const Duration(seconds: 3) &&
          hasFirstFrame.value &&
          pos >= dur - const Duration(milliseconds: 500)) {
        setCompleted(true);
      } else {
        // Spurious completed event from iOS VideoToolbox/demuxer during startup/chunk transition:
        // Position is NOT genuinely at the end. Auto-resume immediately!
        setCompleted(false);
        if (ReelsVideoControllerPool.instance.activeProductIndex ==
                currentItemIndex &&
            !ReelsVideoControllerPool.instance.isGloballyPaused) {
          try {
            player.play().catchError((_) {});
          } catch (_) {}
        }
      }
    }

    _subscriptions.add(
      player.stream.playing.listen((p) {
        setPlaying(p);
        if (p) {
          setCompleted(false);
          checkFirstFrameReady();
        }
      }),
    );
    _subscriptions.add(
      player.stream.completed.listen((c) {
        if (!c) {
          setCompleted(false);
        } else {
          checkCompletion(true);
        }
      }),
    );
    _subscriptions.add(
      player.stream.buffering.listen((b) {
        // Suppress buffering spinner on instant seamless loops back to time 0
        if (b &&
            hasFirstFrame.value &&
            player.state.position < const Duration(milliseconds: 400)) {
          return;
        }
        setBuffering(b);
        if (!b) {
          checkFirstFrameReady();
        }
      }),
    );
    void updateDimensions(int? w, int? h) {
      if (w != null && h != null && w > 0 && h > 0) {
        // Only consider genuine horizontal/landscape videos (width > height * 1.15).
        // Standard portrait videos (9:16, 3:4, 4:5, etc.) stay full-screen cover like TikTok.
        final isLand = (w / h) > 1.15;
        setIsLandscape(isLand);
      }
    }

    if (player.state.width != null && player.state.height != null) {
      updateDimensions(player.state.width, player.state.height);
    }

    _subscriptions.add(
      player.stream.videoParams.listen((params) {
        if (params.w != null && params.w! > 0) {
          checkFirstFrameReady();
          updateDimensions(params.w, params.h);
        }
      }),
    );
    _subscriptions.add(
      player.stream.width.listen((w) {
        if (w != null && w > 0) {
          checkFirstFrameReady();
          updateDimensions(w, player.state.height);
        }
      }),
    );
    _subscriptions.add(
      player.stream.position.listen((pos) {
        if (pos > Duration.zero) {
          checkFirstFrameReady();
        }
        // Note: NEVER call checkCompletion from position.listen!
        // Completion must solely be signaled by player.stream.completed.
      }),
    );
    videoController.waitUntilFirstFrameRendered
        .then((_) {
          if (!player.state.buffering) {
            setHasFirstFrame(true);
            setBuffering(false);
          }
        })
        .catchError((_) {});

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
    setIsLandscape(false);
    setCompleted(false);
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
    isCompleted.dispose();
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

  static const int poolSize = 3;
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

      _applyMpvProperties(player, isAudioEnabled: false);

      try {
        player.setPlaylistMode(PlaylistMode.none);
        player.setVolume(_isMuted ? 0.0 : 100.0);
      } catch (_) {}

      _slots.add(
        ReelsPlayerSlot(index: i, player: player, videoController: controller),
      );
    }
  }

  Future<void> _applyMpvProperties(
    Player player, {
    bool isAudioEnabled = false,
  }) async {
    try {
      final platform = player.platform;
      if (platform == null) return;
      final p = platform as dynamic;
      await Future.wait(<Future<dynamic>>[
        p.setProperty('hwdec', 'auto-safe'),
        // Auto adaptive bitrate: dynamically adjusts quality based on network throughput
        p.setProperty('hls-bitrate', 'auto'),
        p.setProperty('cache', 'yes'),
        p.setProperty('cache-secs', '15'),
        p.setProperty('demuxer-readahead-secs', '8'),
        p.setProperty('demuxer-max-bytes', '32MiB'),
        // Retain past demuxed packets in memory so rewinding and looping back to 0 is 0ms instant!
        p.setProperty('demuxer-max-back-bytes', '25MiB'),
        // loop-file: no ensures completed event fires when video reaches end so replay icon appears
        p.setProperty('loop-file', 'no'),
        p.setProperty('network-timeout', '15'),
        p.setProperty('user-agent', 'CloudflareStream-Flutter-MediaKit'),
        p.setProperty('audio-stream-silence', 'yes'),
        p.setProperty('ao-null-fallback', 'yes'),
        // Disable audio track on background/idle slots to prevent AVAudioSession conflict on iOS
        p.setProperty('aid', isAudioEnabled ? 'auto' : 'no'),
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

    // Enable audio on active slot
    try {
      (slot.player.platform as dynamic)?.setProperty('aid', 'auto');
    } catch (_) {}

    // Pause other slots and disable audio
    for (int i = 1; i < _slots.length; i++) {
      try {
        (slot.player.platform as dynamic)?.setProperty('aid', 'no');
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
      // Slot already has this media - play without destructive seek interruption
      activeSlot.setCompleted(false);
      try {
        (activeSlot.player.platform as dynamic)?.setProperty('aid', 'auto');
      } catch (_) {}
      activeSlot.player.setVolume(_isMuted ? 0.0 : 100.0);
      try {
        if (initialPosition != null && initialPosition > Duration.zero) {
          activeSlot.player.seek(initialPosition).catchError((_) {});
        }
        activeSlot.player.play().catchError((_) {});
      } catch (_) {}
    }

    // 3. Pause all other slots and disable their audio so iOS AVAudioSession belongs 100% to activeSlot
    for (final slot in _slots) {
      if (slot != activeSlot) {
        try {
          (slot.player.platform as dynamic)?.setProperty('aid', 'no');
          slot.setCompleted(false);
          slot.player.pause().catchError((_) {});
        } catch (_) {}
      }
    }

    // 4. Pre-warm surrounding video in background with debounce so active video has 100% bandwidth
    _schedulePrewarmSurroundingVideos(
      currentItemIndex: itemIndex,
      nextUrls: nextUrls,
      prevUrl: prevUrl,
      secondPrevUrl: secondPrevUrl,
    );

    return activeSlot;
  }

  Timer? _prewarmTimer;

  void _schedulePrewarmSurroundingVideos({
    required int currentItemIndex,
    required List<String>? nextUrls,
    required String? prevUrl,
    String? secondPrevUrl,
  }) {
    _prewarmTimer?.cancel();
    // Allow the active video 800ms of dedicated network & CPU bandwidth
    // to render and buffer its first chunks cleanly before prewarming background candidates.
    _prewarmTimer = Timer(const Duration(milliseconds: 800), () {
      if (!_initialized || _activeProductIndex != currentItemIndex) return;
      _prewarmSurroundingVideos(
        currentItemIndex: currentItemIndex,
        nextUrls: nextUrls,
        prevUrl: prevUrl,
        secondPrevUrl: secondPrevUrl,
      );
    });
  }

  /// Pre-streams next video into idle slot so it is ready at frame 0.
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

    if (nextUrl != null && nextUrl.isNotEmpty) {
      final alreadyLoaded = _slots.any(
        (s) => s.currentUrl == nextUrl && s.currentItemIndex == nextIndex,
      );
      if (!alreadyLoaded) {
        ReelsPlayerSlot? candidate;
        for (final slot in _slots) {
          if (slot.currentItemIndex != currentItemIndex &&
              slot.currentUrl == null) {
            candidate = slot;
            break;
          }
        }
        if (candidate == null) {
          for (final slot in _slots) {
            if (slot.currentItemIndex != currentItemIndex) {
              candidate = slot;
              break;
            }
          }
        }
        if (candidate != null) {
          _loadMediaIntoSlot(candidate, nextIndex, nextUrl, autoPlay: false);
        }
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
      slot.setCompleted(false);
      if (autoPlay && !slot.player.state.playing) {
        try {
          (slot.player.platform as dynamic)?.setProperty('aid', 'auto');
        } catch (_) {}
        slot.player.setVolume(_isMuted ? 0.0 : 100.0);
        if (initialPosition != null && initialPosition > Duration.zero) {
          try {
            slot.player.seek(initialPosition).catchError((_) {});
          } catch (_) {}
        }
        try {
          slot.player.play().catchError((_) {});
        } catch (_) {}
      } else if (!autoPlay) {
        try {
          (slot.player.platform as dynamic)?.setProperty('aid', 'no');
          slot.player.pause().catchError((_) {});
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
      if (autoPlay) {
        try {
          (slot.player.platform as dynamic)?.setProperty('aid', 'auto');
        } catch (_) {}
        slot.player.setVolume(_isMuted ? 0.0 : 100.0);
      } else {
        try {
          (slot.player.platform as dynamic)?.setProperty('aid', 'no');
        } catch (_) {}
        slot.player.setVolume(0.0);
      }

      final startPos =
          (initialPosition != null && initialPosition > Duration.zero)
          ? initialPosition
          : null;
      slot.player.open(Media(playUrl, start: startPos), play: autoPlay);
    } catch (e) {
      debugPrint('⚠️ [ReelsVideoControllerPool] Error opening $url: $e');
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

  void resume({bool force = false}) {
    if (_isGloballyPaused && !force) return;
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
    _prewarmTimer?.cancel();
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
    _prewarmTimer?.cancel();
    for (final slot in _slots) {
      slot.dispose();
    }
    _slots.clear();
    _initialized = false;
    super.dispose();
  }
}
