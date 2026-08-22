import 'package:binetatour/core/video/video_route_observer.dart';
import 'package:go_router/go_router.dart';
import '../presentation/authentication/splash_screen.dart';

final GoRouter router = GoRouter(
  observers: [
    VideoRouteObserver.instance,
  ],
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => SplashScreen(),
    ),
  ],
);