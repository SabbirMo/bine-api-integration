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
      debugPrint("⚠️ [FeedVideoManager] Player error for $currentKey: $error");
      isBuffering = false;
      onUpdate();
    });
  }

  void stopAndReset() {
    try {
      player.pause();
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
        bufferSize: 10 * 1024 * 1024,
        logLevel: MPVLogLevel.warn,
      ),
    );

    final controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

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

  FeedPlayerState _getOrCreatePlayer(
    String key,
    String url, {
    bool autoPlay = false,
  }) {
    final cachedPath = VideoCacheManager.instance.getCachedFilePath(url);
    final targetUrl = cachedPath ?? url;

    if (_keyToPlayer.containsKey(key)) {
      final state = _keyToPlayer[key]!;
      if (state.currentUrl != url) {
        state.currentUrl = url;
        state.hasFirstFrame = false;
        state.isBuffering = true;
        try {
          state.player.open(Media(targetUrl), play: autoPlay);
        } catch (_) {}
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
    if (state.currentKey != null && state.currentKey != key) {
      _keyToPlayer.remove(state.currentKey);
    }

    state.currentKey = key;
    _keyToPlayer[key] = state;

    if (state.currentUrl != url) {
      state.currentUrl = url;
      state.hasFirstFrame = false;
      state.isBuffering = true;
      try {
        state.player.open(Media(targetUrl), play: autoPlay);
      } catch (_) {}
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

  void _evaluatePlayback() {
    String? bestKey;

    // 1. If sections are active (Home page)
    if (_sectionVisibility.isNotEmpty) {
      String? bestSectionId;
      double bestScore = -99999.0;

      for (final entry in _sectionVisibility.entries) {
        final secId = entry.key;
        final fraction = entry.value;
        final centerY = _sectionCenterY[secId] ?? 0.0;

        if (fraction >= 0.25) {
          final score = (fraction * 1000.0) + (centerY * 0.1);
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
    // 2. Else if grid cards are active (Boutique page)
    else if (_cardVisibility.isNotEmpty) {
      double bestCardScore = -99999.0;

      for (final entry in _cardVisibility.entries) {
        final key = entry.key;
        final fraction = entry.value;
        final centerY = _cardCenterY[key] ?? 0.0;
        final url = _urlMap[key] ?? '';

        if (url.isNotEmpty && fraction >= 0.25) {
          final score = (fraction * 1000.0) + (centerY * 0.1);
          if (score > bestCardScore) {
            bestCardScore = score;
            bestKey = key;
          }
        }
      }
    }

    if (bestKey != null) {
      final url = _urlMap[bestKey];
      if (url != null && url.isNotEmpty) {
        if (bestKey != _currentPlayingKey) {
          if (_currentPlayingKey != null &&
              _keyToPlayer.containsKey(_currentPlayingKey)) {
            try {
              _keyToPlayer[_currentPlayingKey]!.player.pause();
            } catch (_) {}
          }
          _currentPlayingKey = bestKey;
          final playerState = _getOrCreatePlayer(bestKey, url, autoPlay: true);
          try {
            playerState.player.play();
          } catch (_) {}
        } else {
          final playerState = _keyToPlayer[bestKey];
          if (playerState != null && !playerState.isPlaying) {
            try {
              playerState.player.play();
            } catch (_) {}
          }
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
