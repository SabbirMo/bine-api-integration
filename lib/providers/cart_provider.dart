import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/cart_model.dart';
import 'package:binetatour/data/models/product_model.dart';

class CartProvider extends ChangeNotifier {
  final ApiServices _apiServices = ApiServices();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  CartModel? _cart;
  CartModel? get cart => _cart;

  final Map<int, ProductModel> _productDetailsCache = {};

  Future<void> fetchCart({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final response = await _apiServices.get(
        '/api/mobile/cart/',
        requireAuth: true,
      );

      final dynamic data = response.data;

      if (data != null && data is Map<String, dynamic>) {
        _cart = CartModel.fromJson(data);
      } else {
        _cart = null;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  CartItemModel? _getItem(int id) {
    final items = _cart?.items.where((e) => e.id == id).toList() ?? [];
    return items.isEmpty ? null : items.first;
  }

  double _getPrice(CartItemModel item) {
    return item.priceAfterDiscount > 0
        ? item.priceAfterDiscount
        : item.sellingPrice;
  }

  Future<void> increment(int itemId, BuildContext context) async {
    final item = _getItem(itemId);
    if (item == null) return;

    // Check stock limit
    ProductModel? product;
    if (_productDetailsCache.containsKey(item.productId)) {
      product = _productDetailsCache[item.productId];
    } else {
      try {
        final response = await _apiServices.get(
          '/api/mobile/products/${item.productId}/',
          requireAuth: false,
        );
        final data = response.data;
        if (data != null && data is Map<String, dynamic>) {
          product = ProductModel.fromJson(data);
          _productDetailsCache[item.productId] = product;
        }
      } catch (e) {
        debugPrint("Error checking product stock: $e");
      }
    }

    if (product != null) {
      ProductVariantModel? matchingVariant;
      // Search by variantId first
      for (var v in product.variants) {
        if (item.variantId != null && v.id == item.variantId) {
          matchingVariant = v;
          break;
        }
      }
      // If not found, try to match by color/size
      if (matchingVariant == null && product.variants.isNotEmpty) {
        for (var v in product.variants) {
          bool colorMatch = (v.colorCode == item.colorCode) || (v.colorName == item.colorName);
          bool sizeMatch = v.size == item.size;
          if (colorMatch && sizeMatch) {
            matchingVariant = v;
            break;
          }
        }
      }

      // Fallback: use first variant if still not matched
      if (matchingVariant == null && product.variants.isNotEmpty) {
        matchingVariant = product.variants.first;
      }

      if (matchingVariant != null) {
        final maxStock = matchingVariant.stockQuantity;
        if (item.quantity >= maxStock) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Stock disponible : $maxStock",
                  textAlign: TextAlign.center,
                ),
                backgroundColor: const Color(0xFFFF6900),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(20),
              ),
            );
          }
          return;
        }
      }
    }

    item.quantity++;
    _cart?.total += _getPrice(item);
    notifyListeners();

    try {
      await _apiServices.patch(
        '/api/mobile/cart/$itemId/',
        data: {'quantity': item.quantity},
        requireAuth: true,
      );
      await fetchCart(showLoading: false);
    } catch (e) {
      await fetchCart(showLoading: false);
    }
  }

  Future<void> decrement(int itemId) async {
    final item = _getItem(itemId);
    if (item == null || item.quantity <= 1) return;

    item.quantity--;
    _cart?.total -= _getPrice(item);
    notifyListeners();

    try {
      await _apiServices.patch(
        '/api/mobile/cart/$itemId/',
        data: {'quantity': item.quantity},
        requireAuth: true,
      );
      await fetchCart(showLoading: false);
    } catch (e) {
      await fetchCart(showLoading: false);
    }
  }

  Future<void> remove(int itemId) async {
    final item = _getItem(itemId);
    if (item == null) return;

    _cart?.items.remove(item);
    _cart?.total -= _getPrice(item) * item.quantity;
    notifyListeners();

    try {
      await _apiServices.delete('/api/mobile/cart/$itemId/', requireAuth: true);
      await fetchCart(showLoading: false);
    } catch (e) {
      await fetchCart(showLoading: false);
    }
  }

  Future<void> addToCart(ProductModel product, {int quantity = 1}) async {
    if (product.status == "out_of_stock") {
      log("Cannot add to cart: Product is out of stock.");
      return;
    }
    try {
      final response = await _apiServices.post(
        '/api/mobile/cart/',
        data: {'product_id': product.id, 'quantity': quantity},
        requireAuth: true,
      );
      await fetchCart(showLoading: false);
      log("Response: ${response.data}");
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  void clearCart() {
    _cart = null;
    _errorMessage = null;
    notifyListeners();
  }
}
