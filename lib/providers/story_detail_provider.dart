import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';
import 'package:binetatour/presentation/home/widget/story_details.dart';
import 'package:binetatour/providers/story_provider.dart';

class StoryDetailProvider extends ChangeNotifier {
  final List<StoryContent> stories;
  final StoryProvider storyProvider;
  final VoidCallback? onFinished;
  final VoidCallback? onPreviousAtStart;
  final bool autoStart;

  int _currentIndex = 0;
  bool _isMuted = false;
  Timer? _timer;
  double _imageProgress = 0.0;
  double _currentMediaProgress = 0.0;
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _isDisposed = false;
  bool _hasStarted = false;

  Player? _playerA;
  VideoController? _controllerA;
  Player? _playerB;
  VideoController? _controllerB;

  StoryDetailProvider({
    required this.stories,
    required this.storyProvider,
    this.onFinished,
    this.onPreviousAtStart,
    this.autoStart = true,
  }) {
    if (autoStart) {
      _hasStarted = true;
      _loadStory(_currentIndex);
    }
  }

  int get currentIndex => _currentIndex;
  bool get isMuted => _isMuted;
  double get imageProgress => _imageProgress;
  double get currentMediaProgress => _currentMediaProgress;
  bool get isLoading => _isLoading;
  bool get isPlaying => _isPlaying;

  Player? get player => (_currentIndex % 2 == 0) ? _playerA : _playerB;
  VideoController? get videoController =>
      (_currentIndex % 2 == 0) ? _controllerA : _controllerB;

  Player? get _nextPlayer =>
      ((_currentIndex + 1) % 2 == 0) ? _playerA : _playerB;

  void _ensurePlayersInitialized() {
    if (_playerA != null) return;
    try {
      _playerA = Player();
      _controllerA = VideoController(
        _playerA!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );
      _playerA!.setVolume(_isMuted ? 0.0 : 100.0);
      _setupListeners(_playerA!, 0);

      _playerB = Player();
      _controllerB = VideoController(
        _playerB!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );
      _playerB!.setVolume(_isMuted ? 0.0 : 100.0);
      _setupListeners(_playerB!, 1);
    } catch (e) {
      debugPrint('Story player initialization error: $e');
    }
  }

  void _setupListeners(Player p, int pIdx) {
    p.stream.position.listen((pos) {
      if (_isDisposed) return;
      if ((_currentIndex % 2) == pIdx) {
        if (pos > Duration.zero && _isLoading) {
          _isLoading = false;
        }
        final dur = p.state.duration;
        if (dur.inMilliseconds > 0) {
          _currentMediaProgress = (pos.inMilliseconds / dur.inMilliseconds)
              .clamp(0.0, 1.0);
          notifyListeners();
          if (pos >= dur && dur > const Duration(seconds: 1)) {
            nextStory();
          }
        }
      }
    });

    p.stream.duration.listen((dur) {
      if (_isDisposed) return;
      if ((_currentIndex % 2) == pIdx) {
        final pos = p.state.position;
        if (dur.inMilliseconds > 0 && pos.inMilliseconds > 0) {
          _currentMediaProgress = (pos.inMilliseconds / dur.inMilliseconds)
              .clamp(0.0, 1.0);
          notifyListeners();
        }
      }
    });

    p.stream.completed.listen((completed) {
      if (!_isDisposed && completed && (_currentIndex % 2) == pIdx) {
        final pos = p.state.position;
        final dur = p.state.duration;
        // Strictly verify that media has actually loaded and played to near the end
        if (dur > const Duration(milliseconds: 500) &&
            (pos.inMilliseconds >= dur.inMilliseconds - 600 || pos >= dur)) {
          nextStory();
        }
      }
    });

    p.stream.buffering.listen((buffering) {
      if (!_isDisposed && (_currentIndex % 2) == pIdx) {
        if (!_isLoading) {
          _isLoading = buffering;
          notifyListeners();
        }
      }
    });

    p.stream.playing.listen((playing) {
      if (!_isDisposed && (_currentIndex % 2) == pIdx) {
        _isPlaying = playing;
        if (playing && _isLoading) {
          _isLoading = false;
        }
        notifyListeners();
      }
    });

    p.stream.width.listen((_) {
      if (!_isDisposed) notifyListeners();
    });

    p.stream.height.listen((_) {
      if (!_isDisposed) notifyListeners();
    });

    p.stream.error.listen((error) {
      if (_isDisposed) return;
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('audio device') || errorStr.contains('no sound')) {
        return;
      }
      debugPrint("⚠️ [StoryDetailProvider] Error on p$pIdx: $error");
      if ((_currentIndex % 2) == pIdx) {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void _loadStory(int index) {
    _cancelTimer();
    _imageProgress = 0.0;
    _currentMediaProgress = 0.0;

    if (_isDisposed || stories.isEmpty || index < 0 || index >= stories.length) {
      return;
    }

    final oldIndex = _currentIndex;
    _currentIndex = index;
    final story = stories[index];

    _ensurePlayersInitialized();

    // Pause previous player if switching index
    final prevPlayer = (oldIndex % 2 == 0) ? _playerA : _playerB;
    if (prevPlayer != null && oldIndex != index) {
      try {
        prevPlayer.pause();
      } catch (_) {}
    }

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
      final activePlayer = player;
      if (activePlayer == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      try {
        activePlayer.setVolume(_isMuted ? 0.0 : 100.0);

        final cleanUrl = story.url;
        final cachedPath = VideoCacheManager.instance.getCachedFilePath(
          cleanUrl,
        );
        final playPath = cachedPath ?? cleanUrl;


        // Format URI properly with file:// scheme for local files
        final String mediaUri;
        if (cachedPath != null && cachedPath.isNotEmpty) {
          mediaUri = cachedPath.startsWith('file://')
              ? cachedPath
              : 'file://$cachedPath';
        } else if (playPath.startsWith('/')) {
          mediaUri = playPath.startsWith('file://')
              ? playPath
              : 'file://$playPath';
        } else {
          mediaUri = playPath;
        }

        // Check if active player was already pre-buffered with this URL!
        final currentSource = activePlayer.state.playlist.medias.isNotEmpty
            ? activePlayer.state.playlist.medias.first.uri
            : '';

        final bool isAlreadyPrebuffered =
            currentSource == playPath ||
            currentSource == cleanUrl ||
            currentSource == mediaUri ||
            currentSource == 'file://$playPath' ||
            currentSource == 'file://$cleanUrl';

        if (isAlreadyPrebuffered) {
          _isLoading = activePlayer.state.position == Duration.zero;
          activePlayer.play();
        } else {
          _isLoading = true;
          activePlayer.open(Media(mediaUri), play: true);
          if (story.isNetwork && cachedPath == null) {
            VideoCacheManager.instance.preCacheVideo(cleanUrl);
          }
        }
      } catch (e) {
        debugPrint("Error loading media in StoryDetailProvider: $e");
        _isLoading = false;
      }
      notifyListeners();

      // Pre-buffer next story in background on the secondary player!
      _preloadNextStory(index + 1);
    } else {
      _isLoading = false;
      startImageTimer();
      notifyListeners();

      // Pre-buffer next story in background even if current is an image!
      _preloadNextStory(index + 1);
    }
  }

  void _preloadNextStory(int nextIndex) {
    if (_isDisposed || nextIndex < 0 || nextIndex >= stories.length) return;
    final nextStory = stories[nextIndex];
    if (!nextStory.isVideo && !nextStory.isAudio) return;
    if (nextStory.url.isEmpty) return;

    final nextP = _nextPlayer;
    if (nextP == null) return;

    try {
      final cleanNext = nextStory.url;
      final cachedPath = VideoCacheManager.instance.getCachedFilePath(
        cleanNext,
      );
      final playPath = cachedPath ?? cleanNext;

      final String mediaUri;
      if (cachedPath != null && cachedPath.isNotEmpty) {
        mediaUri = cachedPath.startsWith('file://')
            ? cachedPath
            : 'file://$cachedPath';
      } else if (playPath.startsWith('/')) {
        mediaUri = playPath.startsWith('file://')
            ? playPath
            : 'file://$playPath';
      } else {
        mediaUri = playPath;
      }

      final currentSource = nextP.state.playlist.medias.isNotEmpty
          ? nextP.state.playlist.medias.first.uri
          : '';

      final bool isAlreadyPreloaded =
          currentSource == playPath ||
          currentSource == cleanNext ||
          currentSource == mediaUri ||
          currentSource == 'file://$playPath' ||
          currentSource == 'file://$cleanNext';

      if (!isAlreadyPreloaded) {
        nextP.setVolume(_isMuted ? 0.0 : 100.0);
        nextP.open(Media(mediaUri), play: false);
        if (nextStory.isNetwork && cachedPath == null) {
          VideoCacheManager.instance.preCacheVideo(cleanNext);
        }
      }

    } catch (e) {
      debugPrint("Error preloading next story: $e");
    }
  }

  void startOrResumeStory() {
    if (_isDisposed) return;
    if (!_hasStarted) {
      _hasStarted = true;
      _loadStory(_currentIndex);
    } else {
      resumeStory();
    }
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
        _playerA?.pause();
        _playerB?.pause();
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
      _playerA?.setVolume(_isMuted ? 0.0 : 100.0);
      _playerB?.setVolume(_isMuted ? 0.0 : 100.0);
    } catch (_) {}
    notifyListeners();
  }

  void togglePlayPause() {
    if (_isDisposed) return;
    final p = player;
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
    if (_isDisposed || stories.isEmpty) return;
    if (_currentIndex < 0 || _currentIndex >= stories.length) return;
    final story = stories[_currentIndex];
    if (story.isImage) {
      _cancelTimer();
    } else {
      try {
        player?.pause();
      } catch (_) {}
    }
  }

  void resumeStory() {
    if (_isDisposed || stories.isEmpty) return;
    if (_currentIndex < 0 || _currentIndex >= stories.length) return;
    final story = stories[_currentIndex];
    if (story.isImage) {
      startImageTimer();
    } else {
      try {
        player?.play();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelTimer();
    try {
      _playerA?.dispose();
      _playerB?.dispose();
    } catch (_) {}
    super.dispose();
  }
}
