import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:binetatour/core/video/feed_video_manager.dart';

class VideoRouteObserver extends NavigatorObserver {
  static final VideoRouteObserver instance = VideoRouteObserver._();
  VideoRouteObserver._();

  int _routeDepth = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute != null) {
      _routeDepth++;
      // A new screen/dialog/bottomSheet was pushed on top! Pause background feed videos
      FeedVideoManager.instance.pauseAll();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      if (_routeDepth > 0) _routeDepth--;
      // Returned back to the previous screen!
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (FeedVideoManager.instance.activeTabIndex != 2) {
          FeedVideoManager.instance.resume();
          VisibilityDetectorController.instance.notifyNow();
        }
      });
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (previousRoute != null) {
      if (_routeDepth > 0) _routeDepth--;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (FeedVideoManager.instance.activeTabIndex != 2) {
          FeedVideoManager.instance.resume();
          VisibilityDetectorController.instance.notifyNow();
        }
      });
    }
  }
}
