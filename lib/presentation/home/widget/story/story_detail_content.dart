import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/core/video/video_frame_manager.dart';
import 'package:binetatour/providers/story_detail_provider.dart';
import 'package:binetatour/presentation/home/widget/story/story_models.dart';
import 'package:binetatour/presentation/home/widget/story/story_audio_wave.dart';

class StoryDetailContent extends StatelessWidget {
  final String userName;
  final String userProfile;
  final VoidCallback onNextCategory;
  final VoidCallback onPrevCategory;
  final VoidCallback onClose;

  const StoryDetailContent({
    super.key,
    required this.userName,
    required this.userProfile,
    required this.onNextCategory,
    required this.onPrevCategory,
    required this.onClose,
  });

  Widget _buildNavigationLayer(
    BuildContext context,
    StoryDetailProvider provider,
    StoryContent story,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < screenWidth / 3) {
          provider.previousStory();
        } else {
          provider.nextStory();
        }
      },
      onLongPressStart: (_) => provider.pauseStory(),
      onLongPressEnd: (_) => provider.resumeStory(),
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          onClose();
        }
      },
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
            return Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF6900).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const CircularProgressIndicator(
                  color: Color(0xFFFF6900),
                  strokeWidth: 3.5,
                ),
              ),
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
      final double videoWidth =
          provider.player!.state.width?.toDouble() ?? 16.0;
      final double videoHeight =
          provider.player!.state.height?.toDouble() ?? 9.0;
      final cleanUrl = story.url;

      return Stack(
        alignment: Alignment.center,
        children: [
          // 1. Video Player with blurred frame background
          SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListenableBuilder(
                  listenable: VideoFrameManager.instance,
                  builder: (context, _) {
                    final frameBytes = VideoFrameManager.instance
                        .getCachedFrame(cleanUrl);
                    if (frameBytes != null && frameBytes.isNotEmpty) {
                      return Positioned.fill(
                        child: ClipRect(
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: 15.0,
                              sigmaY: 15.0,
                            ),
                            child: Image.memory(
                              frameBytes,
                              fit: BoxFit.cover,
                              color: Colors.black.withValues(alpha: 0.35),
                              colorBlendMode: BlendMode.darken,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      );
                    }
                    return Positioned.fill(
                      child: Container(color: Colors.black),
                    );
                  },
                ),
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.25)),
                ),
                Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: videoWidth,
                      height: videoHeight,
                      child: Video(
                        key: ValueKey('fg_${provider.currentIndex}'),
                        controller: provider.videoController!,
                        controls: NoVideoControls,
                        fill: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Loading Indicator & Pre-decoded First Frame (NEVER a blank black screen!)
          if (isLoading)
            Positioned.fill(
              child: ListenableBuilder(
                listenable: VideoFrameManager.instance,
                builder: (context, _) {
                  final frameBytes = VideoFrameManager.instance.getCachedFrame(
                    cleanUrl,
                  );

                  Widget? backgroundWidget;
                  if (frameBytes != null && frameBytes.isNotEmpty) {
                    backgroundWidget = Center(
                      child: Image.memory(
                        frameBytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    );
                  }

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (backgroundWidget != null)
                        backgroundWidget
                      else
                        Container(color: Colors.black),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(
                                0xFFFF6900,
                              ).withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const CircularProgressIndicator(
                            color: Color(0xFFFF6900),
                            strokeWidth: 3.5,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      );
    }
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFFF6900).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: const CircularProgressIndicator(
          color: Color(0xFFFF6900),
          strokeWidth: 3.5,
        ),
      ),
    );
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
            StoryAudioWave(isPlaying: provider.isPlaying, isReversed: true),
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
            StoryAudioWave(isPlaying: provider.isPlaying, isReversed: false),
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
    if (provider.stories.isEmpty ||
        provider.currentIndex < 0 ||
        provider.currentIndex >= provider.stories.length) {
      return const SizedBox.shrink();
    }
    final story = provider.stories[provider.currentIndex];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[800],
            backgroundImage:
                userProfile.isNotEmpty && userProfile.startsWith('http')
                ? NetworkImage(userProfile)
                : (userProfile.isNotEmpty
                      ? AssetImage(userProfile) as ImageProvider
                      : null),
            child: userProfile.isEmpty
                ? const Icon(Icons.person, color: Colors.white70, size: 20)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if ((story.createdAt ?? '').trim().isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    story.createdAt!,
                    maxLines: 1,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            icon: Icon(
              provider.isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
              size: 22,
            ),
            onPressed: provider.toggleMute,
          ),
          const SizedBox(width: 8),
          IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoryDetailProvider>();
    if (provider.stories.isEmpty ||
        provider.currentIndex < 0 ||
        provider.currentIndex >= provider.stories.length) {
      return const SizedBox.shrink();
    }
    final story = provider.stories[provider.currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Media Content
          Center(child: _buildMedia(context, provider, story)),

          // 2. Navigation Layer (Immediate 15px swipe triggers auto-scroll to next/prev category!)
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
