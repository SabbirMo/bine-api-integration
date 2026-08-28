import 'dart:async';
import 'dart:ui';
import 'package:binetatour/presentation/home/widget/story_details.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/story_provider.dart';

class VideoStoryScreen extends StatefulWidget {
  final List<StoryContent> stories;

  const VideoStoryScreen({super.key, required this.stories});

  @override
  State<VideoStoryScreen> createState() => _VideoStoryScreenState();
}

class _VideoStoryScreenState extends State<VideoStoryScreen> {
  Player? _player;
  VideoController? _videoController;
  int _currentIndex = 0;
  bool _isMuted = false;
  Timer? _timer;
  double _manualProgress = 0.0;
  bool _isLoading = false;

  StreamSubscription? _positionSub;

  @override
  void initState() {
    super.initState();
    _loadStory(_currentIndex);
  }

  void _loadStory(int index) {
    _cancelTimer();

    if (_player != null) {
      _positionSub?.cancel();
      _player?.dispose();
    }

    _player = null;
    _videoController = null;
    _manualProgress = 0.0;
    _isLoading = true;

    final story = widget.stories[index];

    // Call API to mark story as viewed
    if (story.id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<StoryProvider>().viewStory(story.id!);
        }
      });
    }

    if (story.isVideo) {
      _initializeVideo(story);
    } else {
      _isLoading = false;
      _startTimer();
    }
    setState(() {});
  }

  void _initializeVideo(StoryContent story) {
    _player = Player();
    _videoController = VideoController(
      _player!,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _player!.setVolume(_isMuted ? 0.0 : 100.0);

    if (story.isNetwork) {
      _player!.open(Media(story.url));
    } else {
      // media_kit supports assets via asset:// schema
      _player!.open(Media('asset://${story.url}'));
    }

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

    _player!.stream.width.listen((width) {
      if (mounted) setState(() {});
    });

    _player!.stream.height.listen((height) {
      if (mounted) setState(() {});
    });

    setState(() {});
  }

  void _startTimer() {
    const duration = Duration(seconds: 5);
    const tick = Duration(milliseconds: 50);
    int elapsed = 0;

    _timer = Timer.periodic(tick, (t) {
      if (mounted) {
        setState(() {
          elapsed += tick.inMilliseconds;
          _manualProgress = elapsed / duration.inMilliseconds;
        });
      }

      if (elapsed >= duration.inMilliseconds) {
        _nextStory();
      }
    });
  }

  void _cancelTimer() => _timer?.cancel();

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _loadStory(_currentIndex);
    } else {
      Navigator.pop(context);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Content Layer
          Center(child: _buildContent(story)),

          // 2. Navigation Layer
          _buildNavigationControls(),

          // 3. UI Layer
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Progress Bars
                  Row(
                    children: List.generate(
                      widget.stories.length,
                      (index) => Expanded(
                        child: VideoProgressBar(
                          index: index,
                          currentIndex: _currentIndex,
                          player: _player,
                          manualProgress: _manualProgress,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildHeader(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(StoryContent story) {
    if (story.isImage) {
      final imageProvider = story.isNetwork
          ? NetworkImage(story.url)
          : AssetImage(story.url) as ImageProvider;

      return Stack(
        fit: StackFit.expand,
        children: [
          // Blurred background image
          Positioned.fill(
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(alpha: 0.35),
                  colorBlendMode: BlendMode.darken,
                ),
              ),
            ),
          ),
          // Clear foreground image
          Center(
            child: Image(image: imageProvider, fit: BoxFit.contain),
          ),
        ],
      );
    }

    if (story.isVideo || story.isAudio) {
      if (_player != null && _videoController != null) {
        final videoWidth = _player!.state.width?.toDouble() ?? 16.0;
        final videoHeight = _player!.state.height?.toDouble() ?? 9.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            if (!story.isAudio) ...[
              // Background
              Positioned.fill(child: Container(color: Colors.black)),
              // Dark overlay to dim the background
              Positioned.fill(
                child: Container(color: Colors.black.withValues(alpha: 0.25)),
              ),
            ],
            // Foreground Clear Video (Single Video Widget)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: videoWidth,
                  height: videoHeight,
                  child: RepaintBoundary(
                    child: Video(
                      controller: _videoController!,
                      controls: NoVideoControls,
                      fill: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
            if (story.isAudio)
              const Icon(Icons.music_note, size: 100, color: Colors.white54),
            if (_isLoading)
              const CircularProgressIndicator(color: Color(0xFFFF6900)),
          ],
        );
      }
    }
    return const CircularProgressIndicator(color: Color(0xFFFF6900));
  }

  Widget _buildNavigationControls() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _previousStory,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _nextStory,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const CircleAvatar(radius: 16, backgroundColor: Colors.grey),
        const SizedBox(width: 10),
        const Text(
          "Story Content",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        _buildCircularButton(
          icon: _isMuted ? Icons.volume_off : Icons.volume_up,
          onTap: () {
            setState(() {
              _isMuted = !_isMuted;
              _player?.setVolume(_isMuted ? 0.0 : 100.0);
            });
          },
        ),
        const SizedBox(width: 12),
        _buildCircularButton(
          icon: Icons.close,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class VideoProgressBar extends StatelessWidget {
  final int index;
  final int currentIndex;
  final Player? player;
  final double manualProgress;

  const VideoProgressBar({
    super.key,
    required this.index,
    required this.currentIndex,
    this.player,
    required this.manualProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2.5,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: index < currentIndex
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            )
          : index == currentIndex
          ? (player != null
                ? StreamBuilder<Duration>(
                    stream: player!.stream.position,
                    builder: (context, snapshot) {
                      final pos =
                          snapshot.data?.inMilliseconds.toDouble() ?? 0.0;
                      final dur = player!.state.duration.inMilliseconds
                          .toDouble();
                      final vProgress = (dur > 0) ? pos / dur : 0.0;
                      return _progressBox(vProgress);
                    },
                  )
                : _progressBox(manualProgress))
          : const SizedBox.shrink(),
    );
  }

  Widget _progressBox(double width) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: width.clamp(0.0, 1.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
