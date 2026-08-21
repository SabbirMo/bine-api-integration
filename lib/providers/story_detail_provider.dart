import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';
import 'package:binetatour/core/video/video_frame_manager.dart';
import 'package:binetatour/presentation/home/widget/story_details.dart';
import 'package:binetatour/providers/story_provider.dart';

class StoryDetailProvider extends ChangeNotifier {
  final List<StoryContent> stories;
  final StoryProvider storyProvider;
  final VoidCallback? onFinished;

  int _currentIndex = 0;
  bool _isMuted = false;
  Timer? _timer;
  double _imageProgress = 0.0;
  double _currentMediaProgress = 0.0;
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _isDisposed = false;

  Player? _playerA;
  VideoController? _controllerA;
  Player? _playerB;
  VideoController? _controllerB;

  StoryDetailProvider({
    required this.stories,
    required this.storyProvider,
    this.onFinished,
  }) {
    _loadStory(_currentIndex);
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
          _currentMediaProgress = pos.inMilliseconds / dur.inMilliseconds;
          notifyListeners();
        }
      }
    });

    p.stream.completed.listen((completed) {
      if (!_isDisposed && completed && (_currentIndex % 2) == pIdx) {
        nextStory();
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
        notifyListeners();
      }
    });
  }

  void _loadStory(int index) {
    _cancelTimer();
    _imageProgress = 0.0;
    _currentMediaProgress = 0.0;

    if (index < 0 || index >= stories.length) return;

    final oldIndex = _currentIndex;
    _currentIndex = index;
    final story = stories[index];

    _ensurePlayersInitialized();

    // Pause previous player if switching index
    final prevPlayer = (oldIndex % 2 == 0) ? _playerA : _playerB;
    if (prevPlayer != null && oldIndex != index) {
      prevPlayer.pause();
    }

    if (story.id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) {
          storyProvider.viewStory(story.id!);
        }
      });
    }

    if (story.isVideo || story.isAudio) {
      final activePlayer = player!;
      activePlayer.setVolume(_isMuted ? 0.0 : 100.0);

      final cleanUrl = story.url;
      final cachedPath = VideoCacheManager.instance.getCachedFilePath(cleanUrl);
      final playPath = cachedPath ?? cleanUrl;

      // Extract first frame
      VideoFrameManager.instance.extractFirstFrame(cleanUrl);

      // Check if active player was already pre-buffered with this URL!
      final currentSource = activePlayer.state.playlist.medias.isNotEmpty
          ? activePlayer.state.playlist.medias.first.uri
          : '';

      final bool isAlreadyPrebuffered = currentSource == playPath ||
          currentSource == cleanUrl ||
          currentSource == 'file://$playPath' ||
          currentSource == 'file://$cleanUrl';

      if (isAlreadyPrebuffered) {
        _isLoading = activePlayer.state.position == Duration.zero;
        activePlayer.play();
      } else {
        _isLoading = true;
        if (story.isNetwork && cachedPath == null) {
          activePlayer.open(Media(cleanUrl), play: true);
          VideoCacheManager.instance.preCacheVideo(cleanUrl);
        } else {
          final mediaUri = (cachedPath != null || playPath.startsWith('/'))
              ? playPath
              : (playPath.startsWith('http')
                  ? playPath
                  : 'asset://$playPath');
          activePlayer.open(Media(mediaUri), play: true);
        }
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
    if (nextIndex < 0 || nextIndex >= stories.length) return;
    final nextStory = stories[nextIndex];
    if (!nextStory.isVideo && !nextStory.isAudio) return;
    if (nextStory.url.isEmpty) return;

    final nextP = _nextPlayer;
    if (nextP == null) return;

    final cleanNext = nextStory.url;
    final cachedPath = VideoCacheManager.instance.getCachedFilePath(cleanNext);
    final playPath = cachedPath ?? cleanNext;

    final currentSource = nextP.state.playlist.medias.isNotEmpty
        ? nextP.state.playlist.medias.first.uri
        : '';

    final bool isAlreadyPreloaded = currentSource == playPath ||
        currentSource == cleanNext ||
        currentSource == 'file://$playPath' ||
        currentSource == 'file://$cleanNext';

    if (!isAlreadyPreloaded) {
      debugPrint(
        "Pre-buffering next story index $nextIndex in background: $cleanNext",
      );
      nextP.setVolume(_isMuted ? 0.0 : 100.0);
      if (nextStory.isNetwork && cachedPath == null) {
        nextP.open(Media(cleanNext), play: false);
        VideoCacheManager.instance.preCacheVideo(cleanNext);
      } else {
        final mediaUri = (cachedPath != null || playPath.startsWith('/'))
            ? playPath
            : (playPath.startsWith('http')
                ? playPath
                : 'asset://$playPath');
        nextP.open(Media(mediaUri), play: false);
      }
    }

    // Pre-extract first frame
    VideoFrameManager.instance.extractFirstFrame(cleanNext);
  }

  void startImageTimer() {
    _cancelTimer();
    const duration = Duration(seconds: 5);
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (_isDisposed) {
        t.cancel();
        return;
      }
      _imageProgress = (t.tick * 50) / duration.inMilliseconds;
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
    if (_currentIndex < stories.length - 1) {
      _loadStory(_currentIndex + 1);
    } else {
      _cancelTimer();
      _playerA?.pause();
      _playerB?.pause();
      if (onFinished != null) {
        onFinished!();
      }
    }
  }

  void previousStory() {
    if (_currentIndex > 0) {
      _loadStory(_currentIndex - 1);
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _playerA?.setVolume(_isMuted ? 0.0 : 100.0);
    _playerB?.setVolume(_isMuted ? 0.0 : 100.0);
    notifyListeners();
  }

  void togglePlayPause() {
    final p = player;
    if (p == null) return;
    if (_isPlaying) {
      p.pause();
    } else {
      p.play();
    }
  }

  void pauseStory() {
    final story = stories[_currentIndex];
    if (story.isImage) {
      _cancelTimer();
    } else {
      player?.pause();
    }
  }

  void resumeStory() {
    final story = stories[_currentIndex];
    if (story.isImage) {
      startImageTimer();
    } else {
      player?.play();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelTimer();
    _playerA?.dispose();
    _playerB?.dispose();
    super.dispose();
  }
}
