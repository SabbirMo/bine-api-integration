import 'package:flutter/foundation.dart';
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
  final Set<int> _productIds = {};

  static List<ProductModel> _parseProducts(dynamic data) {
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
        .map((e) => ProductModel.fromJson((e as Map<String, dynamic>?) ?? {}))
        .toList();
  }

  int? _activeCategoryId;
  int? get activeCategoryId => _activeCategoryId;

  int? _activeSubcategoryId;
  int? get activeSubcategoryId => _activeSubcategoryId;

  // Filtered caches keyed by "categoryId:subcategoryId"
  final Map<String, List<ProductModel>> _filteredCache = {};
  final Map<String, int> _categoryCurrentPage = {};
  final Map<String, bool> _categoryHasMore = {};
  final Map<String, Set<int>> _categoryProductIds = {};

  static String _cacheKey(int? categoryId, int? subcategoryId) {
    final cat = (categoryId == null || categoryId == -1)
        ? 'all'
        : categoryId.toString();
    final sub = subcategoryId?.toString() ?? 'all';
    return '$cat:$sub';
  }

  Future<void> fetchProducts({
    bool refresh = true,
    int? categoryId,
    int? subcategoryId,
  }) async {
    final normalizedCatId = (categoryId == null || categoryId == -1)
        ? null
        : categoryId;
    final normalizedSubCatId = (normalizedCatId == null) ? null : subcategoryId;
    final key = _cacheKey(normalizedCatId, normalizedSubCatId);

    _activeCategoryId = normalizedCatId;
    _activeSubcategoryId = normalizedSubCatId;

    if (refresh) {
      _categoryCurrentPage[key] = 1;
      _categoryHasMore[key] = true;
      _currentPage = 1;
      _hasMore = true;
    } else {
      _currentPage = _categoryCurrentPage[key] ?? 1;
      _hasMore = _categoryHasMore[key] ?? true;
    }

    final hasCached =
        _filteredCache.containsKey(key) && _filteredCache[key]!.isNotEmpty;

    // If we have cached data and not refreshing, display immediately without blocking
    if (hasCached && !refresh) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    _errorMessage = null;

    try {
      final Map<String, dynamic> qParams = {
        'page': refresh ? 1 : (_categoryCurrentPage[key] ?? 1),
      };
      if (normalizedCatId != null) {
        qParams['category'] = normalizedCatId;
      }
      if (normalizedSubCatId != null) {
        qParams['subcategory'] = normalizedSubCatId;
      }

      final response = await _apiServices.get(
        '/api/mobile/products/',
        queryParameters: qParams,
        requireAuth: false,
      );

      final dynamic data = response.data;
      final parsed = await compute(_parseProducts, data);

      bool hasMoreData = false;
      if (data is Map) {
        if (data['next'] != null) {
          hasMoreData = true;
        } else if (parsed.length < 5) {
          hasMoreData = false;
        } else {
          hasMoreData = true;
        }
      } else {
        hasMoreData = parsed.length >= 5;
      }

      _categoryHasMore[key] = hasMoreData;
      _hasMore = hasMoreData;

      _categoryProductIds.putIfAbsent(key, () => <int>{});
      if (refresh || !_filteredCache.containsKey(key)) {
        _filteredCache[key] = parsed;
        _categoryProductIds[key]!.clear();
        _categoryProductIds[key]!.addAll(parsed.map((e) => e.id));
        _categoryCurrentPage[key] = 1;
      } else {
        for (final p in parsed) {
          if (!_categoryProductIds[key]!.contains(p.id)) {
            _filteredCache[key]!.add(p);
            _categoryProductIds[key]!.add(p.id);
          }
        }
      }

      // Keep _allProducts updated
      if (normalizedCatId == null && normalizedSubCatId == null) {
        _allProducts = List.from(_filteredCache[key] ?? []);
        _productIds.clear();
        _productIds.addAll(_allProducts.map((e) => e.id));
      } else {
        for (final p in parsed) {
          if (!_productIds.contains(p.id)) {
            _allProducts.add(p);
            _productIds.add(p.id);
          }
        }
      }

      // Seed product details cache
      for (final p in parsed) {
        if (!_productDetailsCache.containsKey(p.id)) {
          _productDetailsCache[p.id] = p;
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreProducts() async {
    final key = _cacheKey(_activeCategoryId, _activeSubcategoryId);
    final hasMoreForCurrent = _categoryHasMore[key] ?? _hasMore;
    if (!hasMoreForCurrent || _isLoadingMore || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final currentPg = _categoryCurrentPage[key] ?? _currentPage;
      final nextPage = currentPg + 1;

      final Map<String, dynamic> qParams = {'page': nextPage};
      if (_activeCategoryId != null) {
        qParams['category'] = _activeCategoryId;
      }
      if (_activeSubcategoryId != null) {
        qParams['subcategory'] = _activeSubcategoryId;
      }

      final response = await _apiServices.get(
        '/api/mobile/products/',
        queryParameters: qParams,
        requireAuth: false,
      );

      final dynamic data = response.data;
      final parsed = await compute(_parseProducts, data);

      if (parsed.isNotEmpty) {
        _categoryCurrentPage[key] = nextPage;
        _currentPage = nextPage;

        _categoryProductIds.putIfAbsent(key, () => <int>{});
        _filteredCache.putIfAbsent(key, () => <ProductModel>[]);

        for (final p in parsed) {
          if (!_categoryProductIds[key]!.contains(p.id)) {
            _filteredCache[key]!.add(p);
            _categoryProductIds[key]!.add(p.id);
          }
          if (!_productIds.contains(p.id)) {
            _allProducts.add(p);
            _productIds.add(p.id);
          }
          if (!_productDetailsCache.containsKey(p.id)) {
            _productDetailsCache[p.id] = p;
          }
        }
      }

      bool hasMoreData = false;
      if (data is Map && data['next'] == null) {
        hasMoreData = false;
      } else if (parsed.isEmpty || parsed.length < 5) {
        hasMoreData = false;
      } else {
        hasMoreData = true;
      }

      _categoryHasMore[key] = hasMoreData;
      _hasMore = hasMoreData;
    } catch (e) {
      debugPrint("❌ [Error Load More Products]: $e");
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  List<ProductModel> getFilteredProducts(int? categoryId, int? subcategoryId) {
    final normalizedCatId = (categoryId == null || categoryId == -1)
        ? null
        : categoryId;
    final normalizedSubCatId = (normalizedCatId == null) ? null : subcategoryId;
    final key = _cacheKey(normalizedCatId, normalizedSubCatId);

    if (_filteredCache.containsKey(key)) {
      return _filteredCache[key]!;
    }

    if (normalizedCatId == null) {
      return _allProducts; // Return all for "Tous"
    }

    return _allProducts.where((product) {
      bool categoryMatch = product.categoryId == normalizedCatId;
      if (!categoryMatch) return false;

      if (normalizedSubCatId != null) {
        return product.subcategoryId == normalizedSubCatId;
      }
      return true;
    }).toList();
  }

  final Map<int, ProductModel> _productDetailsCache = {};
  final Map<int, Future<ProductModel?>> _inFlightFetches = {};

  void clearCache() {
    _productDetailsCache.clear();
    _inFlightFetches.clear();
    _filteredCache.clear();
    _categoryCurrentPage.clear();
    _categoryHasMore.clear();
    _categoryProductIds.clear();
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

  /// Silently pre-fetches and caches product details in background for 0ms transitions.
  void prefetchProductDetails(int id) {
    if (id <= 0 ||
        isProductDetailsCached(id) ||
        _inFlightFetches.containsKey(id)) {
      return;
    }
    fetchProductDetails(id).catchError((_) => null);
  }

  Future<ProductModel?> fetchProductDetails(
    int id, {
    bool forceRefresh = false,
  }) async {
    final cached = _productDetailsCache[id];
    final isFullDetails =
        cached != null &&
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
