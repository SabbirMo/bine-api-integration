import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class HomeProductCardProvider extends ChangeNotifier {
  final String videoUrl;

  Player? _player;
  VideoController? _videoController;
  bool _isInitializing = false;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _hasStartedPlaying = false;
  bool _isDisposed = false;

  HomeProductCardProvider({required this.videoUrl});

  Player? get player => _player;
  VideoController? get videoController => _videoController;
  bool get isInitializing => _isInitializing;
  bool get hasError => _hasError;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get hasStartedPlaying => _hasStartedPlaying;
  bool get isVideoReady => _player != null && _videoController != null;

  Future<void> playVideo() async {
    if (_isInitializing || _player != null) return;

    _isInitializing = true;
    _hasError = false;
    _isBuffering = true;
    _hasStartedPlaying = false;
    notifyListeners();

    try {
      _player = Player();
      _videoController = VideoController(
        _player!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );

      _player!.setPlaylistMode(PlaylistMode.single);

      _player!.stream.playing.listen((playing) {
        if (!_isDisposed) {
          _isPlaying = playing;
          if (playing) {
            _hasStartedPlaying = true;
            _isBuffering = false;
            _isInitializing = false;
          }
          notifyListeners();
        }
      });

      _player!.stream.position.listen((pos) {
        if (!_isDisposed && pos > Duration.zero) {
          _hasStartedPlaying = true;
          _isBuffering = false;
          notifyListeners();
        }
      });

      _player!.stream.buffering.listen((buffering) {
        if (!_isDisposed) {
          if (_isPlaying || _hasStartedPlaying) {
            _isBuffering = false;
          } else {
            _isBuffering = buffering;
          }
          notifyListeners();
        }
      });

      await _player!.open(Media(videoUrl));
    } catch (e) {
      debugPrint('Video Init Error: $e');
      if (!_isDisposed) {
        _isInitializing = false;
        _hasError = true;
        _isBuffering = false;
        _hasStartedPlaying = false;
        _player?.dispose();
        _player = null;
        _videoController = null;
        notifyListeners();
      }
    }
  }

  void togglePlayPause() {
    if (_player == null) return;
    if (_isPlaying) {
      _player!.pause();
    } else {
      _player!.play();
    }
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _player?.dispose();
    super.dispose();
  }
}
