import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class StoryDetailScreen extends StatefulWidget {
  final List<StoryContent> stories;
  final String userName;
  final String userProfile;

  const StoryDetailScreen({
    super.key, 
    required this.stories, 
    this.userName = "User Name",
    this.userProfile = "https://images.pexels.com/photos/771742/pexels-photo-771742.jpeg",
  });

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  VideoPlayerController? _controller;
  int _currentIndex = 0;
  bool _isMuted = false;
  Timer? _timer;
  double _imageProgress = 0.0;
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStory(_currentIndex);
  }

  void _loadStory(int index) {
    _cancelTimer();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _controller = null;
    _imageProgress = 0.0;

    final story = widget.stories[index];

    if (story.isVideo || story.isAudio) {
      _initializeMedia(story);
    } else {
      _startImageTimer();
    }
    setState(() {});
  }

  void _initializeMedia(StoryContent story) {
    _controller = VideoPlayerController.networkUrl(Uri.parse(story.url));
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
    if (_controller != null && _controller!.value.position >= _controller!.value.duration) {
      _nextStory();
    }
  }

  void _startImageTimer() {
    const duration = Duration(seconds: 5);
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (mounted) {
        setState(() => _imageProgress = (t.tick * 50) / duration.inMilliseconds);
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
      _controller?.pause();
      _controller?.removeListener(_videoListener);
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
    _controller?.dispose();
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
              _controller?.pause();
              _cancelTimer();
            },
            onLongPressEnd: (_) {
              if (story.isImage) _startImageTimer(); else _controller?.play();
            },
            child: Center(child: _buildMedia(story)),
          ),

          // 2. UI Overlay (Header + Progress)
          SafeArea(
            child: Column(
              children: [
                _buildProgressBars(),
                _buildHeader(),
                // const Spacer(),
                // _buildFooter(), // Reply bar & Reactions
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(StoryContent story) {
    if (story.isImage) return Image.network(story.url, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    if (story.isAudio) return _buildAudioPlaceholder();
    if (story.isVideo && _controller != null && _controller!.value.isInitialized) {
      return SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _controller!.value.size.width, height: _controller!.value.size.height, child: VideoPlayer(_controller!))));
    }
    return const CircularProgressIndicator(color: Colors.white);
  }

  Widget _buildAudioPlaceholder() {
    return Center(child: InkWell(
      onTap: (){
        setState(() {
          if (_controller != null && _controller!.value.isInitialized) {
            // Toggle between Play and Pause
            _controller!.value.isPlaying 
                ? _controller!.pause() 
                : _controller!.play();
          }
        });
      },
      child: Image.asset("assets/images/music_logo.png")),);
  }

  Widget _buildProgressBars() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: List.generate(widget.stories.length, (index) {
          double val = 0.0;
          if (index < _currentIndex) val = 1.0;
          else if (index == _currentIndex) {
            val = (_controller != null && _controller!.value.isInitialized)
                ? (_controller!.value.position.inMilliseconds / _controller!.value.duration.inMilliseconds)
                : _imageProgress;
          }
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
              child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: val.clamp(0, 1), child: Container(color: Colors.white)),
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
          CircleAvatar(radius: 18, backgroundImage: NetworkImage(widget.userProfile)),
          const SizedBox(width: 12),
          Text(widget.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          const Text("12h", style: TextStyle(color: Colors.white54, fontSize: 12)),
          const Spacer(),
          IconButton(icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white), onPressed: () => setState(() { _isMuted = !_isMuted; _controller?.setVolume(_isMuted ? 0 : 1); })),
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  // Widget _buildFooter() {
  //   return Padding(
  //     padding: const EdgeInsets.all(16.0),
  //     child: Row(
  //       children: [
  //         Expanded(
  //           child: TextField(
  //             controller: _replyController,
  //             style: const TextStyle(color: Colors.white),
  //             decoration: InputDecoration(
  //               hintText: "Send message",
  //               hintStyle: const TextStyle(color: Colors.white60),
  //               contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  //               enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.white38)),
  //               focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.white)),
  //             ),
  //           ),
  //         ),
  //         const SizedBox(width: 15),
  //         const Icon(Icons.favorite_border, color: Colors.white, size: 28),
  //         const SizedBox(width: 15),
  //         const Icon(Icons.send_outlined, color: Colors.white, size: 28),
  //       ],
  //     ),
  //   );
  // }
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