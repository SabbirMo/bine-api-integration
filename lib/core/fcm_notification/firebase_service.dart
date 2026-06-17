import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:binetatour/core/network/api_services/api_services.dart';

import 'notification_service.dart';

class FirebaseService {
  FirebaseService._();

  static final instance = FirebaseService._();

  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  final ApiServices apiServices = ApiServices();

  Future<void> init() async {
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final token = await messaging.getToken();

    if (token != null) {
      await _registerDeviceToken(token);
    }
    log("FCM TOKEN => $token");

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;

      if (notification != null) {
        NotificationService.instance.show(
          title: notification.title ?? '',
          body: notification.body ?? '',
        );
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
    final token = await messaging.getToken();

    if (token != null) {
      await _registerDeviceToken(token);
      log('FCM token registered after login');
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
