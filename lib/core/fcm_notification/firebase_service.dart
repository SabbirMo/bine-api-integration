import 'dart:developer';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:binetatour/core/network/api_services/api_services.dart';

import 'notification_service.dart';

class FirebaseService {
  FirebaseService._();

  static final instance = FirebaseService._();

  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  final ApiServices apiServices = ApiServices();

  Function()? onNotificationReceived;

  Future<void> init() async {
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Allow iOS to show notification banners in the foreground
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    String? token;
    try {
      token = await messaging.getToken();
      if (token != null) {
        await _registerDeviceToken(token);
      }
      log("FCM TOKEN => $token");
    } catch (e) {
      log(
        "FCM getToken failed (SERVICE_NOT_AVAILABLE or no Play Services): $e",
      );
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;

      if (notification != null) {
        // iOS will show the default system banner automatically because we set setForegroundNotificationPresentationOptions.
        // So we only need to trigger a local notification banner on Android to avoid duplicate banners on iOS.
        if (!Platform.isIOS) {
          NotificationService.instance.show(
            title: notification.title ?? '',
            body: notification.body ?? '',
          );
        }
        onNotificationReceived?.call();
      } else {
        // Fallback for data-only notifications where title/body might be sent in the 'data' payload
        final title =
            message.data['title'] ??
            message.data['notification_title'] ??
            message.data['header'];
        final body =
            message.data['body'] ??
            message.data['notification_body'] ??
            message.data['message'] ??
            message.data['content'];
        if (title != null || body != null) {
          log("FCM onMessage: Presenting local notification from data payload");
          NotificationService.instance.show(
            title: title.toString(),
            body: body.toString(),
          );
          onNotificationReceived?.call();
        } else {
          log(
            "FCM onMessage: No notification or data-only title/body fields found to display.",
          );
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log("Notification Clicked");

      log(message.data.toString());
    });

    final initialMessage = await messaging.getInitialMessage();

    if (initialMessage != null) {
      log("Opened From Terminated State");

      log(initialMessage.data.toString());
    }
  }

  Future<void> registerCurrentToken() async {
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await _registerDeviceToken(token);
        log('FCM token registered after login');
      }
    } catch (e) {
      log(
        'FCM registerCurrentToken failed (SERVICE_NOT_AVAILABLE or no Play Services): $e',
      );
    }
  }

  Future<void> _registerDeviceToken(String token) async {
    try {
      await apiServices.post(
        '/api/notifications/devices/',
        data: {'registration_token': token},
        requireAuth: true,
      );
      log('FCM Token registered successfully');
    } catch (e) {
      log('Failed to register FCM token: $e');
    }
  }
}
