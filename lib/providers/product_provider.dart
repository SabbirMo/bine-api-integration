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
      debugPrint("📦 [API Response - Products List]: $data");

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

  Future<ProductModel?> fetchProductDetails(int id) async {
    if (_productDetailsCache.containsKey(id)) {
      _fetchProductDetailsBackground(id);
      return _productDetailsCache[id];
    }
    return await _fetchProductDetailsBackground(id);
  }

  Future<ProductModel?> _fetchProductDetailsBackground(int id) async {
    try {
      final response = await _apiServices.get(
        '/api/mobile/products/$id/',
        requireAuth: false,
      );
      final data = response.data;
      debugPrint("📦 [API Response - Product Details ID: $id]: $data");
      if (data != null && data is Map<String, dynamic>) {
        final product = ProductModel.fromJson(data);
        _productDetailsCache[id] = product;
        return product;
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch product details ID: $id: $e');
    }
    return null;
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
