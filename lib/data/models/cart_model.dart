class CartModel {
  final List<CartItemModel> items;
  double total;

  CartModel({
    required this.items,
    required this.total,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    return CartModel(
      items: (json['items'] as List?)
              ?.map((item) => CartItemModel.fromJson(item))
              .toList() ??
          [],
      total: _parseDouble(json['total']),
    );
  }

  static int _parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final clean = value.replaceAll(' ', '').replaceAll(',', '.').trim();
      return double.tryParse(clean) ?? 0.0;
    }
    return 0.0;
  }
}

class CartItemModel {
  final int id;
  final int productId;
  final int? variantId;
  final String productName;
  final double sellingPrice;
  final double priceAfterDiscount;
  final String? mainImage;
  final String? videoUrl;
  final String? thumbnailUrl;
  int quantity;
  final String? colorName;
  final String? colorCode;
  final String? size;

  CartItemModel({
    required this.id,
    required this.productId,
    this.variantId,
    required this.productName,
    required this.sellingPrice,
    required this.priceAfterDiscount,
    this.mainImage,
    this.videoUrl,
    this.thumbnailUrl,
    required this.quantity,
    this.colorName,
    this.colorCode,
    this.size,
  });

  static bool isVideoUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase().split('?').first.split('#').first;
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.m3u8') ||
        clean.endsWith('.webm') ||
        clean.endsWith('.avi') ||
        clean.endsWith('.mkv') ||
        clean.endsWith('.flv') ||
        clean.endsWith('.3gp') ||
        clean.contains('.mp4') ||
        clean.contains('.m3u8');
  }

  String get effectiveThumbnailUrl {
    if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty && !isVideoUrl(thumbnailUrl)) {
      return thumbnailUrl!.trim();
    }
    if (mainImage != null && mainImage!.trim().isNotEmpty && !isVideoUrl(mainImage)) {
      return mainImage!.trim();
    }
    return '';
  }

  String get effectiveVideoUrl {
    if (videoUrl != null && videoUrl!.trim().isNotEmpty) {
      return videoUrl!.trim();
    }
    if (mainImage != null && mainImage!.trim().isNotEmpty && isVideoUrl(mainImage)) {
      return mainImage!.trim();
    }
    if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty && isVideoUrl(thumbnailUrl)) {
      return thumbnailUrl!.trim();
    }
    return '';
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final variantData = json['variant'] is Map<String, dynamic>
        ? json['variant'] as Map<String, dynamic>
        : null;

    final rawVariantId = variantData != null
        ? variantData['id']
        : json['variant_id'];

    final int? parsedVariantId = rawVariantId != null && rawVariantId != 0
        ? (rawVariantId is num ? rawVariantId.toInt() : int.tryParse(rawVariantId.toString()))
        : null;

    final productMap = json['product'] is Map ? (json['product'] as Map) : null;
    final rawProductId = json['product_id'] ?? (productMap != null ? productMap['id'] : null);

    String? vUrl = json['video_url']?.toString() ??
        json['video']?.toString() ??
        (productMap != null
            ? (productMap['video_url']?.toString() ??
                productMap['video']?.toString() ??
                productMap['hls_url']?.toString())
            : null);

    String? tUrl = json['thumbnail_url']?.toString() ??
        json['thumbnail']?.toString() ??
        (productMap != null
            ? (productMap['thumbnail_url']?.toString() ??
                productMap['thumbnail']?.toString() ??
                productMap['thumb_url']?.toString())
            : null);

    String? mImg = json['main_image']?.toString() ??
        (productMap != null ? productMap['main_image']?.toString() : null);

    final rawMedia = json['media'] ??
        json['product_media'] ??
        (productMap != null
            ? (productMap['media'] ?? productMap['product_media'])
            : null);

    if (rawMedia is List) {
      for (final item in rawMedia) {
        if (item is Map) {
          final mType = item['media_type']?.toString().toLowerCase().trim();
          final mUrl = item['media_url']?.toString() ??
              item['video_url']?.toString() ??
              item['file']?.toString();
          final itemThumb = item['thumbnail_url']?.toString() ??
              item['thumbnail']?.toString() ??
              item['thumb_url']?.toString();

          if (tUrl == null && itemThumb != null && itemThumb.isNotEmpty) {
            tUrl = itemThumb;
          }
          if (vUrl == null &&
              (mType == 'video' || isVideoUrl(mUrl)) &&
              mUrl != null &&
              mUrl.isNotEmpty) {
            vUrl = mUrl;
          }
          if (mImg == null && mType == 'image' && mUrl != null && mUrl.isNotEmpty) {
            mImg = mUrl;
          }
        }
      }
    }

    return CartItemModel(
      id: CartModel._parseInt(json['id']),
      productId: CartModel._parseInt(rawProductId),
      variantId: parsedVariantId,
      productName: (json['product_name'] ??
              (productMap != null ? productMap['product_name'] : ''))
          ?.toString() ??
          '',
      sellingPrice: CartModel._parseDouble(json['selling_price'] ??
          (productMap != null ? productMap['selling_price'] : null)),
      priceAfterDiscount: CartModel._parseDouble(json['price_after_discount'] ??
          (productMap != null ? productMap['price_after_discount'] : null)),
      mainImage: mImg,
      videoUrl: vUrl,
      thumbnailUrl: tUrl,
      quantity: CartModel._parseInt(json['quantity']),
      colorName: (variantData != null
              ? variantData['color_name']
              : json['color_name'])
          ?.toString(),
      colorCode: (variantData != null
              ? variantData['color_code']
              : json['color_code'])
          ?.toString(),
      size: (variantData != null ? variantData['size'] : json['size'])
          ?.toString(),
    );
  }
}
