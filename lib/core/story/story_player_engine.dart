import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:binetatour/core/story/story_hls_preloader.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';
import 'package:binetatour/presentation/home/widget/story/story_models.dart';

/// Single unified session player engine for Story playback.
/// Keeps a persistent Player and VideoController across all stories in a category session
/// so Android OpenGL SurfaceTextures are never destroyed and recreated mid-swipe.
class StoryPlayerEngine {
  final VoidCallback onCompleted;

  late final Player _player;
  late final VideoController _videoController;

  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isBufferingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _metadataReadyNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _codecReadyNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _hasFirstFrameNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _errorNotifier = ValueNotifier<String?>(null);

  final List<StreamSubscription> _subscriptions = [];
  Timer? _imageTimer;
  Timer? _bufferingWatchdogTimer;
  int _imageElapsedMs = 0;
  static const Duration _defaultImageDuration = Duration(seconds: 5);
  static const int _imageTickMs = 50;

  StoryContent? _currentStory;
  bool _isDisposed = false;
  bool _isMuted = false;
  bool _hasCompleted = false;
  int _currentGenerationId = 0;
  int _activeCompletedGenerationId = -1;
  int _retryCount = 0;
  static const int _maxRetries = 2;
  DateTime? _transitionStartTime;
  DateTime? _openStartTime;

  ValueListenable<double> get progressNotifier => _progressNotifier;
  ValueListenable<bool> get isPlayingNotifier => _isPlayingNotifier;
  ValueListenable<bool> get isBufferingNotifier => _isBufferingNotifier;
  ValueListenable<bool> get metadataReadyNotifier => _metadataReadyNotifier;
  ValueListenable<bool> get codecReadyNotifier => _codecReadyNotifier;
  ValueListenable<bool> get hasFirstFrameNotifier => _hasFirstFrameNotifier;
  ValueListenable<String?> get errorNotifier => _errorNotifier;

  double get progress => _progressNotifier.value;
  bool get isPlaying => _isPlayingNotifier.value;
  bool get isBuffering => _isBufferingNotifier.value;
  bool get isMetadataReady => _metadataReadyNotifier.value;
  bool get isCodecReady => _codecReadyNotifier.value;
  bool get hasFirstFrame => _hasFirstFrameNotifier.value;
  String? get error => _errorNotifier.value;
  VideoController get videoController => _videoController;
  Player get player => _player;

  StoryPlayerEngine({required this.onCompleted, bool initialMuted = false})
    : _isMuted = initialMuted {
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize:
            (1.5 * 1024 * 1024) ~/
            1, // 1.5MB tuned for instant first-frame start
        logLevel: MPVLogLevel.warn,
      ),
    );

    _videoController = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _setupPlayerListeners();
    _applyFastMpvProperties(); // Apply once during player initialization!
  }

  bool _hasMediaStartedForCurrentGen = false;

  void _recordFirstFrameTelemetry(String trigger) {
    if (_transitionStartTime != null) {
      final elapsedMs = DateTime.now()
          .difference(_transitionStartTime!)
          .inMilliseconds;
      final isCold = AppStartupTracker.isFirstStoryPlay;
      AppStartupTracker.isFirstStoryPlay = false;
      final totalAppTime = DateTime.now()
          .difference(AppStartupTracker.appStartTime)
          .inMilliseconds;
      debugPrint(
        '⏱️ [StoryPlayerEngine] ${isCold ? "COLD-START" : "WARM"} story transition took ${elapsedMs}ms to first frame visible ($trigger) [App uptime: ${totalAppTime}ms]',
      );
      _transitionStartTime = null;
    }
  }

  void _startBufferingWatchdog(int genId) {
    _bufferingWatchdogTimer?.cancel();
    // Grace period: if video doesn't have first frame within 450ms, show buffering indicator
    _bufferingWatchdogTimer = Timer(const Duration(milliseconds: 450), () {
      if (_isDisposed || genId != _currentGenerationId) return;
      if (!_hasFirstFrameNotifier.value) {
        _isBufferingNotifier.value = true;
      }
    });
  }

  void _cancelBufferingWatchdog() {
    _bufferingWatchdogTimer?.cancel();
    _bufferingWatchdogTimer = null;
  }

  void _setupPlayerListeners() {
    void checkFirstFrameReady() {
      if (_isDisposed || _hasFirstFrameNotifier.value) return;
      final isAudio = _currentStory?.isAudio == true;
      final isVideo = _currentStory?.isVideo == true;
      final pos = _player.state.position;

      if (isAudio && pos > Duration.zero) {
        _hasFirstFrameNotifier.value = true;
        _isBufferingNotifier.value = false;
        _cancelBufferingWatchdog();
      } else if (isVideo && pos > Duration.zero) {
        _hasFirstFrameNotifier.value = true;
        _isBufferingNotifier.value = false;
        _cancelBufferingWatchdog();
        if (_openStartTime != null) {
          final ms = DateTime.now().difference(_openStartTime!).inMilliseconds;
          debugPrint(
            '🎬 [StoryPerf] FIRST FRAME VISIBLE #${_currentStory?.id ?? 0} = ${ms}ms',
          );
        }
      }
    }

    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        if (_isDisposed || _currentStory?.isImage == true) return;
        _isPlayingNotifier.value = playing;
        if (playing) {
          _errorNotifier.value = null;
          checkFirstFrameReady();
        }
      }),
    );

    _subscriptions.add(
      _player.stream.duration.listen((dur) {
        if (_isDisposed || _currentStory?.isImage == true) return;
        if (dur > Duration.zero && !_metadataReadyNotifier.value) {
          _metadataReadyNotifier.value = true;
          if (_openStartTime != null) {
            final ms = DateTime.now()
                .difference(_openStartTime!)
                .inMilliseconds;
            debugPrint(
              '📋 [StoryPerf] metadata ready (+${ms}ms, duration: ${dur.inSeconds}s)',
            );
          }
        }
      }),
    );

    _subscriptions.add(
      _player.stream.width.listen((w) {
        if (_isDisposed || _currentStory?.isImage == true) return;
        if (w != null && w > 0) {
          if (!_codecReadyNotifier.value) {
            _codecReadyNotifier.value = true;
            if (_openStartTime != null) {
              final ms = DateTime.now()
                  .difference(_openStartTime!)
                  .inMilliseconds;
              debugPrint(
                '🖥️ [StoryPerf] codec ready (+${ms}ms, resolution: ${w}x${_player.state.height})',
              );
            }
          }
          checkFirstFrameReady();
        }
      }),
    );

    _subscriptions.add(
      _player.stream.buffering.listen((buffering) {
        if (_isDisposed || _currentStory?.isImage == true) return;
        _isBufferingNotifier.value = buffering;
        if (buffering) {
          if (!_hasFirstFrameNotifier.value &&
              _bufferingWatchdogTimer == null) {
            _startBufferingWatchdog(_currentGenerationId);
          }
        } else {
          _cancelBufferingWatchdog();
          if (_errorNotifier.value != null &&
              _errorNotifier.value!.toLowerCase().contains('slow')) {
            _errorNotifier.value = null;
          }
          checkFirstFrameReady();
        }
      }),
    );

    void triggerCompletion(String reason) {
      if (_isDisposed || _currentStory?.isImage == true) return;
      final int currentGen = _currentGenerationId;
      if (!_hasCompleted && _activeCompletedGenerationId != currentGen) {
        _cancelBufferingWatchdog();
        _hasCompleted = true;
        _activeCompletedGenerationId = currentGen;
        _progressNotifier.value = 1.0;
        onCompleted();
      }
    }

    _subscriptions.add(
      _player.stream.position.listen((pos) {
        if (_isDisposed || _currentStory?.isImage == true) return;
        if (pos > Duration.zero) {
          _hasMediaStartedForCurrentGen = true;
          _cancelBufferingWatchdog();
          if (_errorNotifier.value != null) {
            _errorNotifier.value = null; // Auto-hide slow connection overlay
          }
          checkFirstFrameReady();
        }

        final dur = _player.state.duration;
        if (dur > Duration.zero &&
            _hasMediaStartedForCurrentGen &&
            _hasFirstFrameNotifier.value) {
          final frac = (pos.inMilliseconds / dur.inMilliseconds).clamp(
            0.0,
            1.0,
          );
          _progressNotifier.value = frac;

          // Fail-safe: if position reaches within 200ms of end of video, auto-advance
          if (dur.inMilliseconds > 1000 &&
              pos.inMilliseconds >= dur.inMilliseconds - 200) {
            triggerCompletion('position reached end');
          }
        }
      }),
    );

    _subscriptions.add(
      _player.stream.completed.listen((completed) {
        if (completed && _hasMediaStartedForCurrentGen) {
          triggerCompletion('completed stream event');
        }
      }),
    );

    _subscriptions.add(
      _player.stream.error.listen((err) async {
        if (_isDisposed || _currentStory?.isImage == true) return;
        final lower = err.toString().toLowerCase();
        if (lower.contains('audio device') || lower.contains('no sound')) {
          return;
        }

        final int genId = _currentGenerationId;
        // Automatic retry logic: retry up to 2 times with a 1.5s delay
        if (_retryCount < _maxRetries && _currentStory != null) {
          _retryCount++;
          debugPrint(
            '🔄 [StoryPlayerEngine] Auto-retry opening media (attempt $_retryCount/$_maxRetries) in 1.5s: $err',
          );
          if (lower.contains('could not open codec') ||
              lower.contains('mediacodec')) {
            debugPrint(
              '⚠️ [StoryPerf] MediaCodec error: falling back to safe software decoding (hwdec: no)',
            );
            try {
              final platform = _player.platform;
              if (platform != null) {
                await (platform as dynamic).setProperty('hwdec', 'no');
              }
            } catch (_) {}
          }
          await Future.delayed(const Duration(milliseconds: 1500));
          if (_isDisposed || genId != _currentGenerationId) return;

          try {
            final effectiveUrl = resolvePlaybackUrl(_currentStory!);
            await _player.open(
              Media(effectiveUrl),
              play: _isPlayingNotifier.value,
            );
            return;
          } catch (e) {
            debugPrint('⚠️ [StoryPlayerEngine] Auto-retry open failed: $e');
          }
        }

        if (!_isDisposed && genId == _currentGenerationId) {
          _cancelBufferingWatchdog();
          _errorNotifier.value = 'Playback error: $err';
          _isBufferingNotifier.value = false;
        }
      }),
    );
  }

  Future<void> _applyFastMpvProperties() async {
    try {
      final platform = _player.platform;
      if (platform != null) {
        final p = platform as dynamic;
        await Future.wait(<Future<dynamic>>[
          p.setProperty('hwdec', 'auto-safe'),
          p.setProperty('hls-bitrate', 'auto'),
          p.setProperty('cache', 'yes'),
          p.setProperty('cache-secs', '10'),
          p.setProperty('demuxer-lavf-analyzeduration', '0'),
          p.setProperty('demuxer-lavf-probesize', '1048576'),
          p.setProperty('cache-pause', 'no'),
          p.setProperty('cache-pause-wait', '0'),
          p.setProperty('cache-pause-initial', 'no'),
          p.setProperty('demuxer-readahead-secs', '5'),
          p.setProperty('demuxer-max-bytes', '25MiB'),
          p.setProperty('demuxer-max-back-bytes', '25MiB'),
          p.setProperty('loop-file', 'no'),
          p.setProperty('vd-lavc-fast', 'yes'),
          p.setProperty('vd-lavc-skiploopfilter', 'all'),
          p.setProperty('audio-stream-silence', 'yes'),
          p.setProperty('audio-buffer', '0.05'),
          p.setProperty('network-timeout', '10'),
          p.setProperty('user-agent', 'CloudflareStream-Flutter-MediaKit'),
        ]);
      }
    } catch (_) {}
  }

  /// Resolves the optimal playback URL based on hybrid smart caching (same as Product Details):
  /// 1. If local MP4 is cached on disk ➔ plays in 0ms from local storage!
  /// 2. If remote MP4 is available ➔ plays direct MP4 stream & caches for next time.
  /// 3. Fallback ➔ Adaptive HLS Stream (.m3u8) with hls-bitrate=auto.
  String resolvePlaybackUrl(StoryContent story) {
    if (story.isVideo) {
      final candidates = <String>[
        if (story.fallbackUrl != null && story.fallbackUrl!.isNotEmpty)
          story.fallbackUrl!,
        if (story.url.isNotEmpty) story.url,
      ];

      for (final cand in candidates) {
        final cachedPath = VideoCacheManager.instance.getCachedFilePath(cand);
        if (cachedPath != null) {
          debugPrint(
            '💾 [StoryPlayerEngine] Playing from local disk cache: $cachedPath',
          );
          return cachedPath;
        }
        final downloadUrl = VideoCacheManager.getDownloadableUrl(cand);
        final cachedDownload = VideoCacheManager.instance.getCachedFilePath(
          downloadUrl,
        );
        if (cachedDownload != null) {
          debugPrint(
            '💾 [StoryPlayerEngine] Playing direct MP4 from local disk cache: $cachedDownload',
          );
          return cachedDownload;
        }
      }

      if (story.fallbackUrl != null &&
          story.fallbackUrl!.isNotEmpty &&
          story.fallbackUrl!.startsWith('http')) {
        VideoCacheManager.instance.preCacheVideo(story.fallbackUrl!);
        return story.fallbackUrl!;
      }

      // Fallback: Adaptive HLS Stream (.m3u8)
      if (story.url.isNotEmpty && story.url.startsWith('http')) {
        return story.url;
      }
      return story.fallbackUrl ?? story.url;
    } else if (story.isAudio) {
      final target =
          (story.fallbackUrl != null &&
              story.fallbackUrl!.isNotEmpty &&
              story.fallbackUrl!.startsWith('http'))
          ? story.fallbackUrl!
          : story.url;
      final cachedPath = VideoCacheManager.instance.getCachedFilePath(target);
      return cachedPath ?? target;
    }
    return story.url;
  }

  /// Loads a new story into the persistent engine without tearing down the SurfaceTexture
  Future<void> loadStory(StoryContent story, {required bool autoPlay}) async {
    if (_isDisposed) return;
    final int loadId = ++_currentGenerationId;
    _openStartTime = DateTime.now();
    _transitionStartTime = _openStartTime;
    _currentStory = story;
    _hasCompleted = false;
    _hasMediaStartedForCurrentGen = false;
    _retryCount = 0;
    _imageTimer?.cancel();
    _imageTimer = null;
    _cancelBufferingWatchdog();
    _imageElapsedMs = 0;
    _progressNotifier.value = 0.0;
    _errorNotifier.value = null;
    _metadataReadyNotifier.value = story.isImage;
    _codecReadyNotifier.value = story.isImage;

    debugPrint('🚀 [StoryPerf] Story #${story.id ?? 0} requested');
    debugPrint('📡 [StoryPerf] HLS open');

    if (story.isImage) {
      try {
        await _player.stop();
      } catch (_) {}
      if (loadId != _currentGenerationId) return;
      _hasFirstFrameNotifier.value = true;
      _recordFirstFrameTelemetry('image frame');
      _isBufferingNotifier.value = false;
      _isPlayingNotifier.value = autoPlay;
      if (autoPlay) {
        _startImageTimer(loadId);
      }
    } else {
      _hasFirstFrameNotifier.value =
          story.isAudio; // Audio doesn't need video texture frame
      _isBufferingNotifier.value = false;
      _isPlayingNotifier.value = autoPlay;

      if (autoPlay) {
        _startBufferingWatchdog(loadId);
        // Immediately cancel background prefetch to dedicate 100% bandwidth to foreground playback
        StoryHlsPreloader.instance.cancel();
      }

      await _player.setVolume(autoPlay ? (_isMuted ? 0.0 : 100.0) : 0.0);

      final effectiveUrl = resolvePlaybackUrl(story);

      // Note: First frame readiness is strictly verified across stream position,
      // video dimensions, and buffering state by checkFirstFrameReady() so loading
      // completes smoothly before revealing video playback.

      try {
        debugPrint('▶️ [StoryPerf] play() autoPlay=$autoPlay');
        await _player.open(Media(effectiveUrl), play: autoPlay);
      } catch (e) {
        if (!_isDisposed && loadId == _currentGenerationId) {
          _cancelBufferingWatchdog();
          _errorNotifier.value = 'Failed to open media: $e';
          _isBufferingNotifier.value = false;
        }
      }
    }
  }

  void _startImageTimer(int genId) {
    _imageTimer?.cancel();
    _isPlayingNotifier.value = true;

    _imageTimer = Timer.periodic(const Duration(milliseconds: _imageTickMs), (
      t,
    ) {
      if (_isDisposed || genId != _currentGenerationId) {
        t.cancel();
        return;
      }
      _imageElapsedMs += _imageTickMs;
      final frac = (_imageElapsedMs / _defaultImageDuration.inMilliseconds)
          .clamp(0.0, 1.0);
      _progressNotifier.value = frac;

      if (_imageElapsedMs >= _defaultImageDuration.inMilliseconds) {
        t.cancel();
        if (!_hasCompleted && _activeCompletedGenerationId != genId) {
          _hasCompleted = true;
          _activeCompletedGenerationId = genId;
          _progressNotifier.value = 1.0;
          onCompleted();
        }
      }
    });
  }

  Future<void> play() async {
    if (_isDisposed) return;
    if (_currentStory?.isImage == true) {
      _startImageTimer(_currentGenerationId);
    } else {
      try {
        await _player.setVolume(_isMuted ? 0.0 : 100.0);
        await _player.play();
      } catch (_) {}
    }
    _isPlayingNotifier.value = true;
  }

  Future<void> pause() async {
    if (_isDisposed) return;
    if (_currentStory?.isImage == true) {
      _imageTimer?.cancel();
      _imageTimer = null;
    } else {
      try {
        await _player.pause();
      } catch (_) {}
    }
    _isPlayingNotifier.value = false;
  }

  Future<void> setMuted(bool muted) async {
    if (_isDisposed) return;
    _isMuted = muted;
    try {
      await _player.setVolume(muted ? 0.0 : 100.0);
    } catch (_) {}
  }

  void dispose() {
    _isDisposed = true;
    _imageTimer?.cancel();
    _imageTimer = null;
    _cancelBufferingWatchdog();
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    try {
      _player.stop();
      _player.dispose();
    } catch (_) {}
    _progressNotifier.dispose();
    _isPlayingNotifier.dispose();
    _isBufferingNotifier.dispose();
    _hasFirstFrameNotifier.dispose();
    _errorNotifier.dispose();
  }
}
