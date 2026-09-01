import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:binetatour/core/story/story_player_engine.dart';
import 'package:binetatour/core/story/story_preloader.dart';
import 'package:binetatour/presentation/home/widget/story/story_models.dart';
import 'package:binetatour/providers/story_provider.dart';

/// Clean, robust single-engine controller for Story Video, Audio, and Image playback
class StoryDetailProvider extends ChangeNotifier {
  final List<StoryContent> stories;
  final StoryProvider? storyProvider;
  final int categoryIndex;
  final VoidCallback? onFinished;
  final VoidCallback? onPreviousAtStart;

  StoryPlayerEngine? _engine;
  final List<VoidCallback> _engineListeners = [];

  int _currentIndex = 0;
  bool _isMuted = false;
  bool _isPaused = false;
  bool _isDisposed = false;

  final bool isTestMode;

  StoryDetailProvider({
    required this.stories,
    this.storyProvider,
    this.categoryIndex = 0,
    int initialStoryIndex = 0,
    this.onFinished,
    this.onPreviousAtStart,
    this.isTestMode = false,
  }) {
    _currentIndex = initialStoryIndex.clamp(
      0,
      stories.isEmpty ? 0 : stories.length - 1,
    );
  }

  // --- Getters ---
  int get currentIndex => _currentIndex;
  StoryContent? get currentStory =>
      (stories.isNotEmpty && _currentIndex >= 0 && _currentIndex < stories.length)
          ? stories[_currentIndex]
          : null;

  bool get isMuted => _isMuted;
  bool get isPaused => _isPaused;
  bool get isPlaying => _engine?.isPlaying ?? false;
  bool get isBuffering => _engine?.isBuffering ?? false;
  bool get isLoading => !hasFirstFrame && isBuffering;
  bool get hasFirstFrame => _engine?.hasFirstFrame ?? false;
  double get progress => _engine?.progress ?? 0.0;
  double get currentMediaProgress => progress;
  double get imageProgress => progress;
  String? get error => _engine?.error;
  VideoController? get videoController => _engine?.videoController;
  Player? get player => _engine?.player;
  StoryPlayerEngine? get engine => _engine;

  // --- Playback Management ---

  void loadCurrentStory({bool play = true}) {
    _loadStory(_currentIndex, play: play);
  }

  Future<void> _loadStory(int index, {bool play = true}) async {
    if (_isDisposed || stories.isEmpty) return;
    if (index < 0 || index >= stories.length) return;

    _currentIndex = index;
    _isPaused = !play;
    notifyListeners();

    final story = stories[index];

    // 1. Eagerly preload all audio and next items in background
    StoryPreloader.preloadStories(stories);
    if (index + 1 < stories.length) {
      StoryPreloader.preloadNextStory(stories[index + 1]);
    }

    // 2. Track view asynchronously in background (401 handled silently)
    if (story.id != null && storyProvider != null && !isTestMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) {
          storyProvider!.viewStory(story.id!).catchError((_) {});
        }
      });
    }

    // 3. Use persistent session engine (avoids tearing down Android SurfaceTextures mid-category)
    if (!isTestMode) {
      if (_engine == null) {
        _engine = StoryPlayerEngine(
          onCompleted: nextStory,
          initialMuted: _isMuted,
        );
        _attachEngineListeners();
      }

      await _engine!.loadStory(story, autoPlay: play);
    } else {
      notifyListeners();
    }
  }

  void _attachEngineListeners() {
    if (_engine == null) return;
    final eng = _engine!;

    void updateUI() {
      if (_isDisposed) return;
      notifyListeners();
    }

    eng.progressNotifier.addListener(updateUI);
    _engineListeners.add(() => eng.progressNotifier.removeListener(updateUI));

    eng.isPlayingNotifier.addListener(updateUI);
    _engineListeners.add(() => eng.isPlayingNotifier.removeListener(updateUI));

    eng.isBufferingNotifier.addListener(updateUI);
    _engineListeners.add(() => eng.isBufferingNotifier.removeListener(updateUI));

    eng.hasFirstFrameNotifier.addListener(updateUI);
    _engineListeners.add(() => eng.hasFirstFrameNotifier.removeListener(updateUI));

    eng.errorNotifier.addListener(updateUI);
    _engineListeners.add(() => eng.errorNotifier.removeListener(updateUI));
  }

  void _cleanupEngine() {
    for (final remove in _engineListeners) {
      remove();
    }
    _engineListeners.clear();

    if (_engine != null) {
      _engine!.dispose();
      _engine = null;
    }
  }

  // --- Public Action APIs ---

  void nextStory() {
    if (_isDisposed) return;
    if (_currentIndex < stories.length - 1) {
      _loadStory(_currentIndex + 1, play: true);
    } else {
      _engine?.pause();
      if (onFinished != null) {
        onFinished!();
      }
    }
  }

  void previousStory() {
    if (_isDisposed) return;
    if (_currentIndex > 0) {
      _loadStory(_currentIndex - 1, play: true);
    } else {
      if (onPreviousAtStart != null) {
        onPreviousAtStart!();
      }
    }
  }

  void jumpToStory(int index, {bool play = true}) {
    if (_isDisposed || stories.isEmpty) return;
    final target = index.clamp(0, stories.length - 1);
    _loadStory(target, play: play);
  }

  void pauseStory() {
    if (_isDisposed) return;
    _isPaused = true;
    _engine?.pause();
    notifyListeners();
  }

  void resumeStory() {
    if (_isDisposed) return;
    _isPaused = false;
    _engine?.play();
    notifyListeners();
  }

  void togglePlayPause() {
    if (_isDisposed) return;
    if (_isPaused || !isPlaying) {
      resumeStory();
    } else {
      pauseStory();
    }
  }

  void toggleMute() {
    if (_isDisposed) return;
    _isMuted = !_isMuted;
    _engine?.setMuted(_isMuted);
    notifyListeners();
  }

  void retry() {
    if (_isDisposed) return;
    _loadStory(_currentIndex, play: true);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cleanupEngine();
    super.dispose();
  }
}
