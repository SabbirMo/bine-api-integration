import 'package:flutter/cupertino.dart';

/// Ultra-smooth, hardware-accelerated Cupertino page route for Reels & Video Players.
/// Eliminates route transition GPU contention, black/white frame flashes, and stutter.
class CupertinoReelsRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  CupertinoReelsRoute({required this.page})
      : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          opaque: true,
          barrierColor: CupertinoColors.black,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            // iOS-style easeOutCubic curve for buttery smooth entry
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            // Clean hardware-accelerated fade without route scaling so Hero coordinates align with pixel perfection
            return FadeTransition(
              opacity: curvedAnimation,
              child: child,
            );
          },
        );
}
