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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiServices.get('/api/mobile/products/', requireAuth: false);
      
      final dynamic data = response.data;
      
      if (data != null && data is Map<String, dynamic> && data.containsKey('results')) {
        _allProducts = (data['results'] as List).map((e) => ProductModel.fromJson(e)).toList();
      } else if (data is List) {
        _allProducts = data.map((e) => ProductModel.fromJson(e)).toList();
      } else {
        _allProducts = [];
      }
      
    } catch (e) {
      _errorMessage = e.toString();
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

  Future<ProductModel?> fetchProductDetails(int id) async {
    try {
      final response = await _apiServices.get('/api/mobile/products/$id/', requireAuth: false);
      final data = response.data;
      if (data != null && data is Map<String, dynamic>) {
        return ProductModel.fromJson(data);
      }
    } catch (e) {
      debugPrint('Failed to fetch product details: $e');
    }
    return null;
  }

  Future<void> trackVideoView(int id) async {
    try {
      await _apiServices.post('/api/mobile/products/$id/video-view/', requireAuth: false);
    } catch (e) {
      debugPrint('Failed to track video view: $e');
    }
  }
}
