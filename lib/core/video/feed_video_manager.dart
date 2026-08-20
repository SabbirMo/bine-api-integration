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

/// YouTube-style central video feed manager with 2-tier architecture:
/// 1. Section-level vertical viewport tracking
/// 2. Row-level horizontal active card indexing (Card 1 <-> 2 <-> 3)
class FeedVideoManager extends ChangeNotifier {
  static final FeedVideoManager _instance = FeedVideoManager._internal();
  static FeedVideoManager get instance => _instance;

  FeedVideoManager._internal();

  /// 3 pooled native players for minimal memory footprint and zero lag
  static const int maxPoolSize = 3;

  final Map<String, String> _urlMap = {};

  // Section ID -> Active Card Key & Section Viewport info
  final Map<String, String> _sectionActiveKey = {};
  final Map<String, double> _sectionVisibility = {};
  final Map<String, double> _sectionCenterY = {};

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
      p.player.setVolume(_isFeedMuted ? 0.0 : 100.0);
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

    player.setPlaylistMode(PlaylistMode.loop);
    player.setVolume(_isFeedMuted ? 0.0 : 100.0);

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
        state.player.open(Media(targetUrl), play: autoPlay);
      } else if (autoPlay && !state.isPlaying) {
        state.player.play();
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
          state.player.pause();
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
      state.player.open(Media(targetUrl), play: autoPlay);
    } else if (autoPlay && !state.isPlaying) {
      state.player.play();
    }

    return state;
  }

  /// Register card's video URL
  void registerCardUrl(String key, String url) {
    if (url.trim().isEmpty) return;
    _urlMap[key] = url;
    VideoCacheManager.instance.preCacheVideo(url);
  }

  /// Update vertical visibility for a section
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

  /// Set the active horizontal card for a section (from horizontal swipe or initial index)
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

  void _evaluatePlayback() {
    if (_sectionVisibility.isEmpty) {
      if (_currentPlayingKey != null) {
        _keyToPlayer[_currentPlayingKey]?.player.pause();
        _currentPlayingKey = null;
        notifyListeners();
      }
      return;
    }

    // Find the most visible section on screen
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
      final bestKey = _sectionActiveKey[bestSectionId];
      final url = bestKey != null ? _urlMap[bestKey] : null;

      if (bestKey != null && url != null && url.isNotEmpty) {
        if (bestKey != _currentPlayingKey) {
          // Pause previously playing player
          if (_currentPlayingKey != null &&
              _keyToPlayer.containsKey(_currentPlayingKey)) {
            _keyToPlayer[_currentPlayingKey]!.player.pause();
          }

          _currentPlayingKey = bestKey;
          final playerState = _getOrCreatePlayer(bestKey, url, autoPlay: true);
          playerState.player.play();
        } else {
          // Ensure current active player is playing
          final playerState = _keyToPlayer[bestKey];
          if (playerState != null && !playerState.isPlaying) {
            playerState.player.play();
          }
        }
      }
    } else if (_currentPlayingKey != null) {
      _keyToPlayer[_currentPlayingKey]?.player.pause();
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
      _keyToPlayer[_currentPlayingKey]?.player.pause();
    }
    _currentPlayingKey = key;
    _urlMap[key] = url;
    final state = _getOrCreatePlayer(key, url, autoPlay: true);
    state.player.play();
    notifyListeners();
  }

  /// Called when a card is unmounted from the widget tree
  void unregisterCard(String key) {
    _urlMap.remove(key);

    if (_currentPlayingKey == key) {
      _keyToPlayer[key]?.player.pause();
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
      p.player.pause();
    }
    _currentPlayingKey = null;
    notifyListeners();
  }

  /// Resume playback when returning to the home screen
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
    _currentPlayingKey = null;
    super.dispose();
  }
}
