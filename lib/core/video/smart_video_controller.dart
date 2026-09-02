import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';

/// Available video quality options for Cloudflare Stream HLS playback.
enum VideoQuality {
  auto(label: 'Auto', maxRes: null),
  p240(label: '240p', maxRes: '240p'),
  p360(label: '360p', maxRes: '360p'),
  p480(label: '480p', maxRes: '480p'),
  p720(label: '720p', maxRes: '720p'),
  p1080(label: '1080p', maxRes: '1080p');

  final String label;
  final String? maxRes;

  const VideoQuality({required this.label, required this.maxRes});
}

/// Explicit lifecycle states for [SmartVideoController].
enum SmartVideoState {
  uninitialized,
  preloading,
  ready,
  playing,
  paused,
  failed,
  disposed,
}

/// Advanced configuration options for [SmartVideoController].
class SmartVideoConfig {
  /// Target cache duration in seconds (default: 45s).
  final int cacheSecs;

  /// Demuxer readahead buffer in seconds (default: 30s).
  final int demuxerReadaheadSecs;

  /// Maximum demuxer cache size in bytes (default: 50 MB).
  final int demuxerMaxBytes;

  /// Maximum demuxer backwards buffer in bytes for instant rewinds (default: 20 MB).
  final int demuxerMaxBackBytes;

  /// Network read timeout in seconds before triggering reconnection (default: 15s).
  final int networkTimeoutSecs;

  /// Maximum number of automatic retries on network/playback failure (default: 5).
  final int maxRetries;

  /// Base delay duration between retries (default: 2 seconds).
  final Duration retryDelay;

  /// Whether to auto-play when initialized (default: true).
  final bool autoPlay;

  /// Whether video should loop indefinitely (default: false).
  final bool loop;

  /// Initial audio volume (0.0 to 100.0, default: 100.0).
  final double initialVolume;

  /// Whether the video is muted initially (default: false).
  final bool initialMuted;

  /// Whether to use hardware accelerated video decoding (MediaCodec).
  ///
  /// Set to `false` for short-form clips / stories to avoid exhausting
  /// Android's concurrent hardware codec session limits (OMX_ErrorInsufficientResources).
  final bool enableHardwareAcceleration;

  const SmartVideoConfig({
    this.cacheSecs = 45,
    this.demuxerReadaheadSecs = 30,
    this.demuxerMaxBytes = 50 * 1024 * 1024,
    this.demuxerMaxBackBytes = 20 * 1024 * 1024,
    this.networkTimeoutSecs = 15,
    this.maxRetries = 5,
    this.retryDelay = const Duration(seconds: 2),
    this.autoPlay = true,
    this.loop = false,
    this.initialVolume = 100.0,
    this.initialMuted = false,
    this.enableHardwareAcceleration = true,
  });

  /// Story-optimized lightweight configuration profile for short-form clips (3-15s).
  ///
  /// Features minimal cache and readahead limits for instant startup,
  /// with software decoding (`enableHardwareAcceleration: false`) to completely
  /// prevent Android "Could not open codec" resource exhaustion.
  const SmartVideoConfig.story({
    this.cacheSecs = 5,
    this.demuxerReadaheadSecs = 1,
    this.demuxerMaxBytes = 6 * 1024 * 1024,
    this.demuxerMaxBackBytes = 2 * 1024 * 1024,
    this.networkTimeoutSecs = 8,
    this.maxRetries = 2,
    this.retryDelay = const Duration(seconds: 1),
    this.autoPlay = false,
    this.loop = false,
    this.initialVolume = 0.0,
    this.initialMuted = true,
    this.enableHardwareAcceleration = false,
  });
}

/// A high-performance, network-adaptive video controller leveraging `media_kit` (libmpv).
///
/// Features:
/// - Client-side Adaptive Bitrate (ABR) for Cloudflare Stream HLS master manifests.
/// - Tuned libmpv caching and readahead buffers for smooth playback on 2G/3G/4G/WiFi.
/// - Automatic resilience & retry with playback position preservation.
/// - In-memory frame capture via `player.screenshot()` for smooth video placeholder/buffering UX.
/// - Real-time resolution / pixel logging to console.
/// - Reactive ValueNotifier states for clean UI rendering.
/// - Safe lifecycle and memory management.
class SmartVideoController {
  final String originalUrl;
  final SmartVideoConfig config;

  late final Player _player;
  late final VideoController _videoController;

  // Stream Subscriptions
  final List<StreamSubscription> _subscriptions = [];
  Timer? _retryTimer;

  // Internal State
  bool _isDisposed = false;
  Duration _lastPlaybackPosition = Duration.zero;
  bool _wasPlayingBeforeError = false;
  int _currentRetryAttempt = 0;

  // Reactive State Notifiers
  final ValueNotifier<SmartVideoState> lifecycleState =
      ValueNotifier<SmartVideoState>(SmartVideoState.uninitialized);
  final ValueNotifier<bool> isInitializing = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isBuffering = ValueNotifier<bool>(true);
  final ValueNotifier<bool> hasStartedPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isCompleted = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration> duration = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration> buffer = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<double> volume = ValueNotifier<double>(100.0);
  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);
  final ValueNotifier<double> playbackRate = ValueNotifier<double>(1.0);
  final ValueNotifier<VideoQuality> selectedQuality =
      ValueNotifier<VideoQuality>(VideoQuality.auto);
  final ValueNotifier<int?> videoWidth = ValueNotifier<int?>(null);
  final ValueNotifier<int?> videoHeight = ValueNotifier<int?>(null);
  final ValueNotifier<String> currentResolution = ValueNotifier<String>(
    'Detecting...',
  );
  final ValueNotifier<Uint8List?> capturedFrame = ValueNotifier<Uint8List?>(
    null,
  );
  final ValueNotifier<bool> isRetrying = ValueNotifier<bool>(false);
  final ValueNotifier<int> retryAttempt = ValueNotifier<int>(0);
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);
  final ValueNotifier<bool> isRewinding = ValueNotifier<bool>(false);
  DateTime? _lastSeekTime;
  Timer? _perfMonitorTimer;
  int _lastDroppedFrames = 0;
  Future<void>? _openStreamFuture;

  bool _hasCodecError = false;
  String? _codecErrorMessage;

  int? _lastLoggedWidth;
  int? _lastLoggedHeight;
  final bool _isTestMode;

  // Getters
  Player get player => _player;
  VideoController get videoController => _videoController;
  bool get isDisposed => _isDisposed;
  bool get hasCodecError => _hasCodecError;
  String? get codecErrorMessage => _codecErrorMessage;
  bool get isMetadataReady =>
      duration.value > Duration.zero &&
      videoWidth.value != null &&
      videoHeight.value != null &&
      videoWidth.value! > 0 &&
      videoHeight.value! > 0;
  bool get isCodecReady =>
      !_hasCodecError && videoWidth.value != null && videoWidth.value! > 0;
  bool get isFrameReady => capturedFrame.value != null;
  bool get isBufferReady => buffer.value > Duration.zero;
  bool get isPlaybackReady => isMetadataReady && isCodecReady && !_isDisposed;

  SmartVideoController({
    required this.originalUrl,
    this.config = const SmartVideoConfig(),
  }) : _isTestMode = false {
    _initPlayer();
  }

  /// Constructor for testing or mocking in headless environments
  @visibleForTesting
  SmartVideoController.test({
    required this.originalUrl,
    this.config = const SmartVideoConfig(),
  }) : _isTestMode = true {
    _wasPlayingBeforeError = config.autoPlay;
    volume.value = config.initialVolume;
    isMuted.value = config.initialMuted;
    lifecycleState.value = config.autoPlay
        ? SmartVideoState.playing
        : SmartVideoState.ready;
  }

  /// Initializes Player, VideoController, native mpv properties, and stream listeners.
  void _initPlayer() {
    lifecycleState.value = config.autoPlay
        ? SmartVideoState.uninitialized
        : SmartVideoState.preloading;

    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: config.demuxerMaxBytes,
        logLevel: MPVLogLevel.warn,
      ),
    );

    _videoController = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _wasPlayingBeforeError = config.autoPlay;
    volume.value = config.initialVolume;
    isMuted.value = config.initialMuted;

    _player.setPlaylistMode(
      config.loop ? PlaylistMode.loop : PlaylistMode.none,
    );
    _player.setVolume(config.initialMuted ? 0.0 : config.initialVolume);

    _setupListeners();
    _openStreamFuture = _openStream(
      targetUrl: _resolveUrlForQuality(selectedQuality.value),
      startPosition: Duration.zero,
    );
  }

  /// Sets underlying MPV / libmpv platform properties for adaptive bitrate & smooth streaming.
  Future<void> _applyNativeMpvProperties() async {
    if (_isDisposed || _isTestMode) return;

    // 1. Hardware Decoding mode (no = software decoding, 0 MediaCodec slots claimed)
    final hwdecMode = config.enableHardwareAcceleration ? 'auto-safe' : 'no';
    await _setMpvProperty('hwdec', hwdecMode);
    debugPrint(
      '⚙️ [SmartVideoController #${identityHashCode(this)}] Configured hwdec=$hwdecMode (enableHardwareAcceleration: ${config.enableHardwareAcceleration})',
    );

    // 2. Configure HLS Bitrate mode (auto = adaptive dynamic switching based on network)
    final hlsMode = (selectedQuality.value == VideoQuality.auto)
        ? 'auto'
        : 'max';
    await _setMpvProperty('hls-bitrate', hlsMode);

    // 3. Enable stream cache
    await _setMpvProperty('cache', 'yes');

    // 4. Set cache duration in seconds
    await _setMpvProperty('cache-secs', '${config.cacheSecs}');

    // 5. Demuxer readahead & max cache buffer size for smooth network transitions (2G/3G/4G/WiFi)
    await _setMpvProperty(
      'demuxer-readahead-secs',
      '${config.demuxerReadaheadSecs}',
    );
    await _setMpvProperty('demuxer-max-bytes', '${config.demuxerMaxBytes}');
    await _setMpvProperty(
      'demuxer-max-back-bytes',
      '${config.demuxerMaxBackBytes}',
    );

    // 5. Network read timeout
    await _setMpvProperty('network-timeout', '${config.networkTimeoutSecs}');

    // 6. User Agent header if required
    await _setMpvProperty('user-agent', 'CloudflareStream-Flutter-MediaKit');

    // 7. Instant startup options (0ms probe delay for Cloudflare Stream & direct MP4)
    await _setMpvProperty('demuxer-lavf-analyzeduration', '0');
    await _setMpvProperty('demuxer-lavf-probesize', '32768');
    await _setMpvProperty('force-seekable', 'yes');
  }

  /// Helper to safely set native MPV properties across platforms.
  Future<void> _setMpvProperty(String name, String value) async {
    if (_isDisposed || _isTestMode) return;
    try {
      final platform = _player.platform;
      if (platform != null) {
        await (platform as dynamic).setProperty(name, value);
      }
    } catch (e) {
      debugPrint(
        '[SmartVideoController] Could not set MPV property "$name=$value": $e',
      );
    }
  }

  /// Dynamically enables hardware-accelerated video decoding (MediaCodec) for the active foreground stream.
  Future<void> enableHardwareDecoding() async {
    if (_isDisposed || _isTestMode) return;
    try {
      await _setMpvProperty('hwdec', 'auto-safe');
      debugPrint(
        '🚀 [SmartVideoController #${identityHashCode(this)}] Hardware decoding upgraded (hwdec: auto-safe)',
      );
    } catch (_) {}
  }

  /// Releases the hardware video decode session (switches to software decoding / idle).
  Future<void> disableHardwareDecoding() async {
    if (_isDisposed || _isTestMode) return;
    try {
      await _setMpvProperty('hwdec', 'no');
      debugPrint(
        '⚙️ [SmartVideoController #${identityHashCode(this)}] Stepped down to software decoding (hwdec: no)',
      );
    } catch (_) {}
  }

  /// Starts background dropped-frame monitoring to diagnose CPU/decode pressure.
  void _startPerfMonitor() {
    _perfMonitorTimer?.cancel();
    _perfMonitorTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_isDisposed || !isPlaying.value || _isTestMode) return;
      try {
        final platform = _player.platform;
        if (platform != null) {
          final dropCount = await (platform as dynamic).getProperty(
            'decoder-frame-drop-count',
          );
          final drops = int.tryParse(dropCount?.toString() ?? '0') ?? 0;
          if (drops > _lastDroppedFrames) {
            final diff = drops - _lastDroppedFrames;
            _lastDroppedFrames = drops;
            debugPrint(
              '⚠️ [SmartVideoController #${identityHashCode(this)}] Dropped $diff frames (total: $drops) | CPU/Decode Pressure',
            );
          }
        }
      } catch (_) {}
    });
  }

  /// Stops background dropped-frame monitoring.
  void _stopPerfMonitor() {
    _perfMonitorTimer?.cancel();
    _perfMonitorTimer = null;
  }

  /// Attaches listeners to media_kit streams.
  void _setupListeners() {
    // 1. Playback State
    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        if (_isDisposed) return;
        isPlaying.value = playing;
        if (playing) {
          _wasPlayingBeforeError = true;
          hasStartedPlaying.value = true;
          isInitializing.value = false;
          isBuffering.value = false;
          lifecycleState.value = SmartVideoState.playing;
          errorMessage.value = null;
          isRetrying.value = false;
          _currentRetryAttempt = 0;
          retryAttempt.value = 0;
          _onResolutionUpdated();
        } else {
          if (!_wasPlayingBeforeError && !isRetrying.value) {
            if (lifecycleState.value != SmartVideoState.disposed &&
                !_hasCodecError) {
              lifecycleState.value = SmartVideoState.ready;
            }
          } else if (_wasPlayingBeforeError && !isRetrying.value) {
            lifecycleState.value = SmartVideoState.paused;
          }
        }
      }),
    );

    // 2. Position tracking
    _subscriptions.add(
      _player.stream.position.listen((pos) {
        if (_isDisposed) return;

        // Ignore stale position events if we recently sought to Duration.zero / rewound
        if (isRewinding.value) {
          if (pos <= const Duration(milliseconds: 200)) {
            isRewinding.value = false;
          } else {
            // Check for timeout if native seek already passed
            if (_lastSeekTime != null &&
                DateTime.now().difference(_lastSeekTime!) >
                    const Duration(milliseconds: 400)) {
              isRewinding.value = false;
            } else {
              // Suppress stale pre-seek event
              return;
            }
          }
        }

        position.value = pos;
        if (pos > Duration.zero || isPlaying.value) {
          _lastPlaybackPosition = pos;
          if (!hasStartedPlaying.value) {
            hasStartedPlaying.value = true;
            isInitializing.value = false;
            isBuffering.value = false;
            _captureInitialFrame();
          }
        }
      }),
    );

    // 3. Duration
    _subscriptions.add(
      _player.stream.duration.listen((dur) {
        if (_isDisposed) return;
        duration.value = dur;
        if (dur > Duration.zero &&
            !isPlaying.value &&
            !_hasCodecError &&
            lifecycleState.value == SmartVideoState.preloading) {
          lifecycleState.value = SmartVideoState.ready;
          _captureInitialFrame();
        }
      }),
    );

    // 4. Buffering
    _subscriptions.add(
      _player.stream.buffering.listen((buffering) {
        if (_isDisposed) return;
        isBuffering.value = buffering;
      }),
    );

    // 5. Buffer duration
    _subscriptions.add(
      _player.stream.buffer.listen((buf) {
        if (_isDisposed) return;
        buffer.value = buf;
        if (buf > Duration.zero) {
          if (!isPlaying.value &&
              !_hasCodecError &&
              lifecycleState.value == SmartVideoState.preloading) {
            lifecycleState.value = SmartVideoState.ready;
          }
          if (capturedFrame.value == null && !_hasCodecError) {
            _captureInitialFrame();
          }
        }
      }),
    );

    // 6. Playback Rate
    _subscriptions.add(
      _player.stream.rate.listen((rate) {
        if (_isDisposed) return;
        playbackRate.value = rate;
      }),
    );

    // 7. Completed
    _subscriptions.add(
      _player.stream.completed.listen((completed) {
        if (_isDisposed) return;
        isCompleted.value = completed;
        if (completed && !config.loop) {
          isPlaying.value = false;
        }
      }),
    );

    // 8. Error handling & Resilience
    _subscriptions.add(
      _player.stream.error.listen((error) {
        if (_isDisposed) return;
        debugPrint('🚨 [SmartVideoController] stream.error: $error');
        _handlePlaybackError(error.toString());
      }),
    );

    // 9. Real-time Video Resolution / Pixel Tracking
    _subscriptions.add(
      _player.stream.width.listen((w) {
        if (_isDisposed) return;
        videoWidth.value = w;
        _onResolutionUpdated();
      }),
    );

    _subscriptions.add(
      _player.stream.height.listen((h) {
        if (_isDisposed) return;
        videoHeight.value = h;
        _onResolutionUpdated();
      }),
    );
  }

  /// Called whenever video stream pixel dimensions change (Adaptive Bitrate Switch)
  void _onResolutionUpdated() {
    final w = videoWidth.value ?? _player.state.width;
    final h = videoHeight.value ?? _player.state.height;

    if (w != null && h != null && w > 0 && h > 0) {
      if (capturedFrame.value == null) {
        _captureInitialFrame();
      }
      if (_lastLoggedWidth != w || _lastLoggedHeight != h) {
        final previousLabel =
            (_lastLoggedWidth != null && _lastLoggedHeight != null)
            ? '${_lastLoggedWidth}x$_lastLoggedHeight (${formatResolution(_lastLoggedWidth!, _lastLoggedHeight!)})'
            : 'Initial Stream Start';

        _lastLoggedWidth = w;
        _lastLoggedHeight = h;

        final label = formatResolution(w, h);
        currentResolution.value = label;

        final logMsg =
            '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
            '🎬 [Cloudflare Adaptive Video Playing]\n'
            '📍 Video URL   : $originalUrl\n'
            '📺 Resolution  : ${w}x$h (Quality: $label)\n'
            '🔄 Transition  : $previousLabel ➔ ${w}x$h ($label)\n'
            '⚡ Bitrate Mode: 100% Network-Adaptive (hls-bitrate=auto)\n'
            '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
        debugPrint(logMsg);
      }
    }
  }

  /// Maps video pixel width and height to human-readable quality labels (240p/360p/480p/720p/1080p).
  /// Accurately handles both landscape and portrait (vertical/Shorts) video streams.
  static String formatResolution(int w, int h) {
    final minDim = w < h ? w : h;
    if (minDim >= 1080) return '1080p';
    if (minDim >= 720) return '720p';
    if (minDim >= 480) return '480p';
    if (minDim >= 360) return '360p';
    if (minDim >= 240) return '240p';
    return '${minDim}p';
  }

  /// Resolves the URL for the selected quality using Cloudflare Stream query parameters.
  String _resolveUrlForQuality(VideoQuality quality) {
    if (originalUrl.isEmpty) return originalUrl;

    try {
      final uri = Uri.parse(originalUrl);
      final queryParams = Map<String, String>.from(uri.queryParameters);

      if (quality == VideoQuality.auto || quality.maxRes == null) {
        queryParams.remove('maxRes');
      } else {
        queryParams['maxRes'] = quality.maxRes!;
      }

      if (queryParams.isEmpty) {
        return uri.replace(query: '').toString().replaceAll(RegExp(r'\?$'), '');
      } else {
        return uri.replace(queryParameters: queryParams).toString();
      }
    } catch (_) {
      return originalUrl;
    }
  }

  /// Opens the stream URL, with optional start position restoration.
  Future<void> _openStream({
    required String targetUrl,
    Duration startPosition = Duration.zero,
  }) async {
    if (_isDisposed || targetUrl.trim().isEmpty) return;

    try {
      // Check local disk video cache for 0ms instant playback
      final cachedPath = VideoCacheManager.instance.getCachedFilePath(targetUrl);
      final playUrl = cachedPath ?? targetUrl;

      // Apply native mpv properties synchronously BEFORE opening media!
      await _applyNativeMpvProperties();

      await _player.open(Media(playUrl), play: _wasPlayingBeforeError);

      if (startPosition > Duration.zero) {
        await _player.seek(startPosition);
      }

      if (_wasPlayingBeforeError && !_player.state.playing) {
        try {
          await _player.play();
        } catch (_) {}
      } else if (!_wasPlayingBeforeError) {
        if (lifecycleState.value != SmartVideoState.ready) {
          lifecycleState.value = SmartVideoState.ready;
        }
      }
    } catch (e) {
      debugPrint(
        '🚨 [SmartVideoController #${identityHashCode(this)}] Playback open error: $e',
      );
      _handlePlaybackError(e.toString());
    }
  }

  /// Handles playback errors and network drops with automatic retry logic.
  void _handlePlaybackError(String error) {
    if (_isDisposed) return;

    final lower = error.toLowerCase();
    // Ignore harmless audio output or non-critical device notifications
    if (lower.contains('audio device') || lower.contains('no sound')) {
      return;
    }

    final bool isCodecFailure =
        lower.contains('could not open codec') ||
        lower.contains('codec') ||
        lower.contains('decoder') ||
        lower.contains('failed to open');

    if (isCodecFailure) {
      debugPrint(
        '⚠️ [SmartVideoController #${identityHashCode(this)}] MediaCodec failure: $error ➔ Instantly falling back to software decoding (hwdec: no)',
      );
      _hasCodecError = false;
      _codecErrorMessage = null;
      errorMessage.value = null;
      _setMpvProperty('hwdec', 'no');
      _openStreamFuture = _openStream(
        targetUrl: _resolveUrlForQuality(selectedQuality.value),
        startPosition: _lastPlaybackPosition,
      );
      return;
    }

    // Do NOT trigger retry loop if controller is in background preload without active playback intent
    if (!_wasPlayingBeforeError &&
        (lifecycleState.value == SmartVideoState.preloading ||
            lifecycleState.value == SmartVideoState.ready ||
            lifecycleState.value == SmartVideoState.paused ||
            lifecycleState.value == SmartVideoState.failed)) {
      debugPrint(
        'ℹ️ [SmartVideoController #${identityHashCode(this)}] Suppressed background/preload stream error while paused: $error',
      );
      return;
    }

    debugPrint(
      '🚨 [SmartVideoController #${identityHashCode(this)}] Playback error: $error (lastPos: $_lastPlaybackPosition, state: ${lifecycleState.value})',
    );

    if (_currentRetryAttempt < config.maxRetries) {
      _currentRetryAttempt++;
      retryAttempt.value = _currentRetryAttempt;
      isRetrying.value = true;
      lifecycleState.value = SmartVideoState.failed;
      errorMessage.value =
          'Connexion instable. Reconnexion ($_currentRetryAttempt/${config.maxRetries})...';

      _retryTimer?.cancel();
      _retryTimer = Timer(config.retryDelay * _currentRetryAttempt, () async {
        if (_isDisposed) return;
        debugPrint(
          '[SmartVideoController #${identityHashCode(this)}] Retrying stream playback (attempt $_currentRetryAttempt)...',
        );
        if (isCodecFailure) {
          await _setMpvProperty('hwdec', 'no');
        }
        _openStreamFuture = _openStream(
          targetUrl: _resolveUrlForQuality(selectedQuality.value),
          startPosition: _lastPlaybackPosition,
        );
      });
    } else {
      isRetrying.value = false;
      lifecycleState.value = SmartVideoState.failed;
      errorMessage.value =
          'Échec de lecture de la vidéo. Vérifiez votre connexion Internet.';
    }
  }

  // --- Public Control APIs ---

  /// Starts or resumes playback.
  Future<void> play() async {
    if (_isDisposed) return;
    _wasPlayingBeforeError = true;

    // Await in-flight open operation before issuing play
    if (_openStreamFuture != null) {
      try {
        await _openStreamFuture;
      } catch (_) {}
    }
    if (_isDisposed) return;

    if (_isTestMode) {
      isPlaying.value = true;
      lifecycleState.value = SmartVideoState.playing;
    }
    final bool reachedEnd =
        isCompleted.value ||
        (duration.value > Duration.zero &&
            position.value.inMilliseconds >=
                duration.value.inMilliseconds - 100);
    if (reachedEnd) {
      debugPrint(
        '🔄 [SmartVideoController #${identityHashCode(this)}] Reached end of video (pos: ${position.value.inMilliseconds}ms / dur: ${duration.value.inMilliseconds}ms) — seeking to start',
      );
      await seek(Duration.zero);
      isCompleted.value = false;
    }
    final beforeState = _player.state;
    debugPrint(
      '🎬 [SmartVideoController #${identityHashCode(this)}] Dispatching _player.play() '
      '(before: playing=${beforeState.playing}, buffering=${beforeState.buffering}, '
      'dur=${beforeState.duration.inMilliseconds}ms, buf=${beforeState.buffer.inMilliseconds}ms, '
      'pos=${beforeState.position.inMilliseconds}ms, state=${lifecycleState.value.name})',
    );

    try {
      await _player.play();
      _startPerfMonitor();
    } catch (e) {
      debugPrint(
        '🚨 [SmartVideoController #${identityHashCode(this)}] _player.play() threw: $e',
      );
    }

    final afterState = _player.state;
    debugPrint(
      '🎬 [SmartVideoController #${identityHashCode(this)}] Completed _player.play() '
      '(after: playing=${afterState.playing}, buffering=${afterState.buffering}, '
      'dur=${afterState.duration.inMilliseconds}ms, buf=${afterState.buffer.inMilliseconds}ms, '
      'pos=${afterState.position.inMilliseconds}ms)',
    );
  }

  /// Pauses playback.
  Future<void> pause() async {
    if (_isDisposed) return;
    _wasPlayingBeforeError = false;
    lifecycleState.value = SmartVideoState.paused;
    _stopPerfMonitor();
    if (_isTestMode) {
      isPlaying.value = false;
    }
    try {
      await _player.pause();
    } catch (_) {}
  }

  /// Toggles between play and pause.
  Future<void> togglePlayPause() async {
    if (isPlaying.value) {
      await pause();
    } else {
      await play();
    }
  }

  /// Seeks to a specific duration in playback.
  Future<void> seek(Duration newPosition) async {
    if (_isDisposed) return;
    _lastPlaybackPosition = newPosition;
    _lastSeekTime = DateTime.now();
    if (newPosition == Duration.zero) {
      isRewinding.value = true;
      isCompleted.value = false;
    }
    position.value = newPosition;
    try {
      await _player.seek(newPosition);
    } catch (_) {}
  }

  /// Sets playback speed multiplier (e.g. 0.5x, 1.0x, 1.25x, 1.5x, 2.0x).
  Future<void> setRate(double rate) async {
    if (_isDisposed) return;
    try {
      await _player.setRate(rate);
    } catch (_) {}
  }

  /// Sets playback volume (0.0 to 100.0).
  Future<void> setVolume(double newVolume) async {
    if (_isDisposed) return;
    final clamped = newVolume.clamp(0.0, 100.0);
    volume.value = clamped;
    isMuted.value = clamped == 0.0;
    try {
      await _player.setVolume(clamped);
    } catch (_) {}
  }

  /// Toggles mute state while preserving previous volume level.
  Future<void> toggleMute() async {
    if (_isDisposed) return;
    if (isMuted.value) {
      final targetVol = volume.value > 0 ? volume.value : 100.0;
      isMuted.value = false;
      try {
        await _player.setVolume(targetVol);
      } catch (_) {}
    } else {
      isMuted.value = true;
      try {
        await _player.setVolume(0.0);
      } catch (_) {}
    }
  }

  /// Changes the video quality.
  ///
  /// For [VideoQuality.auto]: re-enables `hls-bitrate: auto` and strips `?maxRes=`.
  /// For manual qualities (360p, 480p, 720p, 1080p): appends `?maxRes=<val>` and retains current playback position.
  Future<void> setQuality(VideoQuality quality) async {
    if (_isDisposed || selectedQuality.value == quality) return;

    selectedQuality.value = quality;
    final currentPos = position.value;
    final currentPlaying = isPlaying.value;

    isBuffering.value = true;

    // 1. Re-configure MPV HLS mode
    await _applyNativeMpvProperties();

    // 2. Resolve URL and reopen at current position
    final targetUrl = _resolveUrlForQuality(quality);
    _openStreamFuture = _openStream(
      targetUrl: targetUrl,
      startPosition: currentPos,
    );
    await _openStreamFuture;

    if (currentPlaying) {
      try {
        await _player.play();
      } catch (_) {}
    }
  }

  /// Manually triggers a retry attempt from the current position.
  Future<void> retry() async {
    if (_isDisposed) return;
    _currentRetryAttempt = 0;
    retryAttempt.value = 0;
    errorMessage.value = null;
    isRetrying.value = true;

    await _applyNativeMpvProperties();
    _openStreamFuture = _openStream(
      targetUrl: _resolveUrlForQuality(selectedQuality.value),
      startPosition: _lastPlaybackPosition,
    );
    await _openStreamFuture;
  }

  /// Captures the current video frame as raw image bytes (JPEG) directly from the stream using libmpv.
  Future<Uint8List?> captureFrame({String format = 'image/jpeg'}) async {
    if (_isDisposed) return null;
    try {
      final bytes = await _player.screenshot(format: format);
      if (bytes != null && bytes.isNotEmpty && !_isDisposed) {
        capturedFrame.value = bytes;
        return bytes;
      }
    } catch (e) {
      debugPrint('[SmartVideoController] Frame capture error: $e');
    }
    return null;
  }

  void _captureInitialFrame() {
    if (capturedFrame.value == null && !_isDisposed) {
      captureFrame();
    }
  }

  /// Disposes all player and controller resources safely.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    lifecycleState.value = SmartVideoState.disposed;

    _retryTimer?.cancel();
    _retryTimer = null;
    _stopPerfMonitor();

    if (_openStreamFuture != null) {
      try {
        await _openStreamFuture;
      } catch (_) {}
    }

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _player.dispose();
    } catch (_) {}

    isInitializing.dispose();
    isPlaying.dispose();
    isBuffering.dispose();
    hasStartedPlaying.dispose();
    isCompleted.dispose();
    position.dispose();
    duration.dispose();
    buffer.dispose();
    volume.dispose();
    isMuted.dispose();
    playbackRate.dispose();
    selectedQuality.dispose();
    videoWidth.dispose();
    videoHeight.dispose();
    currentResolution.dispose();
    capturedFrame.dispose();
    isRetrying.dispose();
    retryAttempt.dispose();
    errorMessage.dispose();
    isRewinding.dispose();
    lifecycleState.dispose();
  }
}
