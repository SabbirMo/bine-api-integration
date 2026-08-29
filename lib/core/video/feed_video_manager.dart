import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';

class FeedPlayerState {
  final Player player;
  final VideoController videoController;
  String? currentUrl;
  String? currentKey;
  bool isPlaying;
  bool isBuffering;
  bool hasFirstFrame;
  bool isMuted;

  StreamSubscription? _playingSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _positionSub;

  FeedPlayerState({
    required this.player,
    required this.videoController,
    this.currentUrl,
    this.currentKey,
    this.isPlaying = false,
    this.isBuffering = false,
    this.hasFirstFrame = false,
    this.isMuted = true,
  });

  void listen(VoidCallback onUpdate) {
    _playingSub = player.stream.playing.listen((playing) {
      isPlaying = playing;
      onUpdate();
    });

    _bufferingSub = player.stream.buffering.listen((buffering) {
      isBuffering = buffering;
      onUpdate();
    });

    _positionSub = player.stream.position.listen((pos) {
      if (pos > Duration.zero && !hasFirstFrame) {
        hasFirstFrame = true;
        isBuffering = false;
        onUpdate();
      }
    });

    _errorSub = player.stream.error.listen((error) {
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('audio device') || errorStr.contains('no sound')) {
        return; // Ignore harmless audio device warning for muted feed players
      }
      debugPrint("⚠️ [FeedVideoManager] Player error for $currentKey: $error");
      isBuffering = false;
      onUpdate();
    });
  }

  void stopAndReset() {
    try {
      player.stop();
    } catch (_) {}
    currentUrl = null;
    currentKey = null;
    isPlaying = false;
    isBuffering = false;
    hasFirstFrame = false;
  }

  void dispose() {
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _positionSub?.cancel();
    _errorSub?.cancel();
    try {
      player.stop();
      player.dispose();
    } catch (_) {}
  }
}

/// Robust, rock-solid central video manager:
/// - Maximum 3 native players to strictly prevent OS codec saturation and app crashes
/// - Zero delay instant auto-play on active card
/// - Local disk cached playback
class FeedVideoManager extends ChangeNotifier {
  static final FeedVideoManager _instance = FeedVideoManager._internal();
  static FeedVideoManager get instance => _instance;

  FeedVideoManager._internal();

  /// Strictly keep pool size <= 3 to ensure stability across all Android/iOS devices
  static const int maxPoolSize = 3;

  final Map<String, String> _urlMap = {};

  // Section-level tracking (Home page)
  final Map<String, String> _sectionActiveKey = {};
  final Map<String, double> _sectionVisibility = {};
  final Map<String, double> _sectionCenterY = {};
  // Card-level tracking (Boutique grid & individual cards)
  final Map<String, double> _cardVisibility = {};
  final Map<String, double> _cardCenterY = {};

  // Context-level tracking for real-time live coordinate calculations
  final Map<String, BuildContext> _cardContexts = {};
  final Map<String, BuildContext> _sectionContexts = {};

  void registerCardContext(String key, BuildContext context) {
    _cardContexts[key] = context;
  }

  void unregisterCardContext(String key) {
    _cardContexts.remove(key);
  }

  void registerSectionContext(String sectionId, BuildContext context) {
    _sectionContexts[sectionId] = context;
  }

  void unregisterSectionContext(String sectionId) {
    _sectionContexts.remove(sectionId);
  }

  final List<FeedPlayerState> _playerPool = [];
  final Map<String, FeedPlayerState> _keyToPlayer = {};

  String? _currentPlayingKey;
  String? get currentPlayingKey => _currentPlayingKey;

  bool _isGloballyPaused = false;
  bool get isGloballyPaused => _isGloballyPaused;

  bool _isFeedMuted = true;
  bool get isFeedMuted => _isFeedMuted;

  void toggleFeedMute() {
    _isFeedMuted = !_isFeedMuted;
    for (final p in _playerPool) {
      try {
        p.player.setVolume(_isFeedMuted ? 0.0 : 100.0);
      } catch (_) {}
    }
    notifyListeners();
  }

  FeedPlayerState _createPlayerState() {
    final player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024, // 32 MB — enough for HLS segments
        logLevel: MPVLogLevel.warn,
      ),
    );

    final controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    // Apply HLS-optimized MPV properties asynchronously
    _applyMpvProperties(player);

    try {
      player.setPlaylistMode(PlaylistMode.loop);
      player.setVolume(_isFeedMuted ? 0.0 : 100.0);
    } catch (_) {}

    final state = FeedPlayerState(player: player, videoController: controller);

    state.listen(() {
      notifyListeners();
    });

    return state;
  }

  /// Applies Cloudflare Stream-optimized MPV properties to a [Player].
  Future<void> _applyMpvProperties(Player player) async {
    try {
      final platform = player.platform;
      if (platform == null) return;
      final p = platform as dynamic;
      await p.setProperty('hls-bitrate', 'auto');
      await p.setProperty('cache', 'yes');
      await p.setProperty('cache-secs', '5');
      await p.setProperty('demuxer-readahead-secs', '5');
      await p.setProperty('demuxer-max-bytes', '32MiB');
      await p.setProperty('demuxer-max-back-bytes', '8MiB');
      await p.setProperty('network-timeout', '10');
      await p.setProperty('user-agent', 'CloudflareStream-Flutter-MediaKit');
    } catch (_) {}
  }

  FeedPlayerState _getOrCreatePlayer(
    String key,
    String url, {
    bool autoPlay = false,
  }) {
    final cachedPath = VideoCacheManager.instance.getCachedFilePath(url);
    final targetUrl = cachedPath ?? url;

    // A. Check if the player mapped to this key already has this exact URL loaded
    if (_keyToPlayer.containsKey(key)) {
      final state = _keyToPlayer[key]!;
      if (state.currentUrl == url) {
        if (autoPlay && !state.isPlaying) {
          try {
            state.player.play();
          } catch (_) {}
        } else if (!autoPlay && state.isPlaying) {
          try {
            state.player.pause();
          } catch (_) {}
        }
        return state;
      }
    }

    // B. Check if ANY player in the pool already has this exact URL loaded in memory
    for (final p in _playerPool) {
      if (p.currentUrl == url) {
        if (p.currentKey != null && p.currentKey != key) {
          _keyToPlayer.remove(p.currentKey);
        }
        p.currentKey = key;
        _keyToPlayer[key] = p;
        p.hasFirstFrame = true;
        p.isBuffering = false;
        if (autoPlay && !p.isPlaying) {
          try {
            p.player.play();
          } catch (_) {}
        }
        return p;
      }
    }

    FeedPlayerState? state;

    // 1. Try finding an idle player in the pool
    for (final p in _playerPool) {
      if (p.currentKey == null) {
        state = p;
        break;
      }
    }

    // 2. If pool not full, create new player
    if (state == null && _playerPool.length < maxPoolSize) {
      state = _createPlayerState();
      _playerPool.add(state);
    }

    // 3. If pool is full, reuse a player not currently playing
    if (state == null && _playerPool.isNotEmpty) {
      for (final p in _playerPool) {
        if (p.currentKey != _currentPlayingKey) {
          state = p;
          if (p.currentKey != null) {
            _keyToPlayer.remove(p.currentKey);
          }
          try {
            state.player.pause();
          } catch (_) {}
          break;
        }
      }
    }

    state ??= _playerPool.first;

    // Reassign state
    final bool isKeyChanged = state.currentKey != key;
    final bool isUrlChanged = state.currentUrl != url;

    if (state.currentKey != null && state.currentKey != key) {
      _keyToPlayer.remove(state.currentKey);
    }

    state.currentKey = key;
    _keyToPlayer[key] = state;

    if (isKeyChanged || isUrlChanged) {
      state.currentUrl = url;
      state.hasFirstFrame = false;
      state.isBuffering = true;
      final playerToOpen = state.player;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          playerToOpen.open(Media(targetUrl), play: autoPlay);
        } catch (_) {}
      });
    } else if (autoPlay && !state.isPlaying) {
      try {
        state.player.play();
      } catch (_) {}
    } else if (!autoPlay && state.isPlaying) {
      try {
        state.player.pause();
      } catch (_) {}
    }

    return state;
  }

  /// Clear all cards starting with a prefix (e.g. 'boutique_')
  void clearCategoryCards(String prefix) {
    final keysToRemove = _urlMap.keys
        .where((k) => k.startsWith(prefix))
        .toList();
    for (final k in keysToRemove) {
      _urlMap.remove(k);
      _cardVisibility.remove(k);
      _cardCenterY.remove(k);
      if (_currentPlayingKey == k) {
        try {
          _keyToPlayer[k]?.player.pause();
        } catch (_) {}
        _currentPlayingKey = null;
      }
      final state = _keyToPlayer.remove(k);
      if (state != null) {
        state.stopAndReset();
      }
    }
    _evaluatePlayback();
  }

  /// Register card's video URL & pre-cache to local storage
  void registerCardUrl(String key, String url) {
    if (url.trim().isEmpty) return;
    _urlMap[key] = url;
    VideoCacheManager.instance.preCacheVideo(url);
  }

  /// Update vertical visibility for a section (Home Page)
  void updateSectionVisibility(
    String sectionId,
    double visibleFraction,
    double centerY,
  ) {
    if (visibleFraction <= 0.05) {
      _sectionVisibility.remove(sectionId);
      _sectionCenterY.remove(sectionId);
    } else {
      _sectionVisibility[sectionId] = visibleFraction;
      _sectionCenterY[sectionId] = centerY;
    }

    if (!_isGloballyPaused) {
      _evaluatePlayback();
    }
  }

  /// Set the active horizontal card for a section (Home Page)
  void setActiveSectionCard(String sectionId, String cardKey, String url) {
    _sectionActiveKey[sectionId] = cardKey;
    if (url.trim().isNotEmpty) {
      _urlMap[cardKey] = url;
      VideoCacheManager.instance.preCacheVideo(url);
    }

    if (!_isGloballyPaused) {
      _evaluatePlayback();
    }
  }

  /// Called when a card's visibility changes in a grid (Boutique Page)
  void onCardVisibilityChanged(
    String key,
    String url,
    double visibleFraction, {
    double cardCenterY = 0.0,
  }) {
    if (url.trim().isEmpty) return;

    if (visibleFraction <= 0.05) {
      _cardVisibility.remove(key);
      _cardCenterY.remove(key);
      _urlMap.remove(key);
      final state = _keyToPlayer.remove(key);
      if (state != null) {
        state.stopAndReset();
      }
      if (_currentPlayingKey == key) {
        _currentPlayingKey = null;
      }
    } else {
      _cardVisibility[key] = visibleFraction;
      _cardCenterY[key] = cardCenterY;
      _urlMap[key] = url;
      VideoCacheManager.instance.preCacheVideo(url);
    }

    if (!_isGloballyPaused) {
      _evaluatePlayback();
    }
  }

  int _activeTabIndex = 0;
  int get activeTabIndex => _activeTabIndex;

  double _viewportHeight = 800.0;
  void updateViewportHeight(double height) {
    if (height > 0 && (_viewportHeight - height).abs() > 1.0) {
      _viewportHeight = height;
    }
  }

  double _scrollRatio = 0.0;
  double get scrollRatio => _scrollRatio;

  void updateScrollRatio(double ratio) {
    final clamped = ratio.clamp(0.0, 1.0);
    if ((_scrollRatio - clamped).abs() > 0.02) {
      _scrollRatio = clamped;
      if (!_isGloballyPaused) {
        _evaluatePlayback();
      }
    }
  }

  bool _isAtBottom = false;
  bool get isAtBottom => _isAtBottom;

  void setIsAtBottom(bool atBottom) {
    if (_isAtBottom != atBottom) {
      _isAtBottom = atBottom;
      if (atBottom) {
        _scrollRatio = 1.0;
      }
      if (!_isGloballyPaused) {
        _evaluatePlayback();
      }
    }
  }

  void setActiveTab(int tabIndex) {
    if (_activeTabIndex != tabIndex) {
      _activeTabIndex = tabIndex;
      _isAtBottom = false;
      _scrollRatio = 0.0;
      pauseAll();
      _currentPlayingKey = null;
      if (tabIndex != 2) {
        _isGloballyPaused = false;
        _evaluatePlayback();
      }
    }
  }

  void evaluatePlaybackNow() {
    if (!_isGloballyPaused) {
      _evaluatePlayback();
    }
  }

  void _evaluatePlayback() {
    if (_isGloballyPaused) return;

    // Compte tab - pause all
    if (_activeTabIndex == 2) {
      if (_currentPlayingKey != null) {
        try {
          _keyToPlayer[_currentPlayingKey]?.player.pause();
        } catch (_) {}
        _currentPlayingKey = null;
        notifyListeners();
      }
      return;
    }

    String? bestKey;
    final double vHeight = _viewportHeight > 0 ? _viewportHeight : 800.0;
    // Smooth adaptive visual focus:
    // Starts at top row (0.32 * vHeight) and moves smoothly down to bottom row (0.75 * vHeight)
    final double targetCenterY = _isAtBottom
        ? (vHeight * 0.75)
        : (vHeight * (0.32 + (_scrollRatio * 0.43)));

    // 1. If currently on Home page (tab 0)
    if (_activeTabIndex == 0 && _sectionVisibility.isNotEmpty) {
      String? bestSectionId;
      double bestScore = -999999.0;

      for (final entry in _sectionVisibility.entries) {
        final secId = entry.key;
        final fraction = entry.value;

        // Calculate REAL-TIME centerY from live RenderBox
        double centerY = _sectionCenterY[secId] ?? 0.0;
        final ctx = _sectionContexts[secId];
        if (ctx != null && ctx.mounted) {
          try {
            final renderBox = ctx.findRenderObject() as RenderBox?;
            if (renderBox != null && renderBox.hasSize && renderBox.attached) {
              final globalOffset = renderBox.localToGlobal(Offset.zero);
              centerY = globalOffset.dy + (renderBox.size.height / 2);
              _sectionCenterY[secId] = centerY;
            }
          } catch (_) {}
        }

        if (fraction >= 0.15) {
          final double distFromCenter = (centerY - targetCenterY).abs();
          final score = (fraction * 1000.0) - (distFromCenter * 2.0);
          if (score > bestScore) {
            bestScore = score;
            bestSectionId = secId;
          }
        }
      }

      if (bestSectionId != null) {
        bestKey = _sectionActiveKey[bestSectionId];
      }
    }
    // 2. If currently on Boutique page (tab 1)
    else if (_activeTabIndex == 1) {
      double bestCardScore = -999999.0;

      for (final entry in _cardVisibility.entries) {
        final key = entry.key;
        // Strictly filter only Boutique cards when on Boutique tab
        if (!key.startsWith('boutique_')) continue;

        final fraction = entry.value;
        final url = _urlMap[key] ?? '';
        if (url.isEmpty) continue;

        // Calculate REAL-TIME centerY from live RenderBox
        double centerY = _cardCenterY[key] ?? 0.0;
        final ctx = _cardContexts[key];
        if (ctx != null && ctx.mounted) {
          try {
            final renderBox = ctx.findRenderObject() as RenderBox?;
            if (renderBox != null && renderBox.hasSize && renderBox.attached) {
              final globalOffset = renderBox.localToGlobal(Offset.zero);
              centerY = globalOffset.dy + (renderBox.size.height / 2);
              _cardCenterY[key] = centerY;
            }
          } catch (_) {}
        }

        if (fraction >= 0.15) {
          final double distFromCenter = (centerY - targetCenterY).abs();
          // Score rewards high visibility and closeness to the target Y
          final score = (fraction * 1000.0) - (distFromCenter * 2.0);
          if (score > bestCardScore) {
            bestCardScore = score;
            bestKey = key;
          }
        }
      }

      // Fallback for Boutique initial load
      if (bestKey == null && _urlMap.isNotEmpty) {
        for (final entry in _urlMap.entries) {
          if (entry.key.startsWith('boutique_') && entry.value.isNotEmpty) {
            bestKey = entry.key;
            break;
          }
        }
      }
    }

    if (bestKey != null) {
      final url = _urlMap[bestKey];
      if (url != null && url.isNotEmpty) {
        if (_currentPlayingKey != null && _currentPlayingKey != bestKey) {
          try {
            _keyToPlayer[_currentPlayingKey]?.player.pause();
          } catch (_) {}
        }
        _currentPlayingKey = bestKey;
        final playerState = _getOrCreatePlayer(bestKey, url, autoPlay: true);
        if (!playerState.isPlaying) {
          try {
            playerState.player.play();
          } catch (_) {}
        }

        // ── Pre-warm the next nearby video into an idle pool player ──────────
        // Find a URL that's registered but NOT currently playing
        String? nextUrl;
        for (final entry in _urlMap.entries) {
          if (entry.key != bestKey && entry.value.isNotEmpty) {
            // Only pre-warm if this URL isn't already loaded in any pool player
            final alreadyLoaded = _playerPool.any(
              (p) => p.currentUrl == entry.value,
            );
            if (!alreadyLoaded) {
              nextUrl = entry.value;
              break;
            }
          }
        }
        if (nextUrl != null && _playerPool.length < maxPoolSize) {
          // Silently open nextUrl in a new idle player so it's buffered
          final idleState = _getOrCreatePlayer(
            '__prewarm__${nextUrl.hashCode}',
            nextUrl,
            autoPlay: false,
          );
          // Immediately pause — we just want it buffered
          try {
            idleState.player.pause();
          } catch (_) {}
        }
      }
    } else if (_currentPlayingKey != null) {
      try {
        _keyToPlayer[_currentPlayingKey]?.player.pause();
      } catch (_) {}
      _currentPlayingKey = null;
    }

    notifyListeners();
  }

  FeedPlayerState? getPlayerState(String key) {
    return _keyToPlayer[key];
  }

  bool isKeyPlaying(String key) {
    return _currentPlayingKey == key && (_keyToPlayer[key]?.isPlaying ?? false);
  }

  /// Manually activate playback for a specific card on tap
  void playSingle(String key, String url) {
    if (url.trim().isEmpty) return;
    if (_currentPlayingKey != null && _currentPlayingKey != key) {
      try {
        _keyToPlayer[_currentPlayingKey]?.player.pause();
      } catch (_) {}
    }
    _currentPlayingKey = key;
    _urlMap[key] = url;
    final state = _getOrCreatePlayer(key, url, autoPlay: true);
    try {
      state.player.play();
    } catch (_) {}
    notifyListeners();
  }

  /// Called when a card is unmounted from the widget tree
  void unregisterCard(String key) {
    _urlMap.remove(key);
    _cardVisibility.remove(key);
    _cardCenterY.remove(key);

    if (_currentPlayingKey == key) {
      try {
        _keyToPlayer[key]?.player.pause();
      } catch (_) {}
      _currentPlayingKey = null;
    }

    final state = _keyToPlayer.remove(key);
    if (state != null) {
      state.stopAndReset();
    }

    _evaluatePlayback();
  }

  /// Unregister section
  void unregisterSection(String sectionId) {
    _sectionVisibility.remove(sectionId);
    _sectionCenterY.remove(sectionId);
    _sectionActiveKey.remove(sectionId);
    _evaluatePlayback();
  }

  /// Pause all active video players (e.g. route transitions, app in background)
  void pauseAll() {
    _isGloballyPaused = true;
    for (final p in _playerPool) {
      try {
        p.player.pause();
      } catch (_) {}
    }
    _currentPlayingKey = null;
    notifyListeners();
  }

  /// Resume playback when returning to the screen
  void resume() {
    if (_activeTabIndex == 2) {
      _isGloballyPaused = true;
      pauseAll();
      return;
    }
    _isGloballyPaused = false;
    _evaluatePlayback();
  }

  bool _isNotificationScheduled = false;

  @override
  void notifyListeners() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
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
    for (final p in _playerPool) {
      p.dispose();
    }
    _playerPool.clear();
    _keyToPlayer.clear();
    _urlMap.clear();
    _sectionActiveKey.clear();
    _sectionVisibility.clear();
    _sectionCenterY.clear();
    _cardVisibility.clear();
    _cardCenterY.clear();
    _currentPlayingKey = null;
    super.dispose();
  }
}
