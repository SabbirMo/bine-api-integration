import 'package:flutter/material.dart';

/// Represents a Category and its collection of stories
class StoryGroup {
  final int categoryId;
  final String categoryName;
  final String categoryImage;
  final List<StoryContent> stories;
  final bool isVideo;
  final bool isAudio;

  StoryGroup({
    required this.categoryId,
    required this.categoryName,
    required this.categoryImage,
    required this.stories,
    this.isVideo = false,
    this.isAudio = false,
  });
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
    this.isVideo = false,
    this.isAudio = false,
    this.isImage = false,
    this.isNetwork = false,
    this.createdAt,
  });
}

/// Facebook / Instagram Story 3D Cube Physics
/// Responsive, silky-smooth spring snap on swipe or flick!
class SnappyStoryScrollPhysics extends PageScrollPhysics {
  const SnappyStoryScrollPhysics({super.parent});

  @override
  SnappyStoryScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnappyStoryScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity => 50.0;

  @override
  double get dragStartDistanceMotionThreshold => 3.5;

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 0.45, stiffness: 280.0, damping: 24.0);

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final Tolerance tolerance = toleranceFor(position);
    final PageMetrics metrics = position as PageMetrics;
    final double page =
        metrics.page ?? (metrics.pixels / metrics.viewportDimension);

    final double basePage = page.floorToDouble();
    final double fraction = page - basePage;

    double targetPage = page.roundToDouble();

    // Sensitive swipe thresholds (15% drag or 50px/s flick):
    const double velocityThreshold = 50.0;
    const double dragThreshold = 0.15;

    if (velocity > velocityThreshold) {
      targetPage = basePage + 1.0;
    } else if (velocity < -velocityThreshold) {
      targetPage = basePage;
    } else {
      if (fraction >= dragThreshold) {
        targetPage = basePage + 1.0;
      } else {
        targetPage = basePage;
      }
    }

    final double maxPage = (metrics.maxScrollExtent / metrics.viewportDimension)
        .roundToDouble();
    targetPage = targetPage.clamp(0.0, maxPage);

    final double targetPixels = targetPage * metrics.viewportDimension;
    if (targetPixels != position.pixels) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        targetPixels,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }
}
