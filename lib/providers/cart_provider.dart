import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/core/video/video_frame_manager.dart';
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
  ProductModel? getProductFromCache(int id) => _productDetailsCache[id];
  Map<int, ProductModel> get productDetailsCache => _productDetailsCache;

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
        if (data['data'] is Map<String, dynamic> &&
            (data['data'] as Map<String, dynamic>).containsKey('items')) {
          _cart = CartModel.fromJson(data['data'] as Map<String, dynamic>);
        } else {
          _cart = CartModel.fromJson(data);
        }
      } else {
        _cart = null;
      }

      if (_cart != null) {
        for (final item in _cart!.items) {
          if (item.effectiveVideoUrl.isNotEmpty) {
            VideoFrameManager.instance
                .extractFirstFrame(item.effectiveVideoUrl)
                .ignore();
          }
          if (item.productId > 0 &&
              !_productDetailsCache.containsKey(item.productId)) {
            _fetchAndCacheProduct(item.productId);
          }
        }
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

  Future<void> _fetchAndCacheProduct(int productId) async {
    try {
      final response = await _apiServices.get(
        '/api/mobile/products/$productId/',
        requireAuth: false,
      );
      final data = response.data;
      if (data != null && data is Map<String, dynamic>) {
        final product = ProductModel.fromJson(data);
        _productDetailsCache[productId] = product;
        if (product.effectiveVideoUrl.isNotEmpty) {
          VideoFrameManager.instance
              .extractFirstFrame(product.effectiveVideoUrl)
              .ignore();
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  CartItemModel? _getItem(int id) {
    final items = _cart?.items.where((e) => e.id == id).toList() ?? [];
    return items.isEmpty ? null : items.first;
  }

  double _getPrice(CartItemModel item) {
    final effective = item.effectivePrice.replaceAll(' ', '').replaceAll(',', '.');
    final p = double.tryParse(effective);
    if (p != null && p > 0) return p;
    final pad = double.tryParse(item.priceAfterDiscount.replaceAll(' ', '').replaceAll(',', '.'));
    if (pad != null && pad > 0) return pad;
    final sp = double.tryParse(item.sellingPrice.replaceAll(' ', '').replaceAll(',', '.'));
    return sp ?? 0.0;
  }

  void _adjustTotal(double delta) {
    if (_cart == null) return;
    final current = double.tryParse(_cart!.total.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0;
    final updated = current + delta;
    if (updated <= 0) {
      _cart!.total = "0";
    } else if (updated % 1 == 0) {
      _cart!.total = updated.toInt().toString();
    } else {
      _cart!.total = updated.toStringAsFixed(2);
    }
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
      int maxStock = product.totalStock;

      if (item.variantId != null && item.variantId! > 0) {
        ProductVariantModel? matchingVariant;
        for (var v in product.variants) {
          if (v.id == item.variantId) {
            matchingVariant = v;
            break;
          }
        }
        if (matchingVariant != null) {
          maxStock = matchingVariant.stockQuantity;
        }
      } else if (product.isMixedMode && product.unassignedStock > 0) {
        maxStock = product.unassignedStock;
      } else if (product.isProductMode) {
        maxStock = product.totalStock > 0 ? product.totalStock : product.stockQuantity;
      } else if (product.variants.isNotEmpty) {
        // Variant mode with no variant yet or fallback
        ProductVariantModel? matchingVariant;
        for (var v in product.variants) {
          bool colorMatch = (v.colorCode == item.colorCode) || (v.colorName == item.colorName);
          bool sizeMatch = v.size == item.size;
          if (colorMatch && sizeMatch) {
            matchingVariant = v;
            break;
          }
        }
        if (matchingVariant != null) {
          maxStock = matchingVariant.stockQuantity;
        }
      }

      if (product.isOutOfStock || maxStock <= 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Ce produit est en rupture de stock !",
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

    item.quantity++;
    _adjustTotal(_getPrice(item));
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

  Future<void> updateQuantity(int itemId, int newQuantity) async {
    final item = _getItem(itemId);
    if (item == null || newQuantity < 1 || item.quantity == newQuantity) return;

    final oldQuantity = item.quantity;
    final price = _getPrice(item);

    item.quantity = newQuantity;
    _adjustTotal(price * (newQuantity - oldQuantity));
    notifyListeners();

    try {
      await _apiServices.patch(
        '/api/mobile/cart/$itemId/',
        data: {'quantity': newQuantity},
        requireAuth: true,
      );
      await fetchCart(showLoading: false);
    } catch (e) {
      debugPrint("Error updating cart quantity: $e");
      await fetchCart(showLoading: false);
    }
  }

  Future<void> decrement(int itemId) async {
    final item = _getItem(itemId);
    if (item == null || item.quantity <= 1) return;

    item.quantity--;
    _adjustTotal(-_getPrice(item));
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
    _adjustTotal(-(_getPrice(item) * item.quantity));
    notifyListeners();

    try {
      await _apiServices.delete('/api/mobile/cart/$itemId/', requireAuth: true);
      await fetchCart(showLoading: false);
    } catch (e) {
      await fetchCart(showLoading: false);
    }
  }

  Future<void> addToCart(
    ProductModel product, {
    int quantity = 1,
    bool syncImmediately = true,
  }) async {
    _productDetailsCache[product.id] = product;
    if (product.effectiveVideoUrl.isNotEmpty) {
      VideoFrameManager.instance
          .extractFirstFrame(product.effectiveVideoUrl)
          .ignore();
    }
    if (product.isOutOfStock) {
      debugPrint(
        "❌ Cannot add to cart: Product is out of stock (ID: ${product.id}, TotalStock: ${product.totalStock}, Status: ${product.status})",
      );
      throw Exception("Ce produit est en rupture de stock !");
    }
    try {
      debugPrint(
        "🛒 [AddToCart Request]: POST /api/mobile/cart/ with {'product_id': ${product.id}, 'quantity': $quantity}",
      );
      final response = await _apiServices.post(
        '/api/mobile/cart/',
        data: {'product_id': product.id, 'quantity': quantity},
        requireAuth: true,
      );
      debugPrint("✅ [AddToCart Success]: ${response.data}");

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('items')) {
          _cart = CartModel.fromJson(responseData);
          notifyListeners();
        } else if (responseData['data'] is Map<String, dynamic> &&
            (responseData['data'] as Map<String, dynamic>).containsKey('items')) {
          _cart = CartModel.fromJson(responseData['data'] as Map<String, dynamic>);
          notifyListeners();
        }
      }

      if (syncImmediately) {
        await fetchCart(showLoading: false);
      } else {
        fetchCart(showLoading: false).ignore();
      }
    } catch (e) {
      debugPrint("❌ [AddToCart Error]: $e");
      _errorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> clearServerCart() async {
    final itemsToDelete = _cart?.items != null
        ? List<CartItemModel>.from(_cart!.items)
        : <CartItemModel>[];

    _cart = null;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Try endpoint for clearing entire cart if available
      await _apiServices.delete('/api/mobile/cart/', requireAuth: true);
    } catch (_) {
      // 2. Fallback: delete item by item
      for (final item in itemsToDelete) {
        try {
          await _apiServices.delete('/api/mobile/cart/${item.id}/',
              requireAuth: true);
        } catch (e) {
          log("Error deleting cart item ${item.id}: $e");
        }
      }
    }
    await fetchCart(showLoading: false);
  }

  void clearCart() {
    clearServerCart();
  }
}
