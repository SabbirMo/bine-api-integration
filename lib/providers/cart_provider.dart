import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:binetatour/core/token_storage/token_storage.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/cart_model.dart';
import 'package:binetatour/data/models/product_model.dart';

class CartProvider extends ChangeNotifier {
  static const String _cachedCartKey = 'cached_cart_data';
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

  CartProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadFromCache();
    await _fetchIfAuthenticated();
  }

  Future<void> _fetchIfAuthenticated() async {
    try {
      final token = await TokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        await fetchCart(showLoading: false);
      }
    } catch (e) {
      debugPrint("Error auto-fetching cart on init: $e");
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_cart != null && _cart!.items.isNotEmpty) {
        await prefs.setString(_cachedCartKey, json.encode(_cart!.toJson()));
      } else {
        await prefs.remove(_cachedCartKey);
      }
    } catch (e) {
      debugPrint("Error saving cached cart: $e");
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_cachedCartKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final dynamic raw = json.decode(cachedStr);
        if (raw is Map<String, dynamic>) {
          _cart = CartModel.fromJson(raw);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error loading cached cart: $e");
    }
  }

  Future<void> fetchCart({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      int page = 1;
      final response = await _apiServices.get(
        '/api/mobile/cart/',
        queryParameters: {'page': page},
        requireAuth: true,
      );

      final dynamic rawData = response.data;
      final Map<String, dynamic>? data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : null;

      if (data != null) {
        if (data['data'] is Map) {
          _cart = CartModel.fromJson(
            Map<String, dynamic>.from(data['data'] as Map),
          );
        } else {
          _cart = CartModel.fromJson(data);
        }

        // Handle pagination: fetch subsequent pages if present
        bool hasNext = false;
        if (data['next'] != null) {
          hasNext = true;
        } else if (data['data'] is Map &&
            (data['data'] as Map)['next'] != null) {
          hasNext = true;
        }

        while (hasNext) {
          page++;
          try {
            final nextResp = await _apiServices.get(
              '/api/mobile/cart/',
              queryParameters: {'page': page},
              requireAuth: true,
            );
            final dynamic rawNext = nextResp.data;
            final Map<String, dynamic>? nextData = rawNext is Map
                ? Map<String, dynamic>.from(rawNext)
                : null;
            if (nextData != null) {
              final pageCart = CartModel.fromJson(
                nextData['data'] is Map
                    ? Map<String, dynamic>.from(nextData['data'] as Map)
                    : nextData,
              );
              if (pageCart.items.isNotEmpty && _cart != null) {
                for (final item in pageCart.items) {
                  if (!_cart!.items.any((existing) => existing.id == item.id)) {
                    _cart!.items.add(item);
                  }
                }
              }
              hasNext =
                  nextData['next'] != null ||
                  (nextData['data'] is Map &&
                      (nextData['data'] as Map)['next'] != null);
              if (pageCart.items.isEmpty) hasNext = false;
            } else {
              hasNext = false;
            }
          } catch (e) {
            debugPrint("Error fetching cart page $page: $e");
            hasNext = false;
          }
        }
      } else {
        _cart = null;
      }

      if (_cart != null) {
        for (final item in _cart!.items) {
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
      if (_errorMessage == null) {
        _saveToCache();
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
        notifyListeners();
      }
    } catch (_) {}
  }

  CartItemModel? _getItem(int id) {
    final items = _cart?.items.where((e) => e.id == id).toList() ?? [];
    return items.isEmpty ? null : items.first;
  }

  double _getPrice(CartItemModel item) {
    final effective = item.effectivePrice
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    final p = double.tryParse(effective);
    if (p != null && p > 0) return p;
    final pad = double.tryParse(
      item.priceAfterDiscount.replaceAll(' ', '').replaceAll(',', '.'),
    );
    if (pad != null && pad > 0) return pad;
    final sp = double.tryParse(
      item.sellingPrice.replaceAll(' ', '').replaceAll(',', '.'),
    );
    return sp ?? 0.0;
  }

  void _adjustTotal(double delta) {
    if (_cart == null) return;
    final current =
        double.tryParse(
          _cart!.total.replaceAll(' ', '').replaceAll(',', '.'),
        ) ??
        0.0;
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
        maxStock = product.totalStock > 0
            ? product.totalStock
            : product.stockQuantity;
      } else if (product.variants.isNotEmpty) {
        // Variant mode with no variant yet or fallback
        ProductVariantModel? matchingVariant;
        for (var v in product.variants) {
          bool colorMatch =
              (v.colorCode == item.colorCode) ||
              (v.colorName == item.colorName);
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
            (responseData['data'] as Map<String, dynamic>).containsKey(
              'items',
            )) {
          _cart = CartModel.fromJson(
            responseData['data'] as Map<String, dynamic>,
          );
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
    await _saveToCache();
    notifyListeners();

    try {
      // 1. Try endpoint for clearing entire cart if available
      await _apiServices.delete('/api/mobile/cart/', requireAuth: true);
    } catch (_) {
      // 2. Fallback: delete item by item
      for (final item in itemsToDelete) {
        try {
          await _apiServices.delete(
            '/api/mobile/cart/${item.id}/',
            requireAuth: true,
          );
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
