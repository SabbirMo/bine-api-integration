import 'package:flutter/foundation.dart';

class ProductModel {
  final int id;
  final String productName;
  final int categoryId;
  final String categoryName;
  final int? subcategoryId;
  final String? subcategoryName;
  final String sellingPrice;
  final String discountPercentage;
  final double priceAfterDiscount;
  final String status;
  final String? mainImage;
  final List<MediaModel> media;

  final String? actualPrice;
  final String? deliveryPrice;
  final String? description;
  final String? deliveryMessage;
  final List<ProductVariantModel> variants;
  final String? createdAt;

  // New stock fields according to API specs
  final String stockMode; // "product", "variant", "mixed"
  final int stockQuantity; // Raw product-level stock quantity
  final int unassignedStock; // Available unassigned stock pool
  final int totalStock; // Total sellable stock
  final bool noVariant; // Shortcut for stockMode == "product"
  final int stock; // From list response

  ProductModel({
    required this.id,
    required this.productName,
    required this.categoryId,
    required this.categoryName,
    this.subcategoryId,
    this.subcategoryName,
    required this.sellingPrice,
    required this.discountPercentage,
    required this.priceAfterDiscount,
    required this.status,
    this.mainImage,
    required this.media,
    this.actualPrice,
    this.deliveryPrice,
    this.description,
    this.deliveryMessage,
    this.variants = const [],
    this.createdAt,
    this.stockMode = 'product',
    this.stockQuantity = 0,
    this.unassignedStock = 0,
    this.totalStock = 0,
    this.noVariant = false,
    this.stock = 0,
  });

  bool get isProductMode =>
      stockMode == 'product' ||
      noVariant ||
      (variants.isEmpty && unassignedStock == 0);
  bool get isVariantMode =>
      stockMode == 'variant' ||
      (variants.isNotEmpty && unassignedStock <= 0 && stockMode != 'mixed');
  bool get isMixedMode =>
      stockMode == 'mixed' || (variants.isNotEmpty && unassignedStock > 0);
  bool get isOutOfStock =>
      status == 'out_of_stock' || (totalStock <= 0 && status != 'pre_order');

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final parsedVariants = json['variants'] != null && json['variants'] is List
        ? (json['variants'] as List)
              .where((i) => i != null)
              .map(
                (i) => ProductVariantModel.fromJson(
                  Map<String, dynamic>.from(i is Map ? i : {}),
                ),
              )
              .toList()
        : <ProductVariantModel>[];

    final rawStockQuantity = json['stock_quantity'] is num
        ? (json['stock_quantity'] as num).toInt()
        : int.tryParse(json['stock_quantity']?.toString() ?? '0') ?? 0;

    final rawUnassigned = json['unassigned_stock'] is num
        ? (json['unassigned_stock'] as num).toInt()
        : int.tryParse(json['unassigned_stock']?.toString() ?? '0') ?? 0;

    final rawTotalStock = json['total_stock'] is num
        ? (json['total_stock'] as num).toInt()
        : int.tryParse(json['total_stock']?.toString() ?? '') ??
              (json['stock'] is num
                  ? (json['stock'] as num).toInt()
                  : (parsedVariants.isEmpty
                        ? rawStockQuantity
                        : parsedVariants.fold<int>(
                                0,
                                (sum, v) => sum + v.stockQuantity,
                              ) +
                              rawUnassigned));

    final rawStock = json['stock'] is num
        ? (json['stock'] as num).toInt()
        : rawTotalStock;

    String mode = json['stock_mode']?.toString().toLowerCase() ?? '';
    if (mode.isEmpty) {
      if (parsedVariants.isEmpty) {
        mode = 'product';
      } else if (rawUnassigned > 0) {
        mode = 'mixed';
      } else {
        mode = 'variant';
      }
    }

    final bool noVar = json['no_variant'] == true || mode == 'product';

    debugPrint(
      "🏷️ [ProductModel]: ID=${json['id']}, Name=${json['product_name']}, Mode=$mode, TotalStock=$rawTotalStock, Unassigned=$rawUnassigned, Variants=${parsedVariants.length}",
    );

    return ProductModel(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      productName: json['product_name']?.toString() ?? '',
      categoryId: json['category_id'] is num
          ? (json['category_id'] as num).toInt()
          : (int.tryParse(json['category_id']?.toString() ?? '0') ?? 0),
      categoryName: json['category_name']?.toString() ?? '',
      subcategoryId: json['subcategory_id'] is num
          ? (json['subcategory_id'] as num).toInt()
          : int.tryParse(json['subcategory_id']?.toString() ?? ''),
      subcategoryName: json['subcategory_name']?.toString(),
      sellingPrice: json['selling_price']?.toString() ?? '0',
      discountPercentage: json['discount_percentage']?.toString() ?? '0',
      priceAfterDiscount:
          (json['price_after_discount'] as num?)?.toDouble() ??
          (double.tryParse(json['price_after_discount']?.toString() ?? '0') ??
              0.0),
      status: json['status']?.toString() ?? '',
      mainImage: json['main_image']?.toString(),
      media: json['media'] != null && json['media'] is List
          ? (json['media'] as List)
                .where((i) => i != null)
                .map(
                  (i) => MediaModel.fromJson(
                    Map<String, dynamic>.from(i is Map ? i : {}),
                  ),
                )
                .toList()
          : [],
      actualPrice: json['actual_price']?.toString(),
      deliveryPrice: json['delivery_price']?.toString(),
      description: json['description']?.toString(),
      deliveryMessage: json['delivery_message']?.toString(),
      variants: parsedVariants,
      createdAt: json['created_at']?.toString(),
      stockMode: mode,
      stockQuantity: rawStockQuantity,
      unassignedStock: rawUnassigned,
      totalStock: rawTotalStock,
      noVariant: noVar,
      stock: rawStock,
    );
  }
}

class MediaModel {
  final int id;
  final String mediaType; // "image", "video", "audio"
  final String mediaUrl;
  final String? hlsUrl;

  MediaModel({
    required this.id,
    required this.mediaType,
    required this.mediaUrl,
    this.hlsUrl,
  });

  String get effectiveMediaUrl =>
      (mediaUrl.trim().isNotEmpty) ? mediaUrl : (hlsUrl ?? '');

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    return MediaModel(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      mediaType: json['media_type']?.toString() ?? '',
      mediaUrl: json['media_url']?.toString() ?? '',
      hlsUrl: json['hls_url']?.toString(),
    );
  }
}

class ProductVariantModel {
  final int id;
  final String colorName;
  final String colorCode;
  final String size;
  final int stockQuantity;

  ProductVariantModel({
    required this.id,
    required this.colorName,
    required this.colorCode,
    required this.size,
    required this.stockQuantity,
  });

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    return ProductVariantModel(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      colorName: json['color_name']?.toString() ?? '',
      colorCode: json['color_code']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      stockQuantity: json['stock_quantity'] is num
          ? (json['stock_quantity'] as num).toInt()
          : (int.tryParse(json['stock_quantity']?.toString() ?? '0') ?? 0),
    );
  }
}
