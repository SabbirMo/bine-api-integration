import 'dart:developer';

import 'package:binetatour/auth/auth_service.dart';
import 'package:binetatour/core/fcm_notification/firebase_service.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/core/token_storage/token_storage.dart';
import 'package:flutter/foundation.dart';

class LoginProvider extends ChangeNotifier {
  bool isLoading = false;
  bool isGoogleLoading = false;
  bool isAppleLoading = false;
  String? errorMessage;

  final ApiServices apiServices = ApiServices();
  final AuthService _authService = AuthService();

  Future<bool> loginWithApple() async {
    final stopwatch = Stopwatch()..start();
    try {
      isAppleLoading = true;
      errorMessage = null;
      notifyListeners();

      final appleAuthData = await _authService.signInWithApple();

      if (appleAuthData != null) {
        final firebaseIdToken = appleAuthData['firebaseIdToken'];

        final apiStart = stopwatch.elapsedMilliseconds;
        final response = await apiServices.post(
          '/api/auth/auth/google/',
          data: {"id_token": firebaseIdToken},
          requireAuth: false,
        );
        final apiEnd = stopwatch.elapsedMilliseconds;
        log(
          "Apple login backend API returned in ${apiEnd - apiStart}ms: $response",
        );

        final data = response.data;

        // Fallback to apple profile data if backend doesn't return user info
        final name = data['user']?['name'] ?? appleAuthData['name'] ?? '';
        final userEmail =
            data['user']?['email'] ?? appleAuthData['email'] ?? '';
        final profileImage =
            data['user']?['profile_photo_url'] ??
            appleAuthData['photoUrl'] ??
            '';
        final userId = data['user']?['id']?.toString() ?? '';

        await TokenStorage.saveUserSession(
          accessToken: data['access']?.toString() ?? '',
          refreshToken: data['refresh']?.toString() ?? '',
          name: name.toString(),
          email: userEmail.toString(),
          profileImage: profileImage.toString(),
          userId: userId.isNotEmpty ? userId : null,
        );

        FirebaseService.instance.registerCurrentToken();

        log(
          "Apple Login Successful (total: ${stopwatch.elapsedMilliseconds}ms)",
        );
        return true;
      }

      // User cancelled sign in
      errorMessage = null;
      return false;
    } catch (e, stack) {
      log("Apple Login Failed after ${stopwatch.elapsedMilliseconds}ms: $e");
      debugPrint("Stacktrace: $stack");
      errorMessage = "Connexion Apple échouée: ${e.toString()}";
      return false;
    } finally {
      isAppleLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithGoogle() async {
    final stopwatch = Stopwatch()..start();
    try {
      isGoogleLoading = true;
      errorMessage = null;
      notifyListeners();

      final googleAuthData = await _authService.signInWithGoogle();

      if (googleAuthData != null) {
        final tokenToSend =
            googleAuthData['firebaseIdToken'] ?? googleAuthData['idToken'];

        final apiStart = stopwatch.elapsedMilliseconds;
        final response = await apiServices.post(
          '/api/auth/auth/google/',
          data: {"id_token": tokenToSend},
          requireAuth: false,
        );
        final apiEnd = stopwatch.elapsedMilliseconds;
        debugPrint(
          "Google login backend API returned in ${apiEnd - apiStart}ms: $response",
        );

        final data = response.data;

        // Fallback to google profile data if backend doesn't return user info
        final name = data['user']?['name'] ?? googleAuthData['name'] ?? '';
        final userEmail =
            data['user']?['email'] ?? googleAuthData['email'] ?? '';
        final profileImage =
            data['user']?['profile_photo_url'] ??
            googleAuthData['photoUrl'] ??
            '';
        final userId = data['user']?['id']?.toString() ?? '';

        final storageStart = stopwatch.elapsedMilliseconds;
        await TokenStorage.saveUserSession(
          accessToken: data['access']?.toString() ?? '',
          refreshToken: data['refresh']?.toString() ?? '',
          name: name.toString(),
          email: userEmail.toString(),
          profileImage: profileImage.toString(),
          userId: userId.isNotEmpty ? userId : null,
        );
        final storageEnd = stopwatch.elapsedMilliseconds;
        debugPrint("Session tokens saved in ${storageEnd - storageStart}ms");

        // Register token in the background so it doesn't block the login flow
        FirebaseService.instance.registerCurrentToken();

        debugPrint(
          "Google Login Successful (total: ${stopwatch.elapsedMilliseconds}ms)",
        );
        return true;
      }

      // User cancelled Google sign-in prompt
      errorMessage = null;
      return false;
    } catch (e, stack) {
      debugPrint(
        "Google Login Failed after ${stopwatch.elapsedMilliseconds}ms: $e",
      );
      debugPrint("Stacktrace: $stack");
      errorMessage = "Connexion Google échouée: ${e.toString()}";
      return false;
    } finally {
      isGoogleLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading = true;
      notifyListeners();

      final response = await apiServices.post(
        '/api/mobile/auth/login/',
        data: {"email": email, "password": password},
        requireAuth: false,
      );

      final data = response.data;

      final name = data['user']['name'];
      final userEmail = data['user']['email'];
      final profileImage = data['user']['profile_photo_url'];
      final userId = data['user']['id'];

      await TokenStorage.saveUserSession(
        accessToken: data['access']?.toString() ?? '',
        refreshToken: data['refresh']?.toString() ?? '',
        name: name?.toString() ?? '',
        email: userEmail?.toString() ?? '',
        profileImage: profileImage?.toString() ?? '',
        userId: userId?.toString(),
      );

      // Register token in the background so it doesn't block the login flow
      FirebaseService.instance.registerCurrentToken();

      log("Login Successful $response");
    } catch (e) {
      log("Login Failed $e");
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAccount() async {
    try {
      isLoading = true;
      notifyListeners();

      final userId = await TokenStorage.getUserId();
      if (userId == null || userId.isEmpty) {
        log("Delete account failed: userId is null or empty");
        return false;
      }

      final response = await apiServices.delete(
        '/api/users/$userId/',
        requireAuth: true,
      );

      log("Delete account success response: $response");
      return true;
    } catch (e) {
      log("Delete account API failed: $e");
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
