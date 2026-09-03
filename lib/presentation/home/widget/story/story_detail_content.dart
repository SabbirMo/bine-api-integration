import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/core/utils/media_url_resolver.dart';
import 'package:binetatour/presentation/common/widgets/video_loading_indicator.dart';
import 'package:binetatour/providers/story_detail_provider.dart';
import 'package:binetatour/presentation/home/widget/story/story_models.dart';
import 'package:binetatour/presentation/home/widget/story/story_audio_wave.dart';
import 'package:binetatour/core/widgets/shimmer/cool_shimmer_kit.dart';

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoryDetailProvider>();

    if (provider.stories.isEmpty ||
        provider.currentIndex < 0 ||
        provider.currentIndex >= provider.stories.length) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text("No stories", style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final currentStory = provider.stories[provider.currentIndex];

    // Eagerly precache all images and thumbnails in active BuildContext for 0ms transitions
    for (final s in provider.stories) {
      if (s.isImage && s.url.isNotEmpty && s.url.startsWith('http')) {
        precacheImage(NetworkImage(s.url), context).catchError((_) {});
      }
      if (s.thumbnailUrl != null &&
          s.thumbnailUrl!.trim().isNotEmpty &&
          s.thumbnailUrl!.startsWith('http')) {
        precacheImage(
          NetworkImage(s.thumbnailUrl!),
          context,
        ).catchError((_) {});
      }
    }
    if (userProfile.isNotEmpty && userProfile.startsWith('http')) {
      precacheImage(NetworkImage(userProfile), context).catchError((_) {});
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Media Layer
          _buildMedia(context, provider, currentStory),

          // 2. Gesture Navigation Overlay (Standard Left 30% Prev / Right 70% Next)
          _buildGestureLayer(context, provider),

          // 3. Dedicated Center Audio Control (Interactive touch ONLY on button/waves, sits above gesture layer)
          if (currentStory.isAudio) _buildAudioCenterControl(provider),

          // 4. Top Controls (Progress Bars & Header)
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProgressBars(provider),
                const SizedBox(height: 6),
                _buildHeader(context, provider, currentStory),
              ],
            ),
          ),

          // 5. Network Stall / Slow Connection Toast (Auto-dismisses when packets arrive)
          if (provider.error != null)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFF6900).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.signal_wifi_connected_no_internet_4_rounded,
                      color: Color(0xFFFF6900),
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Slow Connection',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Waiting for network to reconnect...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    const CoolShimmer(child: CoolShimmerBone.circle(size: 20)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Gesture Navigation ---

  Widget _buildGestureLayer(
    BuildContext context,
    StoryDetailProvider provider,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        final dx = details.globalPosition.dx;
        if (dx < screenWidth * 0.3) {
          provider.previousStory();
        } else {
          provider.nextStory();
        }
      },
      onLongPressStart: (_) => provider.pauseStory(),
      onLongPressEnd: (_) => provider.resumeStory(),
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
          onClose();
        }
      },
      child: const SizedBox.expand(),
    );
  }

  // --- Media Rendering ---

  Widget _buildMedia(
    BuildContext context,
    StoryDetailProvider provider,
    StoryContent story,
  ) {
    if (story.isImage) {
      return Container(
        color: Colors.black,
        child: Image.network(
          story.url,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          width: double.infinity,
          height: double.infinity,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: child,
            );
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: VideoLoadingIndicator(size: 48));
          },
          errorBuilder: (_, e, s) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 54),
          ),
        ),
      );
    }

    if (story.isAudio) {
      return _buildAudioView(provider);
    }

    if (story.isVideo) {
      final String thumb = _resolveStoryThumbnail(story);
      final hasFrame = provider.hasFirstFrame;

      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Live Video Surface A (Hardware Texture)
            if (provider.videoControllerA != null)
              Offstage(
                offstage: !provider.isEngineAActive,
                child: RepaintBoundary(
                  child: SizedBox.expand(
                    child: Video(
                      controller: provider.videoControllerA!,
                      controls: NoVideoControls,
                      fit: BoxFit.contain,
                      fill: Colors.black,
                    ),
                  ),
                ),
              ),

            // 2. Live Video Surface B (Hardware Texture - pre-rolled in background)
            if (provider.videoControllerB != null)
              Offstage(
                offstage: provider.isEngineAActive,
                child: RepaintBoundary(
                  child: SizedBox.expand(
                    child: Video(
                      controller: provider.videoControllerB!,
                      controls: NoVideoControls,
                      fit: BoxFit.contain,
                      fill: Colors.black,
                    ),
                  ),
                ),
              ),

            // 3. Story's OWN poster thumbnail overlay — smoothly crossfades out once first frame is ready
            IgnorePointer(
              ignoring: hasFrame,
              child: RepaintBoundary(
                child: AnimatedOpacity(
                  opacity: hasFrame ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _buildVideoPlaceholder(story, thumb),
                ),
              ),
            ),

            // 4. Low internet / loading buffering Lottie animation — ONLY shown if genuine buffering occurs
            if (provider.isBuffering)
              const Center(child: VideoLoadingIndicator(size: 56)),
          ],
        ),
      );
    }

    // Default loading canvas
    return const Center(child: VideoLoadingIndicator(size: 56));
  }

  String _resolveStoryThumbnail(StoryContent story) {
    if (story.thumbnailUrl != null && story.thumbnailUrl!.trim().isNotEmpty) {
      return story.thumbnailUrl!.trim();
    }
    final cfThumb = MediaUrlResolver.extractThumbnailFromVideoUrl(story.url);
    if (cfThumb.isNotEmpty) return cfThumb;
    if (story.fallbackUrl != null) {
      final cfFallbackThumb = MediaUrlResolver.extractThumbnailFromVideoUrl(
        story.fallbackUrl!,
      );
      if (cfFallbackThumb.isNotEmpty) return cfFallbackThumb;
    }
    // Auto-derive thumbnail from Cloudflare Stream URL
    if (story.url.contains('cloudflarestream.com') &&
        story.url.contains('/manifest/video.m3u8')) {
      return story.url.replaceAll(
        '/manifest/video.m3u8',
        '/thumbnails/thumbnail.jpg?width=640',
      );
    }
    if (story.fallbackUrl != null &&
        story.fallbackUrl!.contains('cloudflarestream.com') &&
        story.fallbackUrl!.contains('/downloads/default.mp4')) {
      return story.fallbackUrl!.replaceAll(
        '/downloads/default.mp4',
        '/thumbnails/thumbnail.jpg?width=640',
      );
    }
    if (userProfile.isNotEmpty && userProfile.startsWith('http')) {
      return userProfile;
    }
    return '';
  }

  Widget _buildVideoPlaceholder(StoryContent story, String thumb) {
    final effectiveThumb = thumb.isNotEmpty
        ? thumb
        : (userProfile.isNotEmpty ? userProfile : '');

    if (effectiveThumb.isNotEmpty && effectiveThumb.startsWith('http')) {
      return Image.network(
        effectiveThumb,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
        frameBuilder: (context, child, frame, wasSync) {
          if (wasSync) return child;
          return AnimatedOpacity(
            opacity: frame != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: child,
          );
        },
        errorBuilder: (_, e, s) => Container(color: Colors.black),
      );
    }

    return Container(color: Colors.black);
  }

  Widget _buildAudioView(StoryDetailProvider provider) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle background category image
          if (userProfile.isNotEmpty && userProfile.startsWith('http'))
            Opacity(
              opacity: 0.12,
              child: Image.network(
                userProfile,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, e, s) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioCenterControl(StoryDetailProvider provider) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left Audio Waves (IgnorePointer: purely visual, non-clickable)
          IgnorePointer(
            child: StoryAudioWave(
              isPlaying: provider.isPlaying,
              isReversed: true,
            ),
          ),
          const SizedBox(width: 16),

          // ONLY THIS CIRCULAR ORANGE BUTTON IS CLICKABLE FOR PLAY/PAUSE
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: provider.togglePlayPause,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6900).withValues(alpha: 0.95),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6900).withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: provider.isLoading && !provider.isPlaying
                  ? const CoolShimmer(child: CoolShimmerBone.circle(size: 36))
                  : Icon(
                      provider.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // Right Audio Waves (IgnorePointer: purely visual, non-clickable)
          IgnorePointer(
            child: StoryAudioWave(
              isPlaying: provider.isPlaying,
              isReversed: false,
            ),
          ),
        ],
      ),
    );
  }

  // --- Top Progress Bars ---

  Widget _buildProgressBars(StoryDetailProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: List.generate(provider.stories.length, (index) {
          double fill = 0.0;
          if (index < provider.currentIndex) {
            fill = 1.0;
          } else if (index == provider.currentIndex) {
            fill = provider.progress.clamp(0.0, 1.0);
          }

          return Expanded(
            child: Container(
              height: 2.5,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fill,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- Top Header ---

  Widget _buildHeader(
    BuildContext context,
    StoryDetailProvider provider,
    StoryContent story,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[850],
            backgroundImage:
                userProfile.isNotEmpty && userProfile.startsWith('http')
                ? NetworkImage(userProfile)
                : null,
            child: userProfile.isEmpty
                ? const Icon(Icons.person, color: Colors.white70, size: 20)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (story.createdAt != null && story.createdAt!.isNotEmpty)
                  Text(
                    story.createdAt!,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: provider.toggleMute,
            icon: Icon(
              provider.isMuted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}
