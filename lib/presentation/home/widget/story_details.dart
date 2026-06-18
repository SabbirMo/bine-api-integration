import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/story_provider.dart';

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
  bool _isPlaying = false;

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
    _isPlaying = false;

    final story = widget.stories[index];

    // Call API to mark story as viewed
    if (story.id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<StoryProvider>().viewStory(story.id!);
        }
      });
    }

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
      if (mounted) {
        setState(() {
          _isPlaying = playing;
          if (playing) _isLoading = false;
        });
      }
    });

    if (story.isAudio && story.isNetwork) {
      // Audio: download first via Dio then play local file (same fix as ProductAudioItem)
      _downloadAndPlayAudio(story.url);
    } else if (story.isNetwork) {
      _player!.open(Media(story.url));
    } else {
      _player!.open(Media('asset://${story.url}'));
    }
  }

  Future<void> _downloadAndPlayAudio(String url) async {
    try {
      final dio = Dio();
      final tempDir = Directory.systemTemp;
      final fileName = 'story_audio_${url.hashCode}.mp3';
      final savePath = '${tempDir.path}/$fileName';
      final file = File(savePath);

      if (!await file.exists()) {
        await dio.download(url, savePath);
      }

      if (!mounted) return;
      await _player?.open(Media('file://$savePath'));
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Story audio download error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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
          // 1. Media Content (no gesture here)
          Center(child: _buildMedia(story)),

          // 2. Navigation zones (long press + tap left/right)
          //    For audio: center 40% is excluded so play button works freely
          _buildNavigationLayer(story),

          // 3. UI Overlay (Header + Progress)
          SafeArea(
            child: Column(children: [_buildProgressBars(), _buildHeader()]),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationLayer(StoryContent story) {
    // For audio stories, skip the center 30% so the play button isn't blocked
    if (story.isAudio) {
      return Row(
        children: [
          // Left zone → previous story
          Expanded(
            flex: 3,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _previousStory,
              onLongPressStart: (_) {
                _player?.pause();
              },
              onLongPressEnd: (_) => _player?.play(),
              child: const SizedBox.expand(),
            ),
          ),
          // Center gap → play button handles this
          const Expanded(flex: 4, child: SizedBox.expand()),
          // Right zone → next story
          Expanded(
            flex: 3,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _nextStory,
              onLongPressStart: (_) {
                _player?.pause();
              },
              onLongPressEnd: (_) => _player?.play(),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      );
    }

    // For image/video stories: full screen navigation
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
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
      child: const SizedBox.expand(),
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6900)),
      );
    }
    return Container(
      color: Colors.black,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StoryAudioWave(isPlaying: _isPlaying, isReversed: true),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () {
                if (_player != null) {
                  _isPlaying ? _player!.pause() : _player!.play();
                }
              },
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF6900).withValues(alpha: 0.4),
                    width: 2,
                  ),
                  color: Colors.transparent,
                ),
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF6900),
                    ),
                    child: Icon(
                      _isPlaying
                          ? Icons.volume_up_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            _StoryAudioWave(isPlaying: _isPlaying, isReversed: false),
          ],
        ),
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
  final int? id;
  final String url;
  final bool isVideo;
  final bool isAudio;
  final bool isImage;
  final bool isNetwork;

  StoryContent({
    this.id,
    required this.url,
    required this.isVideo,
    required this.isAudio,
    required this.isImage,
    this.isNetwork = false,
  });
}

class _StoryAudioWave extends StatefulWidget {
  final bool isPlaying;
  final bool isReversed;

  const _StoryAudioWave({required this.isPlaying, required this.isReversed});

  @override
  State<_StoryAudioWave> createState() => _StoryAudioWaveState();
}

class _StoryAudioWaveState extends State<_StoryAudioWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StoryAudioWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<double> sideHeights = [
      4,
      6,
      8,
      12,
      10,
      16,
      20,
      14,
      24,
      30,
      22,
      36,
      44,
      32,
      50,
      40,
    ];
    final List<double> actualHeights = widget.isReversed
        ? sideHeights
        : sideHeights.reversed.toList();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(actualHeights.length, (index) {
            final double factor = sin(_controller.value * pi * 2 + index);
            final double baseH = actualHeights[index];
            double currentHeight = widget.isPlaying
                ? baseH + (factor * (baseH * 0.3))
                : baseH * 0.3;
            currentHeight = currentHeight.clamp(2.0, 80.0);
            final double opacity = (baseH / 50).clamp(0.2, 1.0);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: currentHeight,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6900).withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
