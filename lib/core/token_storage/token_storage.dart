import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _accessTokenKey = 'access';
  static const String _refreshTokenKey = 'refresh';
  static const String _nameKey = 'name';
  static const String _emailKey = 'email';
  static const String _profileImageKey = 'profile_photo_url';

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

  // Clear all tokens (for logout)
  static Future<bool> clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      return true;
    } catch (e) {
      return false;
    }
  }
}
