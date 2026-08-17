import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _accessTokenKey = 'access';
  static const String _refreshTokenKey = 'refresh';
  static const String _nameKey = 'name';
  static const String _emailKey = 'email';
  static const String _profileImageKey = 'profile_photo_url';
  static const String _userIdKey = 'user_id';

  // Batch save user session in parallel with a single SharedPreferences instance
  static Future<bool> saveUserSession({
    required String accessToken,
    required String refreshToken,
    required String name,
    required String email,
    required String profileImage,
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_accessTokenKey, accessToken),
        prefs.setString(_refreshTokenKey, refreshToken),
        prefs.setString(_nameKey, name),
        prefs.setString(_emailKey, email),
        prefs.setString(_profileImageKey, profileImage),
        if (userId != null && userId.isNotEmpty)
          prefs.setString(_userIdKey, userId),
      ]);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Save access token
  static Future<bool> saveAccessToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_accessTokenKey, token);
    } catch (e) {
      return false;
    }
  }

  // Save refresh token
  static Future<bool> saveRefreshToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_refreshTokenKey, token);
    } catch (e) {
      return false;
    }
  }

  //Save name
  static Future<bool> saveName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_nameKey, name);
    } catch (e) {
      return false;
    }
  }

  //Save email
  static Future<bool> saveEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_emailKey, email);
    } catch (e) {
      return false;
    }
  }

  //Save profile image
  static Future<bool> saveProfileImage(String profileImage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_profileImageKey, profileImage);
    } catch (e) {
      return false;
    }
  }

  // Save User ID
  static Future<bool> saveUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_userIdKey, userId);
    } catch (e) {
      return false;
    }
  }

  //Get name
  static Future<String?> getName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_nameKey);
    } catch (e) {
      return null;
    }
  }

  //Get email
  static Future<String?> getEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_emailKey);
    } catch (e) {
      return null;
    }
  }

  //Get profile image
  static Future<String?> getProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_profileImageKey);
    } catch (e) {
      return null;
    }
  }

  // Get User ID (with JWT decode fallback)
  static Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_userIdKey);
      if (id != null && id.isNotEmpty) {
        return id;
      }

      // Fallback: Try to extract user ID from stored access token
      final accessToken = await getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        final userIdFromJwt = _getUserIdFromJwt(accessToken);
        if (userIdFromJwt != null) {
          // Cache it for subsequent calls
          await prefs.setString(_userIdKey, userIdFromJwt);
          return userIdFromJwt;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // JWT Helper to decode user_id from access token payload
  static String? _getUserIdFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final decodedBytes = base64Url.decode(base64Url.normalize(payload));
      final decodedString = utf8.decode(decodedBytes);
      final map = json.decode(decodedString) as Map<String, dynamic>;
      final userId = map['user_id'] ?? map['sub'] ?? map['id'];
      return userId?.toString();
    } catch (e) {
      return null;
    }
  }

  // Get access token
  static Future<String?> getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_accessTokenKey);
    } catch (e) {
      return null;
    }
  }

  // Get refresh token
  static Future<String?> getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_refreshTokenKey);
    } catch (e) {
      return null;
    }
  }

  // Clear all session tokens & profile data (for logout)
  static Future<bool> clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_accessTokenKey),
        prefs.remove(_refreshTokenKey),
        prefs.remove(_userIdKey),
        prefs.remove(_nameKey),
        prefs.remove(_emailKey),
        prefs.remove(_profileImageKey),
      ]);
      return true;
    } catch (e) {
      return false;
    }
  }
}
