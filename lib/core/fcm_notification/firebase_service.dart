import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_service.dart';

class FirebaseService {
  FirebaseService._();

  static final instance = FirebaseService._();

  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final token = await messaging.getToken();

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
}
