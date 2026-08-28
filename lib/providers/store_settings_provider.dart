import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/store_settings_model.dart';

class StoreSettingsProvider extends ChangeNotifier {
  static const String _cachedStoreSettingsKey = 'cached_store_settings_data';
  final ApiServices _apiServices = ApiServices();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  StoreSettingsModel? _storeSettings;
  StoreSettingsModel? get storeSettings => _storeSettings;

  StoreSettingsProvider() {
    _loadFromCache();
  }

  /// Instant load from disk cache (0ms delay)
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_cachedStoreSettingsKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final dynamic data = json.decode(cachedStr);
        if (data is Map<String, dynamic>) {
          _storeSettings = StoreSettingsModel.fromJson(data);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading cached store settings: $e');
    }
  }

  Future<void> fetchStoreSettings({bool forceLoading = false}) async {
    if (_storeSettings == null || forceLoading) {
      _isLoading = true;
      notifyListeners();
    }
    _errorMessage = null;

    try {
      final response = await _apiServices.get(
        '/api/store-settings/',
        requireAuth: false,
      );

      final dynamic data = response.data;

      if (data is Map<String, dynamic>) {
        if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
          _storeSettings = StoreSettingsModel.fromJson(data['data']);
          _saveToCache(data['data']);
        } else {
          _storeSettings = StoreSettingsModel.fromJson(data);
          _saveToCache(data);
        }
      } else if (data is List &&
          data.isNotEmpty &&
          data.first is Map<String, dynamic>) {
        _storeSettings = StoreSettingsModel.fromJson(data.first);
        _saveToCache(data.first);
      }
    } catch (e) {
      if (_storeSettings == null) {
        _errorMessage = e.toString();
      } else {
        debugPrint('Failed to refresh store settings in background: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveToCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedStoreSettingsKey, json.encode(data));
    } catch (e) {
      debugPrint('Error saving store settings to cache: $e');
    }
  }
}
