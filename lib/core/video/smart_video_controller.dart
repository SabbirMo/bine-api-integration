import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  final ValueNotifier<bool> isInitializing = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isBuffering = ValueNotifier<bool>(true);
  final ValueNotifier<bool> hasStartedPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isCompleted = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> buffer = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<double> volume = ValueNotifier<double>(100.0);
  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);
  final ValueNotifier<double> playbackRate = ValueNotifier<double>(1.0);
  final ValueNotifier<VideoQuality> selectedQuality = ValueNotifier<VideoQuality>(VideoQuality.auto);
  final ValueNotifier<int?> videoWidth = ValueNotifier<int?>(null);
  final ValueNotifier<int?> videoHeight = ValueNotifier<int?>(null);
  final ValueNotifier<String> currentResolution = ValueNotifier<String>('Detecting...');
  final ValueNotifier<Uint8List?> capturedFrame = ValueNotifier<Uint8List?>(null);
  final ValueNotifier<bool> isRetrying = ValueNotifier<bool>(false);
  final ValueNotifier<int> retryAttempt = ValueNotifier<int>(0);
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);

  int? _lastLoggedWidth;
  int? _lastLoggedHeight;

  // Getters
  Player get player => _player;
  VideoController get videoController => _videoController;
  bool get isDisposed => _isDisposed;

  SmartVideoController({
    required this.originalUrl,
    this.config = const SmartVideoConfig(),
  }) {
    _initPlayer();
  }

  /// Initializes Player, VideoController, native mpv properties, and stream listeners.
  void _initPlayer() {
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

    _player.setPlaylistMode(config.loop ? PlaylistMode.loop : PlaylistMode.none);
    _player.setVolume(config.initialMuted ? 0.0 : config.initialVolume);

    _setupListeners();
    _applyNativeMpvProperties();
    _openStream(targetUrl: _resolveUrlForQuality(selectedQuality.value), startPosition: Duration.zero);
  }

  /// Sets underlying MPV / libmpv platform properties for adaptive bitrate & smooth streaming.
  Future<void> _applyNativeMpvProperties() async {
    if (_isDisposed) return;

    // 1. Configure HLS Bitrate mode (auto = adaptive dynamic switching based on network)
    final hlsMode = (selectedQuality.value == VideoQuality.auto) ? 'auto' : 'max';
    await _setMpvProperty('hls-bitrate', hlsMode);

    // 2. Enable stream cache
    await _setMpvProperty('cache', 'yes');

    // 3. Set cache duration in seconds
    await _setMpvProperty('cache-secs', '${config.cacheSecs}');

    // 4. Demuxer readahead & max cache buffer size for smooth network transitions (2G/3G/4G/WiFi)
    await _setMpvProperty('demuxer-readahead-secs', '${config.demuxerReadaheadSecs}');
    await _setMpvProperty('demuxer-max-bytes', '${config.demuxerMaxBytes}');
    await _setMpvProperty('demuxer-max-back-bytes', '${config.demuxerMaxBackBytes}');

    // 5. Network read timeout
    await _setMpvProperty('network-timeout', '${config.networkTimeoutSecs}');

    // 6. User Agent header if required
    await _setMpvProperty('user-agent', 'CloudflareStream-Flutter-MediaKit');
  }

  /// Helper to safely set native MPV properties across platforms.
  Future<void> _setMpvProperty(String name, String value) async {
    if (_isDisposed) return;
    try {
      final platform = _player.platform;
      if (platform != null) {
        await (platform as dynamic).setProperty(name, value);
      }
    } catch (e) {
      debugPrint('[SmartVideoController] Could not set MPV property "$name=$value": $e');
    }
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
          errorMessage.value = null;
          isRetrying.value = false;
          _currentRetryAttempt = 0;
          retryAttempt.value = 0;
          _onResolutionUpdated();
        }
      }),
    );

    // 2. Position tracking
    _subscriptions.add(
      _player.stream.position.listen((pos) {
        if (_isDisposed) return;
        position.value = pos;
        if (pos > Duration.zero) {
          _lastPlaybackPosition = pos;
          if (!hasStartedPlaying.value) {
            hasStartedPlaying.value = true;
            isInitializing.value = false;
            isBuffering.value = false;
            _captureInitialFrame();
          }
          _onResolutionUpdated();
        }
      }),
    );

    // 3. Duration
    _subscriptions.add(
      _player.stream.duration.listen((dur) {
        if (_isDisposed) return;
        duration.value = dur;
      }),
    );

    // 4. Buffering
    _subscriptions.add(
      _player.stream.buffering.listen((buffering) {
        if (_isDisposed) return;
        if (hasStartedPlaying.value) {
          isBuffering.value = buffering;
        } else {
          isBuffering.value = true;
        }
      }),
    );

    // 5. Buffer duration
    _subscriptions.add(
      _player.stream.buffer.listen((buf) {
        if (_isDisposed) return;
        buffer.value = buf;
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
      if (_lastLoggedWidth != w || _lastLoggedHeight != h) {
        final previousLabel = (_lastLoggedWidth != null && _lastLoggedHeight != null)
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
      await _player.open(
        Media(targetUrl),
        play: _wasPlayingBeforeError,
      );

      if (startPosition > Duration.zero) {
        await _player.seek(startPosition);
      }
    } catch (e) {
      _handlePlaybackError(e.toString());
    }
  }

  /// Handles playback errors and network drops with automatic retry logic.
  void _handlePlaybackError(String error) {
    final lower = error.toLowerCase();
    // Ignore harmless audio output or non-critical device notifications
    if (lower.contains('audio device') || lower.contains('no sound')) {
      return;
    }

    debugPrint('[SmartVideoController] Playback error: $error (lastPos: $_lastPlaybackPosition)');

    if (_currentRetryAttempt < config.maxRetries) {
      _currentRetryAttempt++;
      retryAttempt.value = _currentRetryAttempt;
      isRetrying.value = true;
      errorMessage.value = 'Connexion instable. Reconnexion ($_currentRetryAttempt/${config.maxRetries})...';

      _retryTimer?.cancel();
      _retryTimer = Timer(config.retryDelay * _currentRetryAttempt, () {
        if (_isDisposed) return;
        debugPrint('[SmartVideoController] Retrying stream playback (attempt $_currentRetryAttempt)...');
        _openStream(
          targetUrl: _resolveUrlForQuality(selectedQuality.value),
          startPosition: _lastPlaybackPosition,
        );
      });
    } else {
      isRetrying.value = false;
      errorMessage.value = 'Échec de lecture de la vidéo. Vérifiez votre connexion Internet.';
    }
  }

  // --- Public Control APIs ---

  /// Starts or resumes playback.
  Future<void> play() async {
    if (_isDisposed) return;
    _wasPlayingBeforeError = true;
    if (isCompleted.value) {
      await seek(Duration.zero);
      isCompleted.value = false;
    }
    await _player.play();
  }

  /// Pauses playback.
  Future<void> pause() async {
    if (_isDisposed) return;
    _wasPlayingBeforeError = false;
    await _player.pause();
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
    await _player.seek(newPosition);
  }

  /// Sets playback speed multiplier (e.g. 0.5x, 1.0x, 1.25x, 1.5x, 2.0x).
  Future<void> setRate(double rate) async {
    if (_isDisposed) return;
    await _player.setRate(rate);
  }

  /// Sets playback volume (0.0 to 100.0).
  Future<void> setVolume(double newVolume) async {
    if (_isDisposed) return;
    final clamped = newVolume.clamp(0.0, 100.0);
    volume.value = clamped;
    isMuted.value = clamped == 0.0;
    await _player.setVolume(clamped);
  }

  /// Toggles mute state while preserving previous volume level.
  Future<void> toggleMute() async {
    if (_isDisposed) return;
    if (isMuted.value) {
      final targetVol = volume.value > 0 ? volume.value : 100.0;
      isMuted.value = false;
      await _player.setVolume(targetVol);
    } else {
      isMuted.value = true;
      await _player.setVolume(0.0);
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
    await _openStream(targetUrl: targetUrl, startPosition: currentPos);

    if (currentPlaying) {
      await _player.play();
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
    await _openStream(
      targetUrl: _resolveUrlForQuality(selectedQuality.value),
      startPosition: _lastPlaybackPosition,
    );
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

    _retryTimer?.cancel();
    _retryTimer = null;

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    try {
      await _player.stop();
    } catch (_) {}
    await _player.dispose();

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
  }
}
