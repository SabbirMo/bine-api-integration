import 'dart:async';
import 'package:binetatour/presentation/home/widget/story_details.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoStoryScreen extends StatefulWidget {
  final List<StoryContent> stories; // Updated to use your model

  const VideoStoryScreen({super.key, required this.stories});

  @override
  State<VideoStoryScreen> createState() => _VideoStoryScreenState();
}

class _VideoStoryScreenState extends State<VideoStoryScreen> {
  VideoPlayerController? _controller;
  int _currentIndex = 0;
  bool _isMuted = false;
  Timer? _timer; // To handle progress for images/audio
  double _manualProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStory(_currentIndex);
  }

  void _loadStory(int index) {
    _cancelTimer();
    _controller?.dispose();
    _controller = null;
    _manualProgress = 0.0;

    final story = widget.stories[index];

    if (story.isVideo) {
      _initializeVideo(story);
    } else {
      // For Image or Audio, we start a manual 5-second timer
      _startTimer();
    }
    setState(() {});
  }

  void _initializeVideo(StoryContent story) {
    _controller = story.isNetwork 
        ? VideoPlayerController.networkUrl(Uri.parse(story.url))
        : VideoPlayerController.asset(story.url);

    _controller!..initialize().then((_) {
      if (mounted) {
        setState(() {});
        _controller!.setVolume(_isMuted ? 0 : 1);
        _controller!.play();
        _controller!.addListener(_videoListener);
      }
    });
  }

  void _videoListener() {
    if (_controller!.value.position >= _controller!.value.duration) {
      _nextStory();
    }
  }

  void _startTimer() {
    const duration = Duration(seconds: 5);
    const tick = Duration(milliseconds: 50);
    int elapsed = 0;

    _timer = Timer.periodic(tick, (t) {
      setState(() {
        elapsed += tick.inMilliseconds;
        _manualProgress = elapsed / duration.inMilliseconds;
      });

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
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Content Layer (Image / Video / Audio)
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
                          controller: _controller,
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
      return story.isNetwork 
          ? Image.network(story.url, fit: BoxFit.contain) 
          : Image.asset(story.url, fit: BoxFit.contain);
    } 
    
    if (story.isVideo || story.isAudio) {
      // If audio, you can show a special UI or just a black screen with the player
      if (_controller != null && _controller!.value.isInitialized) {
        return AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller!),
              if (story.isAudio) 
                const Icon(Icons.music_note, size: 100, color: Colors.white54),
            ],
          ),
        );
      }
    }
    return const CircularProgressIndicator(color: Color(0xFFFF6900));
  }

  Widget _buildNavigationControls() {
    return Row(
      children: [
        Expanded(child: GestureDetector(onTap: _previousStory, behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
        Expanded(child: GestureDetector(onTap: _nextStory, behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
      ],
    );
  }

  Widget _buildHeader() {
     return Row(
      children: [
        const CircleAvatar(radius: 16, backgroundColor: Colors.grey),
        const SizedBox(width: 10),
        const Text("Story Content", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        const Spacer(),
        _buildCircularButton(
          icon: _isMuted ? Icons.volume_off : Icons.volume_up,
          onTap: () {
            setState(() {
              _isMuted = !_isMuted;
              _controller?.setVolume(_isMuted ? 0 : 1);
            });
          },
        ),
        const SizedBox(width: 12),
        _buildCircularButton(icon: Icons.close, onTap: () => Navigator.pop(context)),
      ],
    );
  }

  Widget _buildCircularButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38, width: 38,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class VideoProgressBar extends StatelessWidget {
  final int index;
  final int currentIndex;
  final VideoPlayerController? controller;
  final double manualProgress;

  const VideoProgressBar({
    super.key,
    required this.index,
    required this.currentIndex,
    this.controller,
    required this.manualProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2.5,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
      child: index < currentIndex
          ? Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)))
          : index == currentIndex
              ? (controller != null 
                  ? AnimatedBuilder(
                      animation: controller!,
                      builder: (context, child) {
                        final vProgress = (controller!.value.isInitialized)
                            ? controller!.value.position.inMilliseconds / controller!.value.duration.inMilliseconds
                            : 0.0;
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
      child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
    );
  }
}