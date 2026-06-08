import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class StoryDetailScreen extends StatefulWidget {
  final List<StoryContent> stories;
  final String userName;
  final String userProfile;

  const StoryDetailScreen({
    super.key,
    required this.stories,
    this.userName = "User Name",
    this.userProfile =
        "https://images.pexels.com/photos/771742/pexels-photo-771742.jpeg",
  });

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  Player? _player;
  VideoController? _videoController;
  int _currentIndex = 0;
  bool _isMuted = false;
  Timer? _timer;
  double _imageProgress = 0.0;
  final TextEditingController _replyController = TextEditingController();

  StreamSubscription? _positionSub;
  double _currentMediaProgress = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStory(_currentIndex);
  }

  void _loadStory(int index) {
    _cancelTimer();
    _positionSub?.cancel();
    _player?.dispose();
    _player = null;
    _videoController = null;
    _imageProgress = 0.0;
    _currentMediaProgress = 0.0;
    _isLoading = true;

    final story = widget.stories[index];

    if (story.isVideo || story.isAudio) {
      _initializeMedia(story);
    } else {
      _isLoading = false;
      startImageTimer();
    }
    setState(() {});
  }

  void _initializeMedia(StoryContent story) {
    _player = Player();
    _videoController = VideoController(
      _player!,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: false,
      ),
    );

    _player!.setVolume(_isMuted ? 0.0 : 100.0);
    if (story.isNetwork) {
      _player!.open(Media(story.url));
    } else {
      _player!.open(Media('asset://${story.url}'));
    }

    _positionSub = _player!.stream.position.listen((pos) {
      if (!mounted) return;
      final dur = _player!.state.duration;
      setState(() {
        if (dur.inMilliseconds > 0) {
          _currentMediaProgress = pos.inMilliseconds / dur.inMilliseconds;
        }
      });
    });

    _player!.stream.completed.listen((completed) {
      if (mounted && completed) {
        _nextStory();
      }
    });

    _player!.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isLoading = buffering);
    });

    _player!.stream.playing.listen((playing) {
      if (mounted && playing) setState(() => _isLoading = false);
    });
  }

  void startImageTimer() {
    const duration = Duration(seconds: 5);
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (mounted) {
        setState(
          () => _imageProgress = (t.tick * 50) / duration.inMilliseconds,
        );
        if (_imageProgress >= 1.0) _nextStory();
      }
    });
  }

  void _cancelTimer() => _timer?.cancel();

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _loadStory(_currentIndex);
    } else {
      _cancelTimer();
      _player?.pause();
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _loadStory(_currentIndex);
    }
  }

  @override
  void dispose() {
    _cancelTimer();
    _positionSub?.cancel();
    _player?.dispose();
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Media Content
          GestureDetector(
            onTapDown: (details) {
              final screenWidth = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < screenWidth / 3) {
                _previousStory();
              } else {
                _nextStory();
              }
            },
            onLongPressStart: (_) {
              _player?.pause();
              _cancelTimer();
            },
            onLongPressEnd: (_) {
              if (story.isImage) {
                startImageTimer();
              } else {
                _player?.play();
              }
            },
            child: Center(child: _buildMedia(story)),
          ),

          // 2. UI Overlay (Header + Progress)
          SafeArea(
            child: Column(children: [_buildProgressBars(), _buildHeader()]),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(StoryContent story) {
    if (story.isImage) {
      return Image.network(
        story.url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6900)),
          );
        },
      );
    }
    if (story.isAudio) return _buildAudioPlaceholder();
    if (story.isVideo && _videoController != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          // Background placeholder while loading to prevent black screen
          if (_isLoading)
            Positioned.fill(
              child: Image.network(
                widget.userProfile,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.7),
                colorBlendMode: BlendMode.darken,
              ),
            ),

          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _player!.state.width?.toDouble() ?? 16.0,
                height: _player!.state.height?.toDouble() ?? 9.0,
                child: Video(
                  controller: _videoController!,
                  controls: NoVideoControls,
                ),
              ),
            ),
          ),
          if (_isLoading)
            const CircularProgressIndicator(color: Color(0xFFFF6900)),
        ],
      );
    }
    return const CircularProgressIndicator(color: Colors.white);
  }

  Widget _buildAudioPlaceholder() {
    return Center(
      child: InkWell(
        onTap: () {
          setState(() {
            if (_player != null) {
              _player!.state.playing ? _player!.pause() : _player!.play();
            }
          });
        },
        child: Image.asset("assets/images/music_logo.png"),
      ),
    );
  }

  Widget _buildProgressBars() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: List.generate(widget.stories.length, (index) {
          double val = 0.0;
          if (index < _currentIndex) {
            val = 1.0;
          } else if (index == _currentIndex) {
            val = (_player != null) ? _currentMediaProgress : _imageProgress;
          }
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: val.clamp(0, 1),
                child: Container(color: Colors.white),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(widget.userProfile),
          ),
          const SizedBox(width: 12),
          Text(
            widget.userName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            "12h",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
            ),
            onPressed: () => setState(() {
              _isMuted = !_isMuted;
              _player?.setVolume(_isMuted ? 0.0 : 100.0);
            }),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class StoryContent {
  final String url;
  final bool isVideo;
  final bool isAudio;
  final bool isImage;
  final bool isNetwork;

  StoryContent({
    required this.url,
    required this.isVideo,
    required this.isAudio,
    required this.isImage,
    this.isNetwork = false,
  });
}
