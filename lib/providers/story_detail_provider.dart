import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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

  Player? _player;
  VideoController? _videoController;
  StreamSubscription? _positionSub;

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
  Player? get player => _player;
  VideoController? get videoController => _videoController;

  void _loadStory(int index) {
    _cancelTimer();
    _positionSub?.cancel();
    _player?.dispose();
    _player = null;
    _videoController = null;
    _imageProgress = 0.0;
    _currentMediaProgress = 0.0;
    _isLoading = true;
    _isPlaying = false;
    notifyListeners();

    if (index < 0 || index >= stories.length) return;
    final story = stories[index];

    // Mark story as viewed
    if (story.id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) {
          storyProvider.viewStory(story.id!);
        }
      });
    }

    if (story.isVideo || story.isAudio) {
      _initializeMedia(story);
    } else {
      _isLoading = false;
      startImageTimer();
      notifyListeners();
    }
  }

  void _initializeMedia(StoryContent story) {
    if (story.url.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _player = Player();
      _videoController = VideoController(
        _player!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: false,
        ),
      );

      _player!.setVolume(_isMuted ? 0.0 : 100.0);

      _positionSub = _player!.stream.position.listen((pos) {
        if (_isDisposed) return;
        final dur = _player!.state.duration;
        if (dur.inMilliseconds > 0) {
          _currentMediaProgress = pos.inMilliseconds / dur.inMilliseconds;
          notifyListeners();
        }
      });

      _player!.stream.completed.listen((completed) {
        if (!_isDisposed && completed) {
          nextStory();
        }
      });

      _player!.stream.buffering.listen((buffering) {
        if (!_isDisposed) {
          _isLoading = buffering;
          notifyListeners();
        }
      });

      _player!.stream.playing.listen((playing) {
        if (!_isDisposed) {
          _isPlaying = playing;
          if (playing) _isLoading = false;
          notifyListeners();
        }
      });

      if (story.isAudio && story.isNetwork) {
        _downloadAndPlayAudio(story.url);
      } else if (story.isNetwork) {
        _player!.open(Media(story.url));
      } else {
        _player!.open(Media('asset://${story.url}'));
      }
    } catch (e) {
      debugPrint('Story player initialization error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _downloadAndPlayAudio(String url) async {
    try {
      final dio = Dio();
      final tempDir = Directory.systemTemp;
      final fileName = 'story_audio_${url.hashCode}.mp3';
      final savePath = '${tempDir.path}/$fileName';
      final file = File(savePath);

      if (!await file.exists()) {
        await dio.download(url, savePath);
      }

      if (_isDisposed) return;
      await _player?.open(Media('file://$savePath'));
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Story audio download error: $e');
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
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
      _currentIndex++;
      _loadStory(_currentIndex);
    } else {
      _cancelTimer();
      _player?.pause();
      if (onFinished != null) {
        onFinished!();
      }
    }
  }

  void previousStory() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _loadStory(_currentIndex);
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _player?.setVolume(_isMuted ? 0.0 : 100.0);
    notifyListeners();
  }

  void togglePlayPause() {
    if (_player == null) return;
    if (_isPlaying) {
      _player!.pause();
    } else {
      _player!.play();
    }
  }

  void pauseStory() {
    final story = stories[_currentIndex];
    if (story.isImage) {
      _cancelTimer();
    } else {
      _player?.pause();
    }
  }

  void resumeStory() {
    final story = stories[_currentIndex];
    if (story.isImage) {
      startImageTimer();
    } else {
      _player?.play();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelTimer();
    _positionSub?.cancel();
    _player?.dispose();
    super.dispose();
  }
}
