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
    _init();
  }

  Future<void> _init() async {
    await _loadFromCache();
    fetchHomeData();
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

  Future<void>? _inFlightFetch;

  Future<void> fetchHomeData({bool forceLoading = false, int page = 1}) async {
    if (_inFlightFetch != null) {
      return _inFlightFetch!;
    }
    _inFlightFetch = _executeFetchHomeData(
      forceLoading: forceLoading,
      page: page,
    );
    try {
      await _inFlightFetch;
    } finally {
      _inFlightFetch = null;
    }
  }

  Future<void> _executeFetchHomeData({
    bool forceLoading = false,
    int page = 1,
  }) async {
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
        queryParameters: page > 1 ? {'page': page} : null,
        requireAuth: false,
      );

      final dynamic data = response.data;

      // Extract JSON map handling DRF pagination or raw format
      Map<String, dynamic> jsonMap = {};
      if (data is Map) {
        final mapData = Map<String, dynamic>.from(data);
        if (mapData.containsKey('banner') ||
            mapData.containsKey('story_categories')) {
          jsonMap = mapData;
        } else if (mapData['results'] is List &&
            (mapData['results'] as List).isNotEmpty) {
          final first = (mapData['results'] as List).first;
          if (first is Map) {
            jsonMap = Map<String, dynamic>.from(first);
          }
        } else if (mapData['data'] is Map) {
          final dataMap = Map<String, dynamic>.from(mapData['data'] as Map);
          if (dataMap['results'] is List &&
              (dataMap['results'] as List).isNotEmpty) {
            final first = (dataMap['results'] as List).first;
            jsonMap = first is Map ? Map<String, dynamic>.from(first) : dataMap;
          } else {
            jsonMap = dataMap;
          }
        } else {
          jsonMap = mapData;
        }
      }

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
