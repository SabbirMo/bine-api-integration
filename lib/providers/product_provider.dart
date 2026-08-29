import 'package:flutter/material.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/product_model.dart';

class ProductProvider extends ChangeNotifier {
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

  List<ProductModel> _allProducts = [];
  List<ProductModel> get allProducts => _allProducts;

  List<ProductModel> _parseProducts(dynamic data) {
    List<dynamic> list = [];
    if (data != null && data is Map<String, dynamic>) {
      if (data['results'] is List) {
        list = data['results'];
      } else if (data['data'] is List) {
        list = data['data'];
      } else if (data['data'] is Map && data['data']['results'] is List) {
        list = data['data']['results'];
      } else if (data['products'] is List) {
        list = data['products'];
      }
    } else if (data is List) {
      list = data;
    }

    return list
        .map(
          (e) => ProductModel.fromJson(
            Map<String, dynamic>.from(e is Map ? e : {}),
          ),
        )
        .toList();
  }

  Future<void> fetchProducts({bool refresh = true}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    if (_allProducts.isEmpty || refresh) {
      _isLoading = true;
      notifyListeners();
    }
    _errorMessage = null;

    try {
      final response = await _apiServices.get(
        '/api/mobile/products/',
        queryParameters: {'page': _currentPage},
        requireAuth: false,
      );

      final dynamic data = response.data;
      final parsed = _parseProducts(data);

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
        _allProducts = parsed;
      } else {
        for (final p in parsed) {
          if (!_allProducts.any((existing) => existing.id == p.id)) {
            _allProducts.add(p);
          }
        }
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

  Future<void> loadMoreProducts() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final response = await _apiServices.get(
        '/api/mobile/products/',
        queryParameters: {'page': nextPage},
        requireAuth: false,
      );

      final dynamic data = response.data;
      final parsed = _parseProducts(data);

      if (parsed.isNotEmpty) {
        _currentPage = nextPage;
        for (final p in parsed) {
          if (!_allProducts.any((existing) => existing.id == p.id)) {
            _allProducts.add(p);
          }
          if (!_productDetailsCache.containsKey(p.id)) {
            _productDetailsCache[p.id] = p;
          }
        }
      }

      if (data is Map && data['next'] == null) {
        _hasMore = false;
      } else if (parsed.isEmpty || parsed.length < 5) {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint("❌ [Error Load More Products]: $e");
    } finally {
      _isLoadingMore = false;
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
