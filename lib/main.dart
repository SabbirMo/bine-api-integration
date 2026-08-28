import 'package:binetatour/core/fcm_notification/notification_service.dart';
import 'package:binetatour/core/fcm_notification/firebase_service.dart';
import 'package:binetatour/core/login/login_provider.dart';
import 'package:binetatour/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart';
import 'routing/app_routing.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/home_provider.dart';
import 'providers/category_provider.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/feedback_provider.dart';
import 'providers/story_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/store_settings_provider.dart';

import 'package:binetatour/core/video/video_cache_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  VisibilityDetectorController.instance.updateInterval =
      const Duration(milliseconds: 200);

  // Pre-initialize and warm up disk video cache for 0ms cold-start playback
  await VideoCacheManager.instance.init();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  NotificationService.instance.init();

  FirebaseService.instance.init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => LoginProvider()),
        ChangeNotifierProvider(create: (_) => FeedbackProvider()),
        ChangeNotifierProvider(create: (_) => StoryProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => StoreSettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bawane',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('fr', 'FR'), // French
        Locale('en', 'US'), // English
      ],
      locale: Locale('fr', 'FR'),
      routerConfig: router,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xffFF8A00)),
        appBarTheme: AppBarTheme(scrolledUnderElevation: 0, elevation: 0),
      ),
    );
  }
}
