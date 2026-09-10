import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:binetatour/core/story/story_player_engine.dart';
import 'package:binetatour/core/story/story_preloader.dart';
import 'package:binetatour/presentation/home/widget/story/story_models.dart';
import 'package:binetatour/providers/story_provider.dart';

/// Production-grade Dual-Engine (Ping-Pong) Pool controller for Story Video, Audio, and Image playback.
/// Eliminates codec initialization latency by pre-rolling the next story to Frame 0 on an idle engine
/// while the active story is playing. Transition between stories occurs in 0ms!
class StoryDetailProvider extends ChangeNotifier {
  final List<StoryContent> stories;
  final StoryProvider? storyProvider;
  final int categoryIndex;
  final List<StoryGroup>? allGroups;
  final VoidCallback? onFinished;
  final VoidCallback? onPreviousAtStart;

  StoryPlayerEngine? _engineA;
  StoryPlayerEngine? _engineB;
  bool _useEngineA = true;
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
    this.allGroups,
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

  // --- Engine Getters ---
  StoryPlayerEngine? get _activeEngine => _useEngineA ? _engineA : _engineB;
  StoryPlayerEngine? get _backgroundEngine => _useEngineA ? _engineB : _engineA;

  bool get isEngineAActive => _useEngineA;
  VideoController? get videoControllerA => _engineA?.videoController;
  VideoController? get videoControllerB => _engineB?.videoController;
  VideoController? get videoController => _activeEngine?.videoController;
  Player? get player => _activeEngine?.player;
  StoryPlayerEngine? get engine => _activeEngine;

  // --- State Getters ---
  int get currentIndex => _currentIndex;
  StoryContent? get currentStory =>
      (stories.isNotEmpty &&
          _currentIndex >= 0 &&
          _currentIndex < stories.length)
      ? stories[_currentIndex]
      : null;

  bool get isMuted => _isMuted;
  bool get isPaused => _isPaused;
  bool get isPlaying =>
      !_isPaused && (_activeEngine?.isPlaying ?? false) && !isBuffering;
  bool get isBuffering => _activeEngine?.isBuffering ?? false;
  bool get isLoading => !hasFirstFrame && isBuffering;
  bool get hasFirstFrame => _activeEngine?.hasFirstFrame ?? false;
  double get progress => _activeEngine?.progress ?? 0.0;
  double get currentMediaProgress => progress;
  double get imageProgress => progress;
  String? get error => _activeEngine?.error;

  // --- Lifecycle & Initialization ---

  void _initEngines() {
    if (isTestMode) return;
    if (_engineA != null && _engineB != null) return;
    _cleanupEngines();

    _engineA = StoryPlayerEngine(
      onCompleted: () {
        if (!_isDisposed && _useEngineA) {
          nextStory();
        }
      },
      initialMuted: _isMuted,
    );
    _attachEngineListeners(_engineA!, true);

    _engineB = StoryPlayerEngine(
      onCompleted: () {
        if (!_isDisposed && !_useEngineA) {
          nextStory();
        }
      },
      initialMuted: _isMuted,
    );
    _attachEngineListeners(_engineB!, false);
  }

  void _attachEngineListeners(StoryPlayerEngine eng, bool isEngineA) {
    void updateUI() {
      if (_isDisposed) return;
      if ((isEngineA && _useEngineA) || (!isEngineA && !_useEngineA)) {
        notifyListeners();
      }
    }

    eng.progressNotifier.addListener(updateUI);
    _engineListeners.add(() => eng.progressNotifier.removeListener(updateUI));

    eng.isPlayingNotifier.addListener(updateUI);
    _engineListeners.add(() => eng.isPlayingNotifier.removeListener(updateUI));

    eng.isBufferingNotifier.addListener(updateUI);
    _engineListeners.add(
      () => eng.isBufferingNotifier.removeListener(updateUI),
    );

    eng.hasFirstFrameNotifier.addListener(updateUI);
    _engineListeners.add(
      () => eng.hasFirstFrameNotifier.removeListener(updateUI),
    );

    eng.errorNotifier.addListener(updateUI);
    _engineListeners.add(() => eng.errorNotifier.removeListener(updateUI));
  }

  void _cleanupEngines() {
    for (final remove in _engineListeners) {
      remove();
    }
    _engineListeners.clear();

    _engineA?.dispose();
    _engineA = null;

    _engineB?.dispose();
    _engineB = null;
  }

  // --- Playback Management ---

  void loadCurrentStory({bool play = true}) {
    _loadStory(_currentIndex, play: play);
  }

  Future<void> _loadStory(int index, {bool play = true}) async {
    if (_isDisposed || stories.isEmpty) return;
    if (index < 0 || index >= stories.length) return;

    _initEngines();

    _currentIndex = index;
    _isPaused = !play;
    notifyListeners();

    final story = stories[index];

    // 1. Deep intelligent preloading of video files and posters into local disk
    StoryPreloader.preloadAround(
      stories: stories,
      currentIndex: index,
      allGroups: allGroups,
      categoryIndex: categoryIndex,
    );

    // 2. Track view asynchronously in background
    if (story.id != null && storyProvider != null && !isTestMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) {
          storyProvider!.viewStory(story.id!).catchError((_) {});
        }
      });
    }

    // 3. Load active story on active engine
    if (!isTestMode) {
      await _activeEngine?.loadStory(story, autoPlay: play);

      // Pre-roll the NEXT story onto the background engine to Frame 0
      _prewarmNextStory(index);
    } else {
      notifyListeners();
    }
  }

  void _prewarmNextStory(int currentIndex) {
    if (_isDisposed || isTestMode) return;
    if (currentIndex + 1 < stories.length) {
      final nextStory = stories[currentIndex + 1];
      // Only pre-warm video stories on the background hardware texture.
      // Audio and image stories do not use a video texture surface and
      // should be loaded fresh with autoPlay: true when active.
      if (nextStory.isVideo) {
        _backgroundEngine?.setMuted(true);
        _backgroundEngine?.loadStory(nextStory, autoPlay: false);
      }
    } else if (allGroups != null && categoryIndex + 1 < allGroups!.length) {
      final nextCat = allGroups![categoryIndex + 1];
      if (nextCat.stories.isNotEmpty && nextCat.stories.first.isVideo) {
        _backgroundEngine?.setMuted(true);
        _backgroundEngine?.loadStory(nextCat.stories.first, autoPlay: false);
      }
    }
  }

  // --- Public Action APIs ---

  void nextStory() {
    if (_isDisposed) return;
    if (_currentIndex < stories.length - 1) {
      // 1. Pause current engine and mute to release audio session
      if (!isTestMode) {
        _activeEngine?.pause();
        _activeEngine?.setMuted(true);
      }

      // 2. Flip active engine pointer (Engine A <-> Engine B)
      _useEngineA = !_useEngineA;
      _currentIndex++;
      _isPaused = false;

      final incomingStory = stories[_currentIndex];

      // 3. Restore configured mute state and start or load the incoming story
      if (!isTestMode) {
        _activeEngine?.setMuted(_isMuted);
        if (incomingStory.isVideo &&
            _activeEngine?.currentStory?.id == incomingStory.id &&
            _activeEngine?.hasFirstFrame == true) {
          _activeEngine?.play();
        } else {
          _activeEngine?.loadStory(incomingStory, autoPlay: true);
        }
      }
      notifyListeners();

      // 4. Pre-roll the next upcoming story onto the idle background engine
      _prewarmNextStory(_currentIndex);

      // 5. Trigger disk cache pre-warm for upcoming queue
      StoryPreloader.preloadAround(
        stories: stories,
        currentIndex: _currentIndex,
        allGroups: allGroups,
        categoryIndex: categoryIndex,
      );

      // 6. Track view
      if (currentStory?.id != null && storyProvider != null && !isTestMode) {
        storyProvider!.viewStory(currentStory!.id!).catchError((_) {});
      }
    } else {
      if (!isTestMode) {
        _activeEngine?.pause();
        _activeEngine?.setMuted(true);
      }
      if (onFinished != null) {
        onFinished!();
      }
    }
  }

  void previousStory() {
    if (_isDisposed) return;
    if (_currentIndex > 0) {
      if (!isTestMode) {
        _activeEngine?.pause();
        _activeEngine?.setMuted(true);
      }
      _useEngineA = !_useEngineA;
      _currentIndex--;
      _isPaused = false;

      if (!isTestMode) {
        _activeEngine?.setMuted(_isMuted);
        _activeEngine?.loadStory(stories[_currentIndex], autoPlay: true);
        _prewarmNextStory(_currentIndex);
      }

      StoryPreloader.preloadAround(
        stories: stories,
        currentIndex: _currentIndex,
        allGroups: allGroups,
        categoryIndex: categoryIndex,
      );
      notifyListeners();
    } else {
      if (onPreviousAtStart != null) {
        onPreviousAtStart!();
      }
    }
  }

  void jumpToStory(int index, {bool play = true}) {
    if (_isDisposed || stories.isEmpty) return;
    if (!isTestMode) {
      _activeEngine?.pause();
      _activeEngine?.setMuted(true);
    }
    final target = index.clamp(0, stories.length - 1);
    _loadStory(target, play: play);
  }

  void pauseStory() {
    if (_isDisposed) return;
    _isPaused = true;
    if (!isTestMode) {
      _activeEngine?.pause();
    }
    notifyListeners();
  }

  void resumeStory() {
    if (_isDisposed) return;
    _isPaused = false;
    if (!isTestMode) {
      _activeEngine?.play();
    }
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
    _engineA?.setMuted(_isMuted);
    _engineB?.setMuted(_isMuted);
    notifyListeners();
  }

  void retry() {
    if (_isDisposed) return;
    _loadStory(_currentIndex, play: true);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cleanupEngines();
    super.dispose();
  }
}
