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

  final ApiServices apiServices = ApiServices();
  final AuthService _authService = AuthService();

  Future<bool> loginWithApple() async {
    try {
      isAppleLoading = true;
      notifyListeners();

      final appleAuthData = await _authService.signInWithApple();

      if (appleAuthData != null) {
        final firebaseIdToken = appleAuthData['firebaseIdToken'];

        final response = await apiServices.post(
          '/api/auth/auth/google/',
          data: {"id_token": firebaseIdToken},
          requireAuth: false,
        );

        log("Apple Login Response: $response");

        final data = response.data;

        // Fallback to apple profile data if backend doesn't return user info
        final name = data['user']?['name'] ?? appleAuthData['name'] ?? '';
        final userEmail =
            data['user']?['email'] ?? appleAuthData['email'] ?? '';
        final profileImage =
            data['user']?['profile_photo_url'] ??
            appleAuthData['photoUrl'] ??
            '';

        await TokenStorage.saveAccessToken(data['access']);
        await TokenStorage.saveRefreshToken(data['refresh']);
        await TokenStorage.saveName(name.toString());
        await TokenStorage.saveEmail(userEmail.toString());
        await TokenStorage.saveProfileImage(profileImage.toString());

        await FirebaseService.instance.registerCurrentToken();

        log("Apple Login Successful");
        return true;
      }

      return false;
    } catch (e) {
      log("Apple Login Failed $e");
      return false;
    } finally {
      isAppleLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithGoogle() async {
    try {
      isGoogleLoading = true;
      notifyListeners();

      final googleAuthData = await _authService.signInWithGoogle();

      if (googleAuthData != null) {
        final firebaseIdToken = googleAuthData['firebaseIdToken'];

        final response = await apiServices.post(
          '/api/auth/auth/google/',
          data: {"id_token": firebaseIdToken},
          requireAuth: false,
        );

        log("Google Login Response: $response");

        final data = response.data;

        // Fallback to google profile data if backend doesn't return user info
        final name = data['user']?['name'] ?? googleAuthData['name'] ?? '';
        final userEmail =
            data['user']?['email'] ?? googleAuthData['email'] ?? '';
        final profileImage =
            data['user']?['profile_photo_url'] ??
            googleAuthData['photoUrl'] ??
            '';

        await TokenStorage.saveAccessToken(data['access']);
        await TokenStorage.saveRefreshToken(data['refresh']);
        await TokenStorage.saveName(name.toString());
        await TokenStorage.saveEmail(userEmail.toString());
        await TokenStorage.saveProfileImage(profileImage.toString());

        await FirebaseService.instance.registerCurrentToken();

        log("Google Login Successful");
        return true;
      }

      return false;
    } catch (e) {
      log("Google Login Failed $e");
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

      await TokenStorage.saveAccessToken(data['access']);

      await TokenStorage.saveRefreshToken(data['refresh']);
      await TokenStorage.saveName(name.toString());
      await TokenStorage.saveEmail(userEmail.toString());
      await TokenStorage.saveProfileImage(profileImage.toString());

      await FirebaseService.instance.registerCurrentToken();

      log("Login Successfull $response");
    } catch (e) {
      log("Login Failed $e");
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
