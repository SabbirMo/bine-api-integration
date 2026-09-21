import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:binetatour/core/video/feed_video_manager.dart';
import 'package:binetatour/core/video/network_quality_estimator.dart';
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
  final ValueNotifier<Duration> duration = ValueNotifier<Duration>(
    Duration.zero,
  );

  void setPlaying(bool val) => _safeUpdate(isPlaying, val);
  void setBuffering(bool val) => _safeUpdate(isBuffering, val);
  void setHasFirstFrame(bool val) => _safeUpdate(hasFirstFrame, val);
  void setError(String? val) => _safeUpdate(error, val);
  void setIsLandscape(bool val) => _safeUpdate(isLandscape, val);
  void setCompleted(bool val) => _safeUpdate(isCompleted, val);
  void setDuration(Duration val) => _safeUpdate(duration, val);

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
      final isBufferingNow = player.state.buffering;

      // Frame is ready ONLY when playback clock has genuinely advanced past Duration.zero.
      // NEVER trigger on width > 0 alone because width is decoded from the container header
      // before any video frame has actually been rendered to the texture, which caused a black flash!
      if (pos > Duration.zero && !isBufferingNow) {
        setHasFirstFrame(true);
        setBuffering(false);
      }
    }

    void checkCompletion(bool fromCompletedStream) {
      // Seamless auto-loop: When video reaches end, immediately loop back to 0 and continue playing.
      // Never pause or show a restart/replay button.
      setCompleted(false);
      if (ReelsVideoControllerPool.instance.activeProductIndex ==
              currentItemIndex &&
          !ReelsVideoControllerPool.instance.isGloballyPaused) {
        try {
          player.seek(Duration.zero).then((_) {
            player.play().catchError((_) {});
          }).catchError((_) {});
        } catch (_) {}
      }
    }

    _subscriptions.add(
      player.stream.playing.listen((p) {
        setPlaying(p);
        if (p) {
          final pos = player.state.position;
          final dur = player.state.duration;
          final isAtEnd =
              isCompleted.value &&
              dur > Duration.zero &&
              pos >= dur - const Duration(milliseconds: 1500);
          if (!isAtEnd) {
            setCompleted(false);
          }
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
        if (b && hasFirstFrame.value) {
          // Mid-stream buffer stall detected -> downgrade ABR tier to LOW (240p) so playback recovers instantly!
          NetworkQualityEstimator.instance.recordPlaybackStall();
        }
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
          updateDimensions(params.w, params.h);
          if (!player.state.buffering) {
            checkFirstFrameReady();
          }
        }
      }),
    );
    _subscriptions.add(
      player.stream.width.listen((w) {
        if (w != null && w > 0) {
          updateDimensions(w, player.state.height);
          if (!player.state.buffering) {
            checkFirstFrameReady();
          }
        }
      }),
    );
    _subscriptions.add(
      player.stream.position.listen((pos) {
        if (pos > Duration.zero) {
          checkFirstFrameReady();
          if (isBuffering.value && player.state.playing) {
            setBuffering(false);
          }
        }
        // Note: NEVER call checkCompletion from position.listen!
        // Completion must solely be signaled by player.stream.completed.
      }),
    );
    _subscriptions.add(
      player.stream.duration.listen((dur) {
        if (dur > Duration.zero) {
          setDuration(dur);
        }
      }),
    );

    _subscriptions.add(
      player.stream.error.listen((err) {
        final errStr = err.toString().toLowerCase();
        // Filter harmless errors from slot recycling and audio device
        if (errStr.contains('audio device') ||
            errStr.contains('no sound') ||
            errStr.contains('coreaudio') ||
            errStr.contains('ao: ') ||
            errStr.contains('audio output') ||
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
      (player.platform as dynamic)?.setProperty('aid', 'no');
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
    setDuration(Duration.zero);
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
    duration.dispose();
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
          bufferSize:
              (1.5 * 1024 * 1024) ~/
              1, // 1.5MB tuned for instant first-frame start on slow/weak networks
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
      final hlsBitrate = NetworkQualityEstimator.instance.getMpvHlsBitrate();
      await Future.wait(<Future<dynamic>>[
        p.setProperty('hwdec', 'auto-safe'),
        // Dynamic Adaptive Bitrate (ABR): starts at 240p (min) for instant startup, ramps up to 360p/480p/720p as bandwidth allows
        p.setProperty('hls-bitrate', hlsBitrate),
        p.setProperty('cache', 'yes'),
        p.setProperty('cache-secs', '6'),
        p.setProperty('cache-pause', 'yes'),
        p.setProperty('cache-pause-wait', '1'),
        p.setProperty('cache-pause-initial', 'no'),
        p.setProperty('demuxer-lavf-analyzeduration', '0'),
        p.setProperty('demuxer-lavf-probesize', '32768'),
        p.setProperty('force-seekable', 'yes'),
        p.setProperty('demuxer-readahead-secs', '3'),
        p.setProperty('demuxer-max-bytes', '8MiB'),
        // Retain past demuxed packets in memory so rewinding and looping back to 0 is 0ms instant!
        p.setProperty('demuxer-max-back-bytes', '20MiB'),
        // Native infinite loop: seamlessly loops video without Dart reload or network re-fetching
        p.setProperty('loop-file', 'inf'),
        p.setProperty('network-timeout', '15'),
        p.setProperty('user-agent', 'CloudflareStream-Flutter-MediaKit'),
        p.setProperty('audio-stream-silence', 'yes'),
        p.setProperty('ao-null-fallback', 'yes'),
        p.setProperty('vd-lavc-fast', 'yes'),
        p.setProperty('vd-lavc-skiploopfilter', 'all'),
        p.setProperty('audio-buffer', '0.05'),
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

    // Unmute for full screen reels
    try {
      slot.player.setVolume(_isMuted ? 0.0 : 100.0);
    } catch (_) {}

    // Pause other slots and mute them
    for (int i = 1; i < _slots.length; i++) {
      try {
        _slots[i].player.setVolume(0.0);
        _slots[i].player.pause();
      } catch (_) {}
    }

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
      // Slot already has this media - restart from beginning like Instagram/TikTok
      activeSlot.setCompleted(false);
      try {
        (activeSlot.player.platform as dynamic)?.setProperty('aid', 'auto');
      } catch (_) {}
      activeSlot.player.setVolume(_isMuted ? 0.0 : 100.0);
      try {
        if (initialPosition != null && initialPosition > Duration.zero) {
          activeSlot.player.seek(initialPosition).catchError((_) {});
        } else if (activeSlot.isCompleted.value ||
            activeSlot.player.state.position >
                const Duration(milliseconds: 300)) {
          activeSlot.player.seek(Duration.zero).catchError((_) {});
        }
        activeSlot.player.play().catchError((_) {});
      } catch (_) {}
    }

    // 3. Pause all other slots, mute them, and rewind to 0 for instant fresh replay
    for (final slot in _slots) {
      if (slot != activeSlot) {
        try {
          (slot.player.platform as dynamic)?.setProperty('aid', 'no');
          slot.player.setVolume(0.0);
          slot.setCompleted(false);
          slot.player.pause().catchError((_) {});
          if (slot.player.state.position > const Duration(milliseconds: 300)) {
            slot.player.seek(Duration.zero).catchError((_) {});
          }
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
    // Fast 500ms debounce ensures the next reel is already primed & buffered at frame 0
    // well before the user swipes down, enabling instantaneous 0ms transition.
    _prewarmTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_initialized || _activeProductIndex != currentItemIndex) return;
      _prewarmSurroundingVideos(
        currentItemIndex: currentItemIndex,
        nextUrls: nextUrls,
        prevUrl: prevUrl,
        secondPrevUrl: secondPrevUrl,
      );
    });
  }

  /// Pre-streams BOTH next and previous videos into idle slots so they are ready at frame 0.
  /// Preserves the ideal [previous, active, next] distribution across the 3 pool slots.
  void _prewarmSurroundingVideos({
    required int currentItemIndex,
    required List<String>? nextUrls,
    required String? prevUrl,
    String? secondPrevUrl,
  }) {
    final Map<int, String> wantedTargets = {};

    // 1. Next target takes single highest priority (95% of user swipes are downward to next reel).
    // Prewarming only ONE candidate avoids splitting scarce mobile bandwidth across multiple simultaneous streams.
    final int nextIndex = currentItemIndex + 1;
    final String? nextUrl = (nextUrls != null && nextUrls.isNotEmpty)
        ? nextUrls.first.trim()
        : null;
    if (nextUrl != null && nextUrl.isNotEmpty) {
      wantedTargets[nextIndex] = nextUrl;
    } else {
      // 2. Fallback to previous target only if no next reel exists
      final int prevIndex = currentItemIndex - 1;
      final String? pUrl =
          (prevUrl != null && prevUrl.trim().isNotEmpty && currentItemIndex > 0)
          ? prevUrl.trim()
          : null;
      if (pUrl != null && pUrl.isNotEmpty) {
        wantedTargets[prevIndex] = pUrl;
      }
    }

    for (final entry in wantedTargets.entries) {
      final targetIdx = entry.key;
      final targetUrl = entry.value;

      final alreadyLoaded = _slots.any(
        (s) => s.currentUrl == targetUrl && s.currentItemIndex == targetIdx,
      );
      if (alreadyLoaded) continue;

      // Find candidate slot that is NOT active and NOT another wanted target
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
          if (slot.currentItemIndex == currentItemIndex) continue;
          final isOtherWanted = wantedTargets.keys.any(
            (k) => k != targetIdx && slot.currentItemIndex == k,
          );
          if (isOtherWanted) continue;
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
      slot.setCompleted(false);
      if (autoPlay && !slot.player.state.playing) {
        try {
          final aid = _isMuted ? 'no' : 'auto';
          (slot.player.platform as dynamic)?.setProperty('aid', aid);
          slot.player.setVolume(_isMuted ? 0.0 : 100.0);
        } catch (_) {}
        if (initialPosition != null && initialPosition > Duration.zero) {
          try {
            slot.player.seek(initialPosition).catchError((_) {});
          } catch (_) {}
        } else if (slot.isCompleted.value ||
            slot.player.state.position > const Duration(milliseconds: 300)) {
          try {
            slot.player.seek(Duration.zero).catchError((_) {});
          } catch (_) {}
        }
        try {
          slot.player.play().catchError((_) {});
        } catch (_) {}
      } else if (!autoPlay) {
        try {
          (slot.player.platform as dynamic)?.setProperty('aid', 'no');
          slot.player.setVolume(0.0);
          slot.player.pause().catchError((_) {});
        } catch (_) {}
        if (slot.player.state.position > const Duration(milliseconds: 300)) {
          try {
            slot.player.seek(Duration.zero).catchError((_) {});
          } catch (_) {}
        }
      }
      return;
    }

    slot.currentItemIndex = itemIndex;
    slot.currentUrl = url;
    slot.setHasFirstFrame(false);
    slot.setBuffering(autoPlay);
    slot.setError(null);

    final cachedPath = VideoCacheManager.instance.getCachedFilePath(url);
    final playUrl = cachedPath ?? url;

    try {
      if (autoPlay) {
        try {
          final aid = _isMuted ? 'no' : 'auto';
          (slot.player.platform as dynamic)?.setProperty('aid', aid);
          slot.player.setVolume(_isMuted ? 0.0 : 100.0);
        } catch (_) {}
      } else {
        try {
          (slot.player.platform as dynamic)?.setProperty('aid', 'no');
          slot.player.setVolume(0.0);
        } catch (_) {}
      }

      final hlsBitrate = NetworkQualityEstimator.instance.getMpvHlsBitrate();
      try {
        (slot.player.platform as dynamic)?.setProperty('hls-bitrate', hlsBitrate);
      } catch (_) {}

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
          (slot.player.platform as dynamic)?.setProperty(
            'aid',
            _isMuted ? 'no' : 'auto',
          );
          slot.player.setVolume(_isMuted ? 0.0 : 100.0);
        } catch (_) {}
      } else {
        try {
          (slot.player.platform as dynamic)?.setProperty('aid', 'no');
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
        (slot.player.platform as dynamic)?.setProperty('aid', 'no');
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
          (slot.player.platform as dynamic)?.setProperty(
            'aid',
            _isMuted ? 'no' : 'auto',
          );
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
