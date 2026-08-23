import 'package:binetatour/data/models/product_model.dart' show MediaModel;

class HomeResponseModel {
  final BannerModel? banner;
  final String? storeAddress;
  final List<StoryCategoryModel> storyCategories;
  final List<ProductSectionModel> productSections;

  HomeResponseModel({
    this.banner,
    this.storeAddress,
    required this.storyCategories,
    required this.productSections,
  });

  factory HomeResponseModel.fromJson(Map<String, dynamic> json) {
    return HomeResponseModel(
      banner: json['banner'] != null
          ? BannerModel.fromJson(json['banner'])
          : null,
      storeAddress: json['store_address'],
      storyCategories:
          (json['story_categories'] as List?)
              ?.map((e) => StoryCategoryModel.fromJson(e))
              .toList() ??
          [],
      productSections:
          (json['product_sections'] as List?)
              ?.map((e) => ProductSectionModel.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class BannerModel {
  final int id;
  final String? videoUrl;
  final String? hlsUrl;
  final String? thumbnailUrl;

  BannerModel({
    required this.id,
    this.videoUrl,
    this.hlsUrl,
    this.thumbnailUrl,
  });

  String get effectiveVideoUrl {
    if (videoUrl != null && videoUrl!.trim().isNotEmpty) {
      return videoUrl!;
    }
    if (hlsUrl != null && hlsUrl!.trim().isNotEmpty) {
      return hlsUrl!;
    }
    return '';
  }

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'],
      videoUrl: json['video_url'],
      hlsUrl: json['hls_url'],
      thumbnailUrl: json['thumbnail_url'],
    );
  }
}

class StoryCategoryModel {
  final int id;
  final String? name;
  final String? imageUrl;
  final String? type;
  final List<StoryModel> stories;

  StoryCategoryModel({
    required this.id,
    this.name,
    this.imageUrl,
    this.type,
    required this.stories,
  });

  factory StoryCategoryModel.fromJson(Map<String, dynamic> json) {
    return StoryCategoryModel(
      id: json['id'],
      name: json['name'],
      imageUrl: json['image_url'],
      type: json['type'],
      stories:
          (json['stories'] as List?)
              ?.map((e) => StoryModel.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class StoryModel {
  final int id;
  final String? contentType;
  final String? mediaUrl;
  final String? hlsUrl;
  final String? thumbnailUrl;
  final String? createdAt;

  StoryModel({
    required this.id,
    this.contentType,
    this.mediaUrl,
    this.hlsUrl,
    this.thumbnailUrl,
    this.createdAt,
  });

  String get effectiveMediaUrl {
    if (mediaUrl != null && mediaUrl!.trim().isNotEmpty) {
      return mediaUrl!;
    }
    if (hlsUrl != null && hlsUrl!.trim().isNotEmpty) {
      return hlsUrl!;
    }
    return '';
  }

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'] ?? 0,
      contentType: json['content_type'],
      mediaUrl: json['media_url'],
      hlsUrl: json['hls_url'],
      thumbnailUrl: json['thumbnail_url'],
      createdAt: json['created_at'],
    );
  }
}

class ProductSectionModel {
  final int categoryId;
  final String? categoryName;
  final String? categoryImageUrl;
  final List<ProductModel> products;

  ProductSectionModel({
    required this.categoryId,
    this.categoryName,
    this.categoryImageUrl,
    required this.products,
  });

  factory ProductSectionModel.fromJson(Map<String, dynamic> json) {
    return ProductSectionModel(
      categoryId: json['category_id'],
      categoryName: json['category_name'],
      categoryImageUrl: json['category_image_url'],
      products:
          (json['products'] as List?)
              ?.map((e) => ProductModel.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class ProductModel {
  final int id;
  final String? productName;
  final String? sellingPrice;
  final String? discountPercentage;
  final String? priceAfterDiscount;
  final String? status;
  final String? mainImage;
  final String? videoUrl;
  final String? hlsUrl;
  final String? thumbnailUrl;
  final List<MediaModel>? media;

  ProductModel({
    required this.id,
    this.productName,
    this.sellingPrice,
    this.discountPercentage,
    this.priceAfterDiscount,
    this.status,
    this.mainImage,
    this.videoUrl,
    this.hlsUrl,
    this.thumbnailUrl,
    this.media,
  });

  List<MediaModel> get safeMedia => media ?? const <MediaModel>[];

  String get effectiveVideoUrl {
    if (videoUrl != null && videoUrl!.trim().isNotEmpty) {
      return videoUrl!;
    }
    if (hlsUrl != null && hlsUrl!.trim().isNotEmpty) {
      return hlsUrl!;
    }
    for (final m in safeMedia) {
      if (m.mediaType.toLowerCase() == 'video' &&
          m.effectiveMediaUrl.isNotEmpty) {
        return m.effectiveMediaUrl;
      }
    }
    if (mainImage != null) {
      final imgLower = mainImage!.toLowerCase().trim();
      if (imgLower.endsWith('.mp4') ||
          imgLower.endsWith('.mov') ||
          imgLower.endsWith('.m3u8') ||
          imgLower.endsWith('.webm') ||
          imgLower.contains('.mp4?')) {
        return mainImage!;
      }
    }
    return '';
  }

  String get effectiveThumbnailUrl {
    if (mainImage != null && mainImage!.trim().isNotEmpty) {
      return mainImage!;
    }
    if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty) {
      return thumbnailUrl!;
    }
    for (final m in safeMedia) {
      if (m.thumbnailUrl != null && m.thumbnailUrl!.trim().isNotEmpty) {
        return m.thumbnailUrl!;
      }
      if (m.mediaType.toLowerCase() == 'image' &&
          m.effectiveMediaUrl.isNotEmpty) {
        return m.effectiveMediaUrl;
      }
    }
    return '';
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['product_media'] ?? json['media'];
    final List<MediaModel> parsedMedia = [];
    if (rawMedia is List) {
      for (final item in rawMedia) {
        if (item != null && item is Map) {
          try {
            parsedMedia.add(
              MediaModel.fromJson(Map<String, dynamic>.from(item)),
            );
          } catch (_) {}
        }
      }
    }

    String? vUrl = json['video_url']?.toString() ?? json['video']?.toString();
    String? hUrl = json['hls_url']?.toString();
    String? tUrl =
        json['thumbnail_url']?.toString() ?? json['thumbnail']?.toString();

    return ProductModel(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      productName: json['product_name']?.toString(),
      sellingPrice: json['selling_price']?.toString(),
      discountPercentage: json['discount_percentage']?.toString(),
      priceAfterDiscount: json['price_after_discount']?.toString(),
      status: json['status']?.toString(),
      mainImage: json['main_image']?.toString(),
      videoUrl: vUrl,
      hlsUrl: hUrl,
      thumbnailUrl: tUrl,
      media: parsedMedia,
    );
  }
}
