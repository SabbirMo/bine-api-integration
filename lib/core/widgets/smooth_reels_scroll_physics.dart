import 'package:flutter/material.dart';

/// Ultra-responsive, smooth Reels/TikTok vertical scrolling physics:
/// - Low drag threshold (starts moving on just 3.5px drag)
/// - Ultra-sensitive flick velocity (50.0 px/s instead of 500 px/s)
/// - Low 15% swipe threshold to glide to next video effortlessly
/// - Snappy, buttery smooth spring simulation
class SmoothReelsScrollPhysics extends PageScrollPhysics {
  const SmoothReelsScrollPhysics({super.parent});

  @override
  SmoothReelsScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothReelsScrollPhysics(parent: buildParent(ancestor));
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

    // Reels swipe thresholds (only 15% drag or 50px/s flick needed!)
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
