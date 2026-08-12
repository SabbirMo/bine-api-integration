import 'dart:math';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/story_provider.dart';
import 'package:binetatour/providers/story_detail_provider.dart';

class StoryDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => StoryDetailProvider(
        stories: stories,
        storyProvider: context.read<StoryProvider>(),
        onFinished: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      ),
      child: _StoryDetailContent(userName: userName, userProfile: userProfile),
    );
  }
}

class _StoryDetailContent extends StatelessWidget {
  final String userName;
  final String userProfile;

  const _StoryDetailContent({
    required this.userName,
    required this.userProfile,
  });

  Widget _buildNavigationLayer(
    BuildContext context,
    StoryDetailProvider provider,
    StoryContent story,
  ) {
    if (story.isAudio) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: provider.previousStory,
              onLongPressStart: (_) => provider.pauseStory(),
              onLongPressEnd: (_) => provider.resumeStory(),
              child: const SizedBox.expand(),
            ),
          ),
          const Expanded(flex: 4, child: SizedBox.expand()),
          Expanded(
            flex: 3,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: provider.nextStory,
              onLongPressStart: (_) => provider.pauseStory(),
              onLongPressEnd: (_) => provider.resumeStory(),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < screenWidth / 3) {
          provider.previousStory();
        } else {
          provider.nextStory();
        }
      },
      onLongPressStart: (_) => provider.pauseStory(),
      onLongPressEnd: (_) => provider.resumeStory(),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildMedia(
    BuildContext context,
    StoryDetailProvider provider,
    StoryContent story,
  ) {
    final isLoading = provider.isLoading;
    if (story.isImage) {
      if (story.isNetwork) {
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
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.broken_image, color: Colors.white, size: 50),
            );
          },
        );
      } else {
        return Image.asset(
          story.url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.broken_image, color: Colors.white, size: 50),
            );
          },
        );
      }
    }
    if (story.isAudio) return _buildAudioPlaceholder(provider);
    if (story.isVideo && provider.videoController != null) {
      final String thumb = (story.thumbnailUrl != null &&
              story.thumbnailUrl!.trim().isNotEmpty)
          ? story.thumbnailUrl!
          : userProfile;

      return Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: provider.player!.state.width?.toDouble() ?? 16.0,
                height: provider.player!.state.height?.toDouble() ?? 9.0,
                child: Video(
                  key: ValueKey(provider.currentIndex),
                  controller: provider.videoController!,
                  controls: NoVideoControls,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: isLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !isLoading,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb.startsWith('http'))
                      Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.black),
                      )
                    else if (thumb.isNotEmpty)
                      Image.asset(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.black),
                      )
                    else
                      Container(color: Colors.black),
                    Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6900),
                        strokeWidth: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return const CircularProgressIndicator(color: Colors.white);
  }

  Widget _buildAudioPlaceholder(StoryDetailProvider provider) {
    if (provider.isLoading) {
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
            _StoryAudioWave(isPlaying: provider.isPlaying, isReversed: true),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: provider.togglePlayPause,
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
                      provider.isPlaying
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
            _StoryAudioWave(isPlaying: provider.isPlaying, isReversed: false),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBars(StoryDetailProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: List.generate(provider.stories.length, (index) {
          double val = 0.0;
          if (index < provider.currentIndex) {
            val = 1.0;
          } else if (index == provider.currentIndex) {
            final story = provider.stories[index];
            val = (story.isVideo || story.isAudio)
                ? provider.currentMediaProgress
                : provider.imageProgress;
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
                widthFactor: val.clamp(0.0, 1.0),
                child: Container(color: Colors.white),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, StoryDetailProvider provider) {
    final story = provider.stories[provider.currentIndex];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: userProfile.startsWith('http')
                ? NetworkImage(userProfile)
                : AssetImage(userProfile) as ImageProvider,
          ),
          const SizedBox(width: 12),
          Text(
            userName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            story.createdAt ?? " ",
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              provider.isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
            ),
            onPressed: provider.toggleMute,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoryDetailProvider>();
    final story = provider.stories[provider.currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Media Content (no gesture here)
          Center(child: _buildMedia(context, provider, story)),

          // 2. Navigation zones (long press + tap left/right)
          //    For audio: center 40% is excluded so play button works freely
          _buildNavigationLayer(context, provider, story),

          // 3. UI Overlay (Header + Progress)
          SafeArea(
            child: Column(
              children: [
                _buildProgressBars(provider),
                _buildHeader(context, provider),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StoryContent {
  final int? id;
  final String url;
  final String? fallbackUrl;
  final String? thumbnailUrl;
  final bool isVideo;
  final bool isAudio;
  final bool isImage;
  final bool isNetwork;
  final String? createdAt;

  StoryContent({
    this.id,
    required this.url,
    this.fallbackUrl,
    this.thumbnailUrl,
    required this.isVideo,
    required this.isAudio,
    required this.isImage,
    this.isNetwork = false,
    this.createdAt,
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
