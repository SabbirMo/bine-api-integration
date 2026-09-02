import 'package:flutter/material.dart';

/// Buttery-smooth, weighted Reels/Shorts scrolling physics.
/// Tuned for 60Hz and 120Hz ProMotion displays.
///
/// Compared to YouTube Shorts / TikTok:
/// - Critically damped spring (zero overshoot, zero tail-crawl)
/// - Symmetric forward/backward drag thresholds
/// - Realistic flick velocity (prevents micro-jitter accidental page turns)
/// - Comfortable touch slop (prevents hijacking taps and nested horizontal swipes)
class SmoothReelsScrollPhysics extends PageScrollPhysics {
  const SmoothReelsScrollPhysics({super.parent});

  @override
  SmoothReelsScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothReelsScrollPhysics(parent: buildParent(ancestor));
  }

  // Realistic flick threshold (prevents micro-jitter accidental page turns)
  @override
  double get minFlingVelocity => 350.0;

  // Touch slop (prevents hijacking taps/double-taps and nested horizontal swipes)
  @override
  double get dragStartDistanceMotionThreshold => 14.0;

  // Critically damped (zeta = 1.0) with organic mass inertia
  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 0.85,
    stiffness: 180.0,
    ratio: 1.0, // Critical damping: zero overshoot, zero tail-crawl
  );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    // Type guard: avoid crash if attached to non-PageScrollPosition
    if (position is! PageMetrics) {
      return super.createBallisticSimulation(position, velocity);
    }

    final Tolerance tolerance = toleranceFor(position);
    final PageMetrics metrics = position;
    final double page =
        metrics.page ?? (metrics.pixels / metrics.viewportDimension);

    final double basePage = page.floorToDouble();
    final double fraction = page - basePage;

    double targetPage;

    // 1. High velocity flick takes priority (symmetric for both directions)
    if (velocity.abs() >= minFlingVelocity) {
      targetPage = velocity > 0 ? basePage + 1.0 : basePage;
    } else {
      // 2. Slow drag: Symmetric 50% threshold from current page boundary
      //    This fixes the critical asymmetry bug where swiping backward
      //    previously required 85% drag distance vs 15% for forward.
      if (fraction >= 0.5) {
        targetPage = basePage + 1.0;
      } else {
        targetPage = basePage;
      }
    }

    final double maxPage =
        (metrics.maxScrollExtent / metrics.viewportDimension).roundToDouble();
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
