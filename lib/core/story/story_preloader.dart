import 'package:flutter/widgets.dart';
import 'package:binetatour/core/story/story_hls_preloader.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';
import 'package:binetatour/presentation/home/widget/story/story_models.dart';

/// Preloader for Story video streams, audio files, and image posters.
/// Manages both HLS stream background warming and disk caching for zero-perceived-loading transitions.
class StoryPreloader {
  static void _precacheNetworkImage(String? url) {
    if (url == null || url.trim().isEmpty || !url.startsWith('http')) return;
    try {
      final imageProvider = NetworkImage(url.trim());
      imageProvider.resolve(ImageConfiguration.empty);
    } catch (_) {}
  }

  /// Preload all audio files, video MP4s, and image posters for the active category session
  static void preloadStories(List<StoryContent> stories, [BuildContext? context]) {
    for (final story in stories) {
      if (story.isAudio) {
        final target = (story.fallbackUrl != null &&
                story.fallbackUrl!.isNotEmpty &&
                story.fallbackUrl!.startsWith('http'))
            ? story.fallbackUrl!
            : story.url;
        if (target.isNotEmpty && target.startsWith('http')) {
          VideoCacheManager.instance.preCacheVideo(target);
        }
      } else if (story.isVideo) {
        if (story.fallbackUrl != null &&
            story.fallbackUrl!.isNotEmpty &&
            story.fallbackUrl!.startsWith('http')) {
          VideoCacheManager.instance.preCacheVideo(story.fallbackUrl!);
        }
      } else if (story.isImage) {
        _precacheNetworkImage(story.url);
      }

      // Pre-cache thumbnail images into Flutter RAM cache so transitions have 0ms poster frames
      if (story.thumbnailUrl != null) {
        _precacheNetworkImage(story.thumbnailUrl);
      }
    }
  }

  /// Preload next immediate story (N+1)
  static void preloadNextStory(StoryContent? nextStory, [BuildContext? context]) {
    if (nextStory == null) return;

    if (nextStory.isVideo) {
      // 1. Preload direct MP4 video file to disk for instant 0ms replay
      if (nextStory.fallbackUrl != null &&
          nextStory.fallbackUrl!.isNotEmpty &&
          nextStory.fallbackUrl!.startsWith('http')) {
        VideoCacheManager.instance.preCacheVideo(nextStory.fallbackUrl!);
      }

      // 2. Preload adaptive HLS stream manifest & buffers in background
      if (nextStory.url.isNotEmpty && nextStory.url.startsWith('http')) {
        StoryHlsPreloader.instance.preload(nextStory.url);
      }

      // 3. Precache thumbnail image directly into RAM for 0ms poster display
      _precacheNetworkImage(nextStory.thumbnailUrl);
    } else if (nextStory.isAudio) {
      final target = (nextStory.fallbackUrl != null &&
              nextStory.fallbackUrl!.isNotEmpty &&
              nextStory.fallbackUrl!.startsWith('http'))
          ? nextStory.fallbackUrl!
          : nextStory.url;
      if (target.isNotEmpty && target.startsWith('http')) {
        VideoCacheManager.instance.preCacheVideo(target);
      }
    } else if (nextStory.isImage) {
      _precacheNetworkImage(nextStory.url);
    }
  }

  /// Preload category N+1 first story and backdrop
  static void preloadCategoryFirstStory(StoryGroup? nextGroup, [BuildContext? context]) {
    if (nextGroup == null) return;

    // Precache category avatar/cover directly into RAM
    _precacheNetworkImage(nextGroup.categoryImage);

    if (nextGroup.stories.isNotEmpty) {
      preloadNextStory(nextGroup.stories.first, context);
    }
  }
}
