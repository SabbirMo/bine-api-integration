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
      status == 'out_of_stock' ||
      (totalStock <= 0 && status != 'pre_order' && status != 'in_stock');

  static double _parsePrice(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) {
      final clean = value.replaceAll(' ', '').replaceAll(',', '.').trim();
      return double.tryParse(clean) ?? fallback;
    }
    return fallback;
  }

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

    final rawMediaList = json['product_media'] ?? json['media'];
    final parsedMedia = rawMediaList is List
        ? rawMediaList
              .where((i) => i != null)
              .map(
                (i) => MediaModel.fromJson(
                  Map<String, dynamic>.from(i is Map ? i : {}),
                ),
              )
              .toList()
        : <MediaModel>[];

    String? mainImg = json['main_image']?.toString();
    if (mainImg == null || mainImg.isEmpty) {
      for (var m in parsedMedia) {
        if (m.mediaType == 'image' && m.effectiveMediaUrl.isNotEmpty) {
          mainImg = m.effectiveMediaUrl;
          break;
        }
      }
    }

    int rawStockQuantity = json['stock_quantity'] is num
        ? (json['stock_quantity'] as num).toInt()
        : int.tryParse(json['stock_quantity']?.toString() ?? '0') ?? 0;

    final rawUnassigned = json['unassigned_stock'] is num
        ? (json['unassigned_stock'] as num).toInt()
        : int.tryParse(json['unassigned_stock']?.toString() ?? '0') ?? 0;

    if (rawStockQuantity == 0 && rawUnassigned > 0) {
      rawStockQuantity = rawUnassigned;
    }

    int rawTotalStock = json['total_stock'] is num
        ? (json['total_stock'] as num).toInt()
        : (int.tryParse(json['total_stock']?.toString() ?? '') ??
              (json['stock'] is num ? (json['stock'] as num).toInt() : 0));

    if (rawTotalStock == 0) {
      if (parsedVariants.isEmpty) {
        rawTotalStock = rawStockQuantity > 0 ? rawStockQuantity : rawUnassigned;
      } else {
        rawTotalStock =
            parsedVariants.fold<int>(0, (sum, v) => sum + v.stockQuantity) +
            rawUnassigned;
      }
    }

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

    final sellingNum = _parsePrice(json['selling_price']);
    final discountNum = _parsePrice(json['discount_percentage']);

    double pad = 0.0;
    if (json['price_after_discount'] != null) {
      pad = _parsePrice(json['price_after_discount'], sellingNum);
    } else if (discountNum > 0 && sellingNum > 0) {
      pad = sellingNum * (1.0 - (discountNum / 100.0));
    } else {
      pad = sellingNum;
    }

    final catIdRaw = json['category_id'] ?? json['category'];
    final int categoryId = catIdRaw is num
        ? catIdRaw.toInt()
        : (int.tryParse(catIdRaw?.toString() ?? '0') ?? 0);

    final subCatIdRaw = json['subcategory_id'] ?? json['subcategory'];
    final int? subcategoryId = subCatIdRaw is num
        ? subCatIdRaw.toInt()
        : int.tryParse(subCatIdRaw?.toString() ?? '');

    debugPrint(
      "🏷️ [ProductModel]: ID=${json['id']}, Name=${json['product_name']}, Mode=$mode, TotalStock=$rawTotalStock, Unassigned=$rawUnassigned, Variants=${parsedVariants.length}",
    );

    return ProductModel(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      productName: json['product_name']?.toString() ?? '',
      categoryId: categoryId,
      categoryName: json['category_name']?.toString() ?? '',
      subcategoryId: subcategoryId,
      subcategoryName: json['subcategory_name']?.toString(),
      sellingPrice: json['selling_price']?.toString() ?? '0',
      discountPercentage: json['discount_percentage']?.toString() ?? '0',
      priceAfterDiscount: pad,
      status: json['status']?.toString() ?? '',
      mainImage: mainImg,
      media: parsedMedia,
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
  final String? thumbnailUrl;
  final String? videoStatus;
  final double? videoDuration;

  MediaModel({
    required this.id,
    required this.mediaType,
    required this.mediaUrl,
    this.hlsUrl,
    this.thumbnailUrl,
    this.videoStatus,
    this.videoDuration,
  });

  String get effectiveMediaUrl {
    if (mediaUrl.trim().isNotEmpty) return mediaUrl;
    if (hlsUrl != null && hlsUrl!.trim().isNotEmpty) return hlsUrl!;
    return '';
  }

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['media_url'] ?? json['media_file'];
    return MediaModel(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      mediaType: json['media_type']?.toString() ?? '',
      mediaUrl: rawUrl?.toString() ?? '',
      hlsUrl: json['hls_url']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      videoStatus: json['video_status']?.toString(),
      videoDuration: json['video_duration'] is num
          ? (json['video_duration'] as num).toDouble()
          : double.tryParse(json['video_duration']?.toString() ?? ''),
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
