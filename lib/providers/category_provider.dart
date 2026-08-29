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

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  int _currentPage = 1;
  int get currentPage => _currentPage;

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

  List<CategoryModel> _parseCategories(dynamic data) {
    List<dynamic> list = [];
    if (data is List) {
      list = data;
    } else if (data is Map<String, dynamic>) {
      if (data['results'] is List) {
        list = data['results'];
      } else if (data['data'] is List) {
        list = data['data'];
      } else if (data['data'] is Map && data['data']['results'] is List) {
        list = data['data']['results'];
      } else if (data['categories'] is List) {
        list = data['categories'];
      }
    }

    return list
        .where((e) => e != null && e is Map)
        .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> fetchCategories({
    bool forceLoading = false,
    bool refresh = true,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    if (_categories.isEmpty || forceLoading || refresh) {
      _isLoading = true;
      notifyListeners();
    }
    _errorMessage = null;

    try {
      final response = await _apiServices.get(
        '/api/mobile/categories/',
        queryParameters: {'page': _currentPage},
        requireAuth: false,
      );

      final dynamic data = response.data;
      final parsed = _parseCategories(data);

      if (data is Map) {
        if (data['next'] != null) {
          _hasMore = true;
        } else if (parsed.length < 5) {
          _hasMore = false;
        } else {
          _hasMore = true;
        }
      } else {
        _hasMore = parsed.length >= 5;
      }

      if (refresh) {
        _categories = parsed;
        if (data is List || data is Map) {
          _saveToCache(data);
        }
      } else {
        for (final item in parsed) {
          if (!_categories.any((c) => c.id == item.id)) {
            _categories.add(item);
          }
        }
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

  Future<void> loadMoreCategories() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final response = await _apiServices.get(
        '/api/mobile/categories/',
        queryParameters: {'page': nextPage},
        requireAuth: false,
      );

      final dynamic data = response.data;
      final parsed = _parseCategories(data);

      if (parsed.isNotEmpty) {
        _currentPage = nextPage;
        for (final item in parsed) {
          if (!_categories.any((c) => c.id == item.id)) {
            _categories.add(item);
          }
        }
      }

      if (data is Map && data['next'] == null) {
        _hasMore = false;
      } else if (parsed.isEmpty || parsed.length < 5) {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('Failed to load more categories: $e');
    } finally {
      _isLoadingMore = false;
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

