import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/category_model.dart';

class CategoryProvider extends ChangeNotifier {
  static const String _cachedCategoriesKey = 'cached_categories_data';
  final ApiServices _apiServices = ApiServices();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => _categories;

  CategoryProvider() {
    _loadFromCache();
  }

  /// Instant load from disk cache (0ms delay)
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_cachedCategoriesKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final dynamic data = json.decode(cachedStr);
        if (data is List) {
          _categories = data
              .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading cached categories: $e');
    }
  }

  Future<void> fetchCategories({bool forceLoading = false}) async {
    if (_categories.isEmpty || forceLoading) {
      _isLoading = true;
      notifyListeners();
    }
    _errorMessage = null;

    try {
      final response = await _apiServices.get(
        '/api/mobile/categories/',
        requireAuth: false,
      );

      final dynamic data = response.data;

      if (data is List) {
        _categories = data
            .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _saveToCache(data);
      } else if (data is Map<String, dynamic> && data.containsKey('data')) {
        final list = data['data'] as List;
        _categories = list
            .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _saveToCache(list);
      } else {
        _categories = [];
      }
    } catch (e) {
      if (_categories.isEmpty) {
        _errorMessage = e.toString();
      } else {
        debugPrint('Failed to refresh categories in background: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveToCache(dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedCategoriesKey, json.encode(data));
    } catch (e) {
      debugPrint('Error saving categories to cache: $e');
    }
  }
}
