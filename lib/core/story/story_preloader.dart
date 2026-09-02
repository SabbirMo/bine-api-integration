import 'package:flutter/widgets.dart';
import 'package:binetatour/core/story/story_hls_preloader.dart';
import 'package:binetatour/core/utils/media_url_resolver.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';
import 'package:binetatour/presentation/home/widget/story/story_models.dart';

/// Preloader for Story video streams, audio files, and image posters.
/// Manages priority disk caching and background warming for zero-perceived-loading transitions.
class StoryPreloader {
  static void _precacheNetworkImage(String? url, [BuildContext? context]) {
    if (url == null || url.trim().isEmpty || !url.startsWith('http')) return;
    try {
      final imageProvider = NetworkImage(url.trim());
      if (context != null) {
        precacheImage(imageProvider, context).catchError((_) {});
      } else {
        imageProvider.resolve(ImageConfiguration.empty);
      }
    } catch (_) {}
  }

  /// Preload all audio files, video MP4s, and image posters for the active category session
  static void preloadStories(
    List<StoryContent> stories, [
    BuildContext? context,
  ]) {
    final List<String> priorityVideos = [];

    for (final story in stories) {
      if (story.isAudio) {
        final target =
            (story.fallbackUrl != null &&
                story.fallbackUrl!.isNotEmpty &&
                story.fallbackUrl!.startsWith('http'))
            ? story.fallbackUrl!
            : story.url;
        if (target.isNotEmpty && target.startsWith('http')) {
          final resolved = MediaUrlResolver.resolveUrl(target);
          if (resolved.isNotEmpty && !priorityVideos.contains(resolved)) {
            priorityVideos.add(resolved);
          }
        }
      } else if (story.isVideo) {
        if (story.fallbackUrl != null &&
            story.fallbackUrl!.isNotEmpty &&
            story.fallbackUrl!.startsWith('http')) {
          final resolved = MediaUrlResolver.resolveUrl(story.fallbackUrl!);
          if (resolved.isNotEmpty && !priorityVideos.contains(resolved)) {
            priorityVideos.add(resolved);
          }
        }
        if (story.url.isNotEmpty && story.url.startsWith('http')) {
          final resolved = MediaUrlResolver.resolveUrl(story.url);
          if (resolved.isNotEmpty && !priorityVideos.contains(resolved)) {
            priorityVideos.add(resolved);
          }
        }
      } else if (story.isImage) {
        _precacheNetworkImage(story.url, context);
      }

      // Pre-cache thumbnail images into Flutter RAM cache so transitions have 0ms poster frames
      if (story.thumbnailUrl != null) {
        _precacheNetworkImage(story.thumbnailUrl, context);
      }
    }

    if (priorityVideos.isNotEmpty) {
      VideoCacheManager.instance.preCachePriorityUrls(priorityVideos);
    }
  }

  /// Preload next immediate story (N+1) with priority
  static void preloadNextStory(
    StoryContent? nextStory, [
    BuildContext? context,
  ]) {
    if (nextStory == null) return;

    if (nextStory.isVideo) {
      final List<String> priority = [];
      if (nextStory.fallbackUrl != null &&
          nextStory.fallbackUrl!.isNotEmpty &&
          nextStory.fallbackUrl!.startsWith('http')) {
        priority.add(MediaUrlResolver.resolveUrl(nextStory.fallbackUrl!));
      }
      if (nextStory.url.isNotEmpty && nextStory.url.startsWith('http')) {
        priority.add(MediaUrlResolver.resolveUrl(nextStory.url));
        StoryHlsPreloader.instance.preload(nextStory.url);
      }

      if (priority.isNotEmpty) {
        VideoCacheManager.instance.preCachePriorityUrls(priority);
      }

      _precacheNetworkImage(nextStory.thumbnailUrl, context);
    } else if (nextStory.isAudio) {
      final target =
          (nextStory.fallbackUrl != null &&
              nextStory.fallbackUrl!.isNotEmpty &&
              nextStory.fallbackUrl!.startsWith('http'))
          ? nextStory.fallbackUrl!
          : nextStory.url;
      if (target.isNotEmpty && target.startsWith('http')) {
        VideoCacheManager.instance.preCachePriorityUrls([
          MediaUrlResolver.resolveUrl(target),
        ]);
      }
    } else if (nextStory.isImage) {
      _precacheNetworkImage(nextStory.url, context);
    }
  }

  /// Preload category N+1 first story and backdrop
  static void preloadCategoryFirstStory(
    StoryGroup? nextGroup, [
    BuildContext? context,
  ]) {
    if (nextGroup == null) return;

    // Precache category avatar/cover directly into RAM
    _precacheNetworkImage(nextGroup.categoryImage, context);

    if (nextGroup.stories.isNotEmpty) {
      preloadNextStory(nextGroup.stories.first, context);
    }
  }

  /// Deep intelligent preloader for Story playback:
  /// - Immediate Next Story (N+1): Top priority video MP4 download + poster + HLS prewarm
  /// - Immediate Previous Story (N-1): High priority video MP4 download + poster
  /// - Second Next Story (N+2): Background pre-caching
  /// - Current Story: Ensure local disk download completes for instant re-play
  /// - Next Category (C+1): Category cover + first & second stories pre-cached
  /// - Previous Category (C-1): Category cover + last story pre-cached
  static void preloadAround({
    required List<StoryContent> stories,
    required int currentIndex,
    List<StoryGroup>? allGroups,
    int categoryIndex = 0,
    BuildContext? context,
  }) {
    final List<String> priorityVideos = [];

    void addStoryCandidate(StoryContent? s, {bool isImmediateNext = false}) {
      if (s == null) return;
      if (s.isVideo) {
        if (s.fallbackUrl != null && s.fallbackUrl!.isNotEmpty) {
          final res = MediaUrlResolver.resolveUrl(s.fallbackUrl!);
          if (res.isNotEmpty && !priorityVideos.contains(res)) {
            priorityVideos.add(res);
          }
        }
        if (s.url.isNotEmpty) {
          final res = MediaUrlResolver.resolveUrl(s.url);
          if (res.isNotEmpty && !priorityVideos.contains(res)) {
            priorityVideos.add(res);
          }
          if (isImmediateNext) {
            StoryHlsPreloader.instance.preload(s.url);
          }
        }
      } else if (s.isAudio) {
        final target = (s.fallbackUrl != null && s.fallbackUrl!.isNotEmpty)
            ? s.fallbackUrl!
            : s.url;
        if (target.isNotEmpty) {
          final res = MediaUrlResolver.resolveUrl(target);
          if (res.isNotEmpty && !priorityVideos.contains(res)) {
            priorityVideos.add(res);
          }
        }
      }

      if (s.thumbnailUrl != null) {
        _precacheNetworkImage(s.thumbnailUrl, context);
      }
      if (s.isImage) {
        _precacheNetworkImage(s.url, context);
      }
    }

    // 1. Next Story (N+1) - Top Priority
    if (currentIndex + 1 < stories.length) {
      addStoryCandidate(stories[currentIndex + 1], isImmediateNext: true);
    }

    // 2. Previous Story (N-1)
    if (currentIndex - 1 >= 0) {
      addStoryCandidate(stories[currentIndex - 1]);
    }

    // 3. Second Next Story (N+2)
    if (currentIndex + 2 < stories.length) {
      addStoryCandidate(stories[currentIndex + 2]);
    }

    // 4. Current Story
    if (currentIndex >= 0 && currentIndex < stories.length) {
      addStoryCandidate(stories[currentIndex]);
    }

    // 5. Next Category (C+1)
    if (allGroups != null && categoryIndex + 1 < allGroups.length) {
      final nextGroup = allGroups[categoryIndex + 1];
      _precacheNetworkImage(nextGroup.categoryImage, context);
      if (nextGroup.stories.isNotEmpty) {
        addStoryCandidate(
          nextGroup.stories.first,
          isImmediateNext: currentIndex >= stories.length - 1,
        );
        if (nextGroup.stories.length > 1) {
          addStoryCandidate(nextGroup.stories[1]);
        }
      }
    }

    // 6. Previous Category (C-1)
    if (allGroups != null && categoryIndex - 1 >= 0) {
      final prevGroup = allGroups[categoryIndex - 1];
      _precacheNetworkImage(prevGroup.categoryImage, context);
      if (prevGroup.stories.isNotEmpty) {
        addStoryCandidate(prevGroup.stories.last);
      }
    }

    // Enqueue prioritized URLs to VideoCacheManager
    if (priorityVideos.isNotEmpty) {
      VideoCacheManager.instance.preCachePriorityUrls(priorityVideos);
    }
  }
}
