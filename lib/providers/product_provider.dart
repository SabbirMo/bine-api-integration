import 'package:flutter/material.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/product_model.dart';

class ProductProvider extends ChangeNotifier {
  final ApiServices _apiServices = ApiServices();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<ProductModel> _allProducts = [];
  List<ProductModel> get allProducts => _allProducts;

  Future<void> fetchProducts() async {
    if (_allProducts.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    _errorMessage = null;

    try {
      final response = await _apiServices.get(
        '/api/mobile/products/',
        requireAuth: false,
      );

      final dynamic data = response.data;

      if (data != null &&
          data is Map<String, dynamic> &&
          data.containsKey('results')) {
        _allProducts = (data['results'] as List)
            .map(
              (e) => ProductModel.fromJson(
                Map<String, dynamic>.from(e is Map ? e : {}),
              ),
            )
            .toList();
      } else if (data is List) {
        _allProducts = data
            .map(
              (e) => ProductModel.fromJson(
                Map<String, dynamic>.from(e is Map ? e : {}),
              ),
            )
            .toList();
      } else {
        _allProducts = [];
      }
      for (final p in _allProducts) {
        if (!_productDetailsCache.containsKey(p.id)) {
          _productDetailsCache[p.id] = p;
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("❌ [Error Products List]: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<ProductModel> getFilteredProducts(int? categoryId, int? subcategoryId) {
    if (categoryId == null || categoryId == -1) {
      return _allProducts; // Return all for "Tous"
    }

    return _allProducts.where((product) {
      bool categoryMatch = product.categoryId == categoryId;
      if (!categoryMatch) return false;

      if (subcategoryId != null) {
        return product.subcategoryId == subcategoryId;
      }
      return true;
    }).toList();
  }

  final Map<int, ProductModel> _productDetailsCache = {};
  final Map<int, Future<ProductModel?>> _inFlightFetches = {};

  void clearCache() {
    _productDetailsCache.clear();
    _inFlightFetches.clear();
  }

  /// Store or update a product in memory cache
  void seedProductCache(ProductModel product) {
    if (product.id > 0) {
      final existing = _productDetailsCache[product.id];
      if (existing == null || existing.media.isEmpty) {
        _productDetailsCache[product.id] = product;
      }
    }
  }

  bool isProductDetailsCached(int id) {
    final p = _productDetailsCache[id];
    return p != null &&
        ((p.description != null && p.description!.isNotEmpty) ||
            p.variants.isNotEmpty ||
            p.totalStock > 0);
  }

  ProductModel? getCachedProduct(int id) {
    if (_productDetailsCache.containsKey(id)) {
      return _productDetailsCache[id];
    }
    final fallback = _allProducts.where((p) => p.id == id).firstOrNull;
    if (fallback != null) {
      _productDetailsCache[id] = fallback;
    }
    return fallback;
  }

  Future<ProductModel?> fetchProductDetails(
    int id, {
    bool forceRefresh = false,
  }) async {
    final cached = _productDetailsCache[id];
    final isFullDetails = cached != null &&
        ((cached.description != null && cached.description!.isNotEmpty) ||
            cached.variants.isNotEmpty ||
            cached.totalStock > 0);

    if (!forceRefresh && isFullDetails) {
      return cached;
    }
    if (_inFlightFetches.containsKey(id)) {
      return await _inFlightFetches[id];
    }
    final future = _fetchProductDetailsBackground(id);
    _inFlightFetches[id] = future;
    return await future;
  }

  Future<ProductModel?> _fetchProductDetailsBackground(int id) async {
    try {
      final response = await _apiServices.get(
        '/api/mobile/products/$id/',
        requireAuth: false,
      );
      final data = response.data;
      if (data != null && data is Map<String, dynamic>) {
        final product = ProductModel.fromJson(data);
        _productDetailsCache[id] = product;
        notifyListeners();
        return product;
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch product details ID: $id: $e');
    } finally {
      _inFlightFetches.remove(id);
    }
    return _productDetailsCache[id];
  }

  Future<void> trackVideoView(int id) async {
    try {
      await _apiServices.post(
        '/api/mobile/products/$id/video-view/',
        requireAuth: false,
      );
    } catch (e) {
      debugPrint('Failed to track video view: $e');
    }
  }
}
