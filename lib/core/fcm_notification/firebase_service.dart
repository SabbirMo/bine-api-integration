import 'dart:developer';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/core/token_storage/token_storage.dart';

import 'notification_service.dart';

class FirebaseService {
  FirebaseService._();

  static final instance = FirebaseService._();

  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  final ApiServices apiServices = ApiServices();

  Function()? onNotificationReceived;

  Future<void> init() async {
    // Allow iOS to show notification banners in the foreground
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // If user is already logged in, refresh and register FCM token silently in background
    Future.delayed(const Duration(seconds: 3), () async {
      final token = await TokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        await registerCurrentToken();
      }
    });

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
      // Prompt user for Notification Permission after successful login on Android and iOS
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      log(
        'FCM Notification permission status: ${settings.authorizationStatus}',
      );

      await NotificationService.instance.requestPermissions();

      final token = await messaging.getToken();
      if (token != null) {
        await _registerDeviceToken(token);
        log('FCM token registered after login => $token');
      }
    } catch (e) {
      log(
        'FCM registerCurrentToken failed (SERVICE_NOT_AVAILABLE or no Play Services): $e',
      );
    }
  }

  Future<void> _registerDeviceToken(String token) async {
    try {
      debugPrint('==================================================');
      debugPrint('🚀 SENDING FCM TOKEN TO BACKEND:');
      debugPrint('TOKEN => $token');
      debugPrint('ENDPOINT => /api/notifications/devices/');
      debugPrint('==================================================');
      log('FCM TOKEN => $token');

      final response = await apiServices.post(
        '/api/notifications/devices/',
        data: {'registration_token': token},
        requireAuth: true,
      );

      debugPrint('==================================================');
      debugPrint('✅ FCM TOKEN REGISTERED SUCCESSFULLY ON BACKEND!');
      debugPrint('RESPONSE => ${response.data}');
      debugPrint('==================================================');
      log('FCM Token registered successfully: ${response.data}');
    } catch (e) {
      debugPrint('==================================================');
      debugPrint('❌ FAILED TO REGISTER FCM TOKEN ON BACKEND: $e');
      debugPrint('==================================================');
      log('Failed to register FCM token: $e');
    }
  }
}
