import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/home_response_model.dart';

class HomeProvider extends ChangeNotifier {
  static const String _cachedHomeKey = 'cached_home_data';
  final ApiServices _apiServices = ApiServices();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  HomeResponseModel? _homeData;
  HomeResponseModel? get homeData => _homeData;

  HomeProvider() {
    _loadFromCache();
  }

  /// Instant load from disk cache (0ms startup delay)
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_cachedHomeKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final dynamic data = json.decode(cachedStr);
        if (data is Map<String, dynamic>) {
          _homeData = HomeResponseModel.fromJson(data);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading cached home data: $e');
    }
  }

  Future<void> fetchHomeData({bool forceLoading = false}) async {
    // Only show full-screen blocking spinner if we have NO cached data at all
    if (_homeData == null || forceLoading) {
      _isLoading = true;
      notifyListeners();
    }
    _errorMessage = null;

    try {
      // Home API doesn't require strict auth to view banners and products
      final response = await _apiServices.get(
        '/api/mobile/home/',
        requireAuth: false,
      );

      final dynamic data = response.data;

      // Extract JSON map
      final Map<String, dynamic> jsonMap =
          data is Map<String, dynamic> && data.containsKey('banner')
              ? data
              : (data is Map<String, dynamic> ? (data['data'] ?? {}) : {});

      _homeData = HomeResponseModel.fromJson(jsonMap);

      // Save fresh data to local cache asynchronously
      _saveToCache(jsonMap);
    } catch (e) {
      // If we already have cached data displayed, don't break the UI with error screen
      if (_homeData == null) {
        _errorMessage = e.toString();
      } else {
        debugPrint('Failed to refresh home data in background: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveToCache(Map<String, dynamic> jsonMap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedHomeKey, json.encode(jsonMap));
    } catch (e) {
      debugPrint('Error saving home data to cache: $e');
    }
  }
}
