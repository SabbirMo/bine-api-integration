import 'package:binetatour/core/utils/media_url_resolver.dart';

class CartModel {
  final List<CartItemModel> items;
  String total;

  CartModel({required this.items, required this.total});

  factory CartModel.fromJson(Map<String, dynamic> json) {
    final rawItems =
        (json['items'] ??
                json['results'] ??
                (json['data'] is Map
                    ? (json['data']['items'] ?? json['data']['results'])
                    : (json['data'] is List ? json['data'] : null)))
            as List?;

    return CartModel(
      items:
          rawItems
              ?.where((item) => item != null && item is Map)
              .map(
                (item) => CartItemModel.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList() ??
          [],
      total:
          (json['total'] ??
                  json['total_amount'] ??
                  json['total_price'] ??
                  (json['data'] is Map
                      ? (json['data']['total'] ??
                            json['data']['total_amount'] ??
                            json['data']['total_price'])
                      : null) ??
                  '')
              .toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      'total': total,
    };
  }

  static int _parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class CartItemModel {
  final int id;
  final int productId;
  final int? variantId;
  final String productName;
  final String sellingPrice;
  final String priceAfterDiscount;
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

  String get effectivePrice {
    if (priceAfterDiscount.isNotEmpty &&
        priceAfterDiscount != '0' &&
        priceAfterDiscount != '0.0' &&
        priceAfterDiscount != '0.00') {
      return priceAfterDiscount;
    }
    if (sellingPrice.isNotEmpty &&
        sellingPrice != '0' &&
        sellingPrice != '0.0' &&
        sellingPrice != '0.00') {
      return sellingPrice;
    }
    return priceAfterDiscount.isNotEmpty ? priceAfterDiscount : sellingPrice;
  }

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
    if (thumbnailUrl != null &&
        thumbnailUrl!.trim().isNotEmpty &&
        !isVideoUrl(thumbnailUrl)) {
      return thumbnailUrl!.trim();
    }
    if (mainImage != null &&
        mainImage!.trim().isNotEmpty &&
        !isVideoUrl(mainImage)) {
      return mainImage!.trim();
    }
    if (effectiveVideoUrl.isNotEmpty) {
      final extracted =
          MediaUrlResolver.extractThumbnailFromVideoUrl(effectiveVideoUrl);
      if (extracted.isNotEmpty) return extracted;
    }
    return '';
  }

  String get effectiveVideoUrl {
    if (videoUrl != null && videoUrl!.trim().isNotEmpty) {
      return videoUrl!.trim();
    }
    if (mainImage != null &&
        mainImage!.trim().isNotEmpty &&
        isVideoUrl(mainImage)) {
      return mainImage!.trim();
    }
    if (thumbnailUrl != null &&
        thumbnailUrl!.trim().isNotEmpty &&
        isVideoUrl(thumbnailUrl)) {
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
        ? (rawVariantId is num
              ? rawVariantId.toInt()
              : int.tryParse(rawVariantId.toString()))
        : null;

    final productMap = json['product'] is Map ? (json['product'] as Map) : null;
    final rawProductId = json['product_id'] ??
        (productMap != null
            ? productMap['id']
            : (json['product'] is num || json['product'] is String
                ? json['product']
                : null));

    String? vUrl =
        json['video_url']?.toString() ??
        json['video']?.toString() ??
        (productMap != null
            ? (productMap['video_url']?.toString() ??
                  productMap['video']?.toString() ??
                  productMap['hls_url']?.toString())
            : null);

    String? tUrl =
        json['thumbnail_url']?.toString() ??
        json['thumbnail']?.toString() ??
        (productMap != null
            ? (productMap['thumbnail_url']?.toString() ??
                  productMap['thumbnail']?.toString() ??
                  productMap['thumb_url']?.toString())
            : null);

    String? mImg =
        json['main_image']?.toString() ??
        (productMap != null ? productMap['main_image']?.toString() : null);

    final rawMedia =
        json['media'] ??
        json['product_media'] ??
        (productMap != null
            ? (productMap['media'] ?? productMap['product_media'])
            : null);

    if (rawMedia is List) {
      for (final item in rawMedia) {
        if (item is Map) {
          final mType = item['media_type']?.toString().toLowerCase().trim();
          final mUrl =
              item['media_url']?.toString() ??
              item['video_url']?.toString() ??
              item['file']?.toString();
          final itemThumb =
              item['thumbnail_url']?.toString() ??
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
          if (mImg == null &&
              mType == 'image' &&
              mUrl != null &&
              mUrl.isNotEmpty) {
            mImg = mUrl;
          }
        }
      }
    }

    if ((tUrl == null || tUrl.isEmpty) && vUrl != null && vUrl.isNotEmpty) {
      final extracted = MediaUrlResolver.extractThumbnailFromVideoUrl(vUrl);
      if (extracted.isNotEmpty) {
        tUrl = extracted;
      }
    }

    final rawSellingPrice =
        json['selling_price'] ??
        json['price'] ??
        json['item_price'] ??
        (productMap != null
            ? (productMap['selling_price'] ?? productMap['price'])
            : null);

    final rawPriceAfterDiscount =
        json['price_after_discount'] ??
        json['discount_price'] ??
        json['price'] ??
        json['item_price'] ??
        (productMap != null
            ? (productMap['price_after_discount'] ??
                  productMap['discount_price'] ??
                  productMap['selling_price'] ??
                  productMap['price'])
            : null);

    return CartItemModel(
      id: CartModel._parseInt(json['id']),
      productId: CartModel._parseInt(rawProductId),
      variantId: parsedVariantId,
      productName:
          (json['product_name'] ??
                  (productMap != null ? productMap['product_name'] : ''))
              ?.toString() ??
          '',
      sellingPrice: (rawSellingPrice ?? '').toString(),
      priceAfterDiscount: (rawPriceAfterDiscount ?? '').toString(),
      mainImage: mImg,
      videoUrl: vUrl,
      thumbnailUrl: tUrl,
      quantity: CartModel._parseInt(json['quantity']),
      colorName:
          (variantData != null ? variantData['color_name'] : json['color_name'])
              ?.toString(),
      colorCode:
          (variantData != null ? variantData['color_code'] : json['color_code'])
              ?.toString(),
      size: (variantData != null ? variantData['size'] : json['size'])
          ?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'variant_id': variantId,
      'product_name': productName,
      'selling_price': sellingPrice,
      'price_after_discount': priceAfterDiscount,
      'main_image': mainImage,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'quantity': quantity,
      'color_name': colorName,
      'color_code': colorCode,
      'size': size,
    };
  }
}
