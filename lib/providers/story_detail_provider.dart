import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:binetatour/core/video/story_player_pool.dart';
import 'package:binetatour/presentation/home/widget/story_details.dart';
import 'package:binetatour/providers/story_provider.dart';

class StoryDetailProvider extends ChangeNotifier {
  final List<StoryContent> stories;
  final StoryProvider storyProvider;
  final VoidCallback? onFinished;
  final VoidCallback? onPreviousAtStart;
  final bool initiallyActive;

  int _currentIndex = 0;
  bool _isMuted = false;
  Timer? _timer;
  double _imageProgress = 0.0;
  double _currentMediaProgress = 0.0;
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isDisposed = false;
  bool _hasFirstFrame = false;
  bool _shouldPlay = false;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _compSub;
  StreamSubscription? _bufSub;
  StreamSubscription? _playSub;
  StreamSubscription? _widthSub;
  StreamSubscription? _heightSub;
  StreamSubscription? _errSub;
  StreamSubscription? _preloadPosSub;

  Player? _player;
  VideoController? _videoController;

  Player? _nextPlayer;
  VideoController? _nextVideoController;
  String _nextPlayerUrl = '';

  StoryDetailProvider({
    required this.stories,
    required this.storyProvider,
    this.onFinished,
    this.onPreviousAtStart,
    this.initiallyActive = true,
  }) {
    _loadStory(_currentIndex, play: initiallyActive);
  }

  int get currentIndex => _currentIndex;
  bool get isMuted => _isMuted;
  double get imageProgress => _imageProgress;
  double get currentMediaProgress => _currentMediaProgress;
  bool get isLoading => _isLoading;
  bool get isPlaying => _isPlaying;
  bool get hasFirstFrame => _hasFirstFrame;

  Player? get player => _player;
  VideoController? get videoController => _videoController;
  VideoController? get nextVideoController => _nextVideoController;

  void _ensurePlayerInitialized() {
    if (_player != null) return;
    try {
      _player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 32 * 1024 * 1024, // 32 MB — smooth buffering
          logLevel: MPVLogLevel.warn,
        ),
      );

      try {
        final platform = _player!.platform;
        if (platform != null) {
          (platform as dynamic).setProperty('demuxer-readahead-secs', '15');
          (platform as dynamic).setProperty('cache', 'yes');
          (platform as dynamic).setProperty('cache-secs', '20');
          (platform as dynamic).setProperty('hls-bitrate', 'auto');
          (platform as dynamic).setProperty('demuxer-max-bytes', '32MiB');
          (platform as dynamic).setProperty('network-timeout', '10');
          (platform as dynamic).setProperty(
            'user-agent',
            'CloudflareStream-Flutter-MediaKit',
          );
        }
      } catch (_) {}

      _videoController = VideoController(
        _player!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );
      _player!.setVolume(_isMuted ? 0.0 : 100.0);
      _setupListeners(_player!);
    } catch (e) {
      debugPrint('Story player initialization error: $e');
    }
  }

  void _cancelListeners() {
    _posSub?.cancel();
    _durSub?.cancel();
    _compSub?.cancel();
    _bufSub?.cancel();
    _playSub?.cancel();
    _widthSub?.cancel();
    _heightSub?.cancel();
    _errSub?.cancel();
  }

  void _setupListeners(Player p) {
    _cancelListeners();
    _posSub = p.stream.position.listen((pos) {
      if (_isDisposed) return;
      if (pos > Duration.zero) {
        if (_isLoading) _isLoading = false;
        if (!_hasFirstFrame) {
          _hasFirstFrame = true;
          notifyListeners();
        }
      }
      final dur = p.state.duration;
      if (dur.inMilliseconds > 0) {
        _currentMediaProgress = (pos.inMilliseconds / dur.inMilliseconds).clamp(
          0.0,
          1.0,
        );
        notifyListeners();
        if (pos >= dur && dur > const Duration(seconds: 1)) {
          nextStory();
        }
      }
    });

    _durSub = p.stream.duration.listen((dur) {
      if (_isDisposed) return;
      final pos = p.state.position;
      if (dur.inMilliseconds > 0 && pos.inMilliseconds > 0) {
        _currentMediaProgress = (pos.inMilliseconds / dur.inMilliseconds).clamp(
          0.0,
          1.0,
        );
        notifyListeners();
      }
    });

    _compSub = p.stream.completed.listen((completed) {
      if (!_isDisposed && completed) {
        final pos = p.state.position;
        final dur = p.state.duration;
        if (dur > const Duration(milliseconds: 500) &&
            (pos.inMilliseconds >= dur.inMilliseconds - 600 || pos >= dur)) {
          nextStory();
        }
      }
    });

    _bufSub = p.stream.buffering.listen((buffering) {
      if (!_isDisposed) {
        if (_isLoading != buffering) {
          _isLoading = buffering;
          notifyListeners();
        }
      }
    });

    _playSub = p.stream.playing.listen((playing) {
      if (!_isDisposed) {
        _isPlaying = playing;
        if (playing && _isLoading) {
          _isLoading = false;
        }
        notifyListeners();
      }
    });

    _widthSub = p.stream.width.listen((_) {
      if (!_isDisposed) notifyListeners();
    });

    _heightSub = p.stream.height.listen((_) {
      if (!_isDisposed) notifyListeners();
    });

    _errSub = p.stream.error.listen((error) {
      if (_isDisposed) return;
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('audio device') || errorStr.contains('no sound')) {
        return;
      }
      debugPrint("⚠️ [StoryDetailProvider] Error: $error");
      final currentStory =
          (_currentIndex >= 0 && _currentIndex < stories.length)
          ? stories[_currentIndex]
          : null;
      if (currentStory != null && currentStory.url.isNotEmpty) {
        final source = p.state.playlist.medias.isNotEmpty
            ? p.state.playlist.medias.first.uri
            : '';
        if (source != currentStory.url) {
          try {
            p.open(Media(currentStory.url), play: true);
            return;
          } catch (_) {}
        }
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void _forcePlay() {
    if (_isDisposed || _player == null || !_shouldPlay) return;
    try {
      _player!.play();
    } catch (_) {}

    // Robust retry mechanism to defeat libmpv state machine race conditions
    // where a recent pause() command swallows our play() command.
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_isDisposed && _shouldPlay && _player != null) {
        if (!_player!.state.playing) {
          try {
            debugPrint(
              '⚡ [StoryDetailProvider] Forcing play retry due to race condition!',
            );
            _player!.play();
          } catch (_) {}
        }
      }
    });
  }

  void _loadStory(int index, {bool play = true}) {
    _cancelTimer();
    _imageProgress = 0.0;
    _currentMediaProgress = 0.0;
    _hasFirstFrame = false;

    if (_isDisposed ||
        stories.isEmpty ||
        index < 0 ||
        index >= stories.length) {
      return;
    }

    _currentIndex = index;
    final story = stories[index];

    if (story.id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) {
          try {
            storyProvider.viewStory(story.id!);
          } catch (_) {}
        }
      });
    }

    if (story.isVideo || story.isAudio) {
      // ── 0. Native Preload HIT (0ms transition inside same category) ──────
      if (_nextPlayer != null &&
          _nextVideoController != null &&
          _nextPlayerUrl == story.url) {
        debugPrint(
          '⚡⚡ [StoryDetailProvider] Native Preload HIT for story #$index',
        );

        final oldUrl = (_currentIndex > 0)
            ? stories[_currentIndex - 1].url
            : '';
        if (_player != null &&
            _videoController != null &&
            oldUrl.isNotEmpty &&
            oldUrl != story.url) {
          StoryPlayerPool.instance.donate(
            url: oldUrl,
            player: _player!,
            controller: _videoController!,
          );
        } else {
          try {
            _player?.dispose();
          } catch (_) {}
        }

        _player = _nextPlayer;
        _videoController = _nextVideoController;

        _nextPlayer = null;
        _nextVideoController = null;
        _nextPlayerUrl = '';

        _preloadPosSub?.cancel();
        _preloadPosSub = null;

        try {
          _player!.setVolume(_isMuted ? 0.0 : 100.0);
          _setupListeners(_player!);

          _shouldPlay = play;
          if (_shouldPlay) _forcePlay();
        } catch (e) {
          debugPrint('Preload player resume error: $e');
        }

        // The first frame was already rendered in the background by the auto-pause logic!
        _isLoading = false;
        _currentMediaProgress = 0.0;
        _hasFirstFrame = true;
        notifyListeners();

        _preloadNextStory(index + 1);
        return;
      }

      // ── 1. Check warm player pool first (0ms instant replay) ─────────────
      final StoryPoolEntry? poolEntry = StoryPlayerPool.instance.remove(
        story.url,
      );
      if (poolEntry != null) {
        final oldUrl = (_currentIndex >= 0 && _currentIndex < stories.length)
            ? stories[_currentIndex].url
            : '';
        if (_player != null &&
            _videoController != null &&
            oldUrl.isNotEmpty &&
            oldUrl != story.url) {
          StoryPlayerPool.instance.donate(
            url: oldUrl,
            player: _player!,
            controller: _videoController!,
          );
        } else {
          try {
            _player?.dispose();
          } catch (_) {}
        }

        _player = poolEntry.player;
        _videoController = poolEntry.controller;

        try {
          _player!.setVolume(_isMuted ? 0.0 : 100.0);
          _setupListeners(_player!);
          _player!.play();
        } catch (e) {
          debugPrint('Pool player resume error: $e');
        }

        _isLoading =
            true; // Let the player stream set this to false when first frame renders
        _currentMediaProgress = 0.0;
        _hasFirstFrame = false;
        notifyListeners();
        return;
      }

      // ── Normal load (first story or pool miss) ─────────────────
      _ensurePlayerInitialized();
      final activePlayer = _player;
      if (activePlayer == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      try {
        activePlayer.setVolume(_isMuted ? 0.0 : 100.0);
        final playPath = story.url;

        _isLoading = true;
        _currentMediaProgress = 0.0;
        _hasFirstFrame = false;
        _shouldPlay = play;
        notifyListeners();

        final playerToOpen = activePlayer;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            playerToOpen.open(Media(playPath), play: false);
            if (_shouldPlay) _forcePlay();
          } catch (_) {}
        });

        _preloadNextStory(index + 1);
      } catch (e) {
        debugPrint("Error loading media in StoryDetailProvider: $e");
        _isLoading = false;
      }
      notifyListeners();
    } else {
      _isLoading = false;
      try {
        _player?.pause();
      } catch (_) {}
      startImageTimer();
      notifyListeners();
    }
  }

  void _preloadNextStory(int nextIndex) {
    if (nextIndex >= stories.length) {
      _disposeNextPlayer();
      return;
    }
    final nextStory = stories[nextIndex];
    if (nextStory.isImage) {
      _disposeNextPlayer();
      return;
    }

    try {
      if (_nextPlayer == null) {
        _nextPlayer = Player(
          configuration: const PlayerConfiguration(
            bufferSize: 32 * 1024 * 1024,
            logLevel: MPVLogLevel.warn,
          ),
        );
        _nextVideoController = VideoController(
          _nextPlayer!,
          configuration: const VideoControllerConfiguration(
            enableHardwareAcceleration: true,
          ),
        );
      }
      _nextPlayerUrl = nextStory.url;
      _nextPlayer!.setVolume(0.0);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          // Force media_kit to fetch the HLS segment by playing it
          _nextPlayer!.open(Media(nextStory.url), play: true);

          // Immediately pause it once it actually renders a few frames
          _preloadPosSub?.cancel();
          _preloadPosSub = _nextPlayer!.stream.position.listen((pos) {
            if (pos.inMilliseconds > 50) {
              _nextPlayer?.pause();
              _preloadPosSub?.cancel();
              _preloadPosSub = null;
            }
          });
        } catch (_) {}
      });
    } catch (_) {}
  }

  void _disposeNextPlayer() {
    _preloadPosSub?.cancel();
    _preloadPosSub = null;
    try {
      _nextPlayer?.stop();
      _nextPlayer?.dispose();
    } catch (_) {}
    _nextPlayer = null;
    _nextVideoController = null;
    _nextPlayerUrl = '';
  }

  void startOrResumeStory() {
    if (_isDisposed) return;
    resumeStory();
  }

  void startImageTimer() {
    _cancelTimer();
    const duration = Duration(seconds: 5);
    final initialTicks = (_imageProgress * duration.inMilliseconds / 50)
        .round();
    int currentTicks = initialTicks;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (_isDisposed) {
        t.cancel();
        return;
      }
      currentTicks++;
      _imageProgress = (currentTicks * 50) / duration.inMilliseconds;
      if (_imageProgress >= 1.0) {
        _cancelTimer();
        nextStory();
      } else {
        notifyListeners();
      }
    });
  }

  void _cancelTimer() => _timer?.cancel();

  void nextStory() {
    if (_isDisposed) return;
    if (_currentIndex < stories.length - 1) {
      _loadStory(_currentIndex + 1);
    } else {
      _cancelTimer();
      try {
        _player?.pause();
      } catch (_) {}
      if (onFinished != null) {
        onFinished!();
      }
    }
  }

  void previousStory() {
    if (_isDisposed) return;
    if (_currentIndex > 0) {
      _loadStory(_currentIndex - 1);
    } else {
      if (onPreviousAtStart != null) {
        onPreviousAtStart!();
      }
    }
  }

  void toggleMute() {
    if (_isDisposed) return;
    _isMuted = !_isMuted;
    try {
      _player?.setVolume(_isMuted ? 0.0 : 100.0);
    } catch (_) {}
    notifyListeners();
  }

  void togglePlayPause() {
    if (_isDisposed) return;
    final p = _player;
    if (p == null) return;
    try {
      if (_isPlaying) {
        p.pause();
      } else {
        p.play();
      }
    } catch (_) {}
  }

  void pauseStory() {
    _shouldPlay = false;
    if (_isDisposed || stories.isEmpty) return;
    if (_currentIndex < 0 || _currentIndex >= stories.length) return;
    final story = stories[_currentIndex];
    if (story.isImage) {
      _cancelTimer();
    } else {
      try {
        _player?.pause();
      } catch (_) {}
    }
  }

  void resumeStory() {
    _shouldPlay = true;
    if (_isDisposed || stories.isEmpty) return;
    if (_currentIndex < 0 || _currentIndex >= stories.length) return;
    final story = stories[_currentIndex];
    if (story.isImage) {
      startImageTimer();
    } else {
      try {
        _player?.play();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelTimer();

    // Donate the active player to pool so it can be instantly reused
    final activePlayer = _player;
    final activeCtrl = _videoController;
    final activeUrl = (_currentIndex >= 0 && _currentIndex < stories.length)
        ? stories[_currentIndex].url
        : '';
    if (activePlayer != null && activeCtrl != null && activeUrl.isNotEmpty) {
      final story = stories[_currentIndex];
      if (story.isVideo || story.isAudio) {
        StoryPlayerPool.instance.donate(
          url: activeUrl,
          player: activePlayer,
          controller: activeCtrl,
        );
      } else {
        try {
          activePlayer.stop();
          activePlayer.dispose();
        } catch (_) {}
      }
    } else {
      try {
        activePlayer?.stop();
        activePlayer?.dispose();
      } catch (_) {}
    }

    _disposeNextPlayer();
    _cancelListeners();
    super.dispose();
  }
}
