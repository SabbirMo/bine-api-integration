import 'package:binetatour/core/utils/media_url_resolver.dart';

class ProductModel {
  final int id;
  final String productName;
  final int categoryId;
  final String categoryName;
  final int? subcategoryId;
  final String? subcategoryName;
  final String sellingPrice;
  final String discountPercentage;
  final String priceAfterDiscount;
  final String status;
  final String? mainImage;
  final List<MediaModel> media;
  final String? videoUrl;
  final String? hlsUrl;
  final String? thumbnailUrl;

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
    this.videoUrl,
    this.hlsUrl,
    this.thumbnailUrl,
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

  String get effectiveVideoUrl {
    final topLevel = MediaUrlResolver.resolveVideoUrl(
      mediaUrl: videoUrl,
      hlsUrl: hlsUrl,
    );
    if (topLevel.isNotEmpty) return topLevel;

    for (final m in media) {
      final mType = m.mediaType.toLowerCase().trim();
      final mUrl = m.effectiveMediaUrl;
      if ((mType == 'video' || MediaUrlResolver.isVideoUrl(mUrl)) &&
          mUrl.isNotEmpty) {
        return mUrl;
      }
    }
    if (mainImage != null && MediaUrlResolver.isVideoUrl(mainImage!)) {
      return MediaUrlResolver.resolveUrl(mainImage!);
    }
    return '';
  }

  static bool _isLocalVideoUrl(String url) {
    if (url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase().split('?').first.split('#').first;
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.m3u8') ||
        clean.endsWith('.webm') ||
        clean.endsWith('.avi') ||
        clean.endsWith('.mkv') ||
        clean.contains('.mp4') ||
        clean.contains('.m3u8');
  }

  String get effectiveThumbnailUrl {
    for (final m in media) {
      if (m.thumbnailUrl != null && m.thumbnailUrl!.isNotEmpty) {
        return m.thumbnailUrl!;
      }
      if (m.mediaType == 'image' && m.effectiveMediaUrl.isNotEmpty) {
        return m.effectiveMediaUrl;
      }
    }
    if (mainImage != null && !_isLocalVideoUrl(mainImage!)) {
      return mainImage!;
    }
    return '';
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
    final List<MediaModel> parsedMedia = [];
    if (rawMediaList is List) {
      for (final item in rawMediaList) {
        if (item != null && item is Map) {
          try {
            parsedMedia.add(
              MediaModel.fromJson(Map<String, dynamic>.from(item)),
            );
          } catch (_) {}
        }
      }
    }

    final rawVideoUrl =
        json['video_url']?.toString() ??
        json['video']?.toString() ??
        json['video_file']?.toString() ??
        json['file']?.toString() ??
        json['media_url']?.toString();
    final rawHlsUrl = json['hls_url']?.toString();
    if ((rawVideoUrl != null && rawVideoUrl.isNotEmpty) ||
        (rawHlsUrl != null && rawHlsUrl.isNotEmpty)) {
      final hasVideoMedia = parsedMedia.any(
        (m) => m.mediaType.toLowerCase() == 'video',
      );
      if (!hasVideoMedia) {
        parsedMedia.insert(
          0,
          MediaModel(
            id: 0,
            mediaType: 'video',
            mediaUrl: rawVideoUrl ?? '',
            hlsUrl: rawHlsUrl,
            thumbnailUrl:
                json['thumbnail_url']?.toString() ??
                json['thumbnail']?.toString() ??
                json['main_image']?.toString(),
          ),
        );
      }
    }

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

    String pad = '';
    if (json['price_after_discount'] != null &&
        json['price_after_discount'].toString().trim().isNotEmpty) {
      pad = json['price_after_discount'].toString();
    } else {
      pad = json['selling_price']?.toString() ?? '0';
    }

    final catIdRaw = json['category_id'] ?? json['category'];
    final int categoryId = catIdRaw is num
        ? catIdRaw.toInt()
        : (int.tryParse(catIdRaw?.toString() ?? '0') ?? 0);

    final subCatIdRaw = json['subcategory_id'] ?? json['subcategory'];
    final int? subcategoryId = subCatIdRaw is num
        ? subCatIdRaw.toInt()
        : int.tryParse(subCatIdRaw?.toString() ?? '');

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
      videoUrl: rawVideoUrl,
      hlsUrl: rawHlsUrl,
      thumbnailUrl: json['thumbnail_url']?.toString() ??
          json['thumbnail']?.toString() ??
          json['thumb_url']?.toString(),
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
    return MediaUrlResolver.resolveVideoUrl(
      mediaUrl: mediaUrl,
      hlsUrl: hlsUrl,
    );
  }

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    final rawUrl =
        json['media_url'] ??
        json['media_file'] ??
        json['file'] ??
        json['video'] ??
        json['video_url'] ??
        json['url'];
    String mType = json['media_type']?.toString().toLowerCase().trim() ?? '';
    final urlStr = (rawUrl?.toString() ?? '').toLowerCase().trim();
    if (mType.isEmpty) {
      if (urlStr.endsWith('.mp4') ||
          urlStr.endsWith('.mov') ||
          urlStr.endsWith('.m3u8') ||
          urlStr.endsWith('.webm') ||
          urlStr.endsWith('.avi') ||
          urlStr.endsWith('.mkv') ||
          urlStr.contains('.mp4') ||
          urlStr.contains('.m3u8')) {
        mType = 'video';
      } else if (urlStr.endsWith('.mp3') ||
          urlStr.endsWith('.wav') ||
          urlStr.endsWith('.aac') ||
          urlStr.endsWith('.m4a')) {
        mType = 'audio';
      } else {
        mType = 'image';
      }
    }

    return MediaModel(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      mediaType: mType,
      mediaUrl: rawUrl?.toString() ?? '',
      hlsUrl: json['hls_url']?.toString(),
      thumbnailUrl:
          json['thumbnail_url']?.toString() ??
          json['thumbnail']?.toString() ??
          json['thumb_url']?.toString(),
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
