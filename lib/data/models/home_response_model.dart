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
  final String? thumbnailUrl;

  BannerModel({required this.id, this.videoUrl, this.thumbnailUrl});

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'],
      videoUrl: json['video_url'],
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
  final String? thumbnailUrl;
  final String? createdAt;

  StoryModel({
    required this.id,
    this.contentType,
    this.mediaUrl,
    this.thumbnailUrl,
    this.createdAt,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'] ?? 0,
      contentType: json['content_type'],
      mediaUrl: json['media_url'],
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
  final double? priceAfterDiscount;
  final String? status;
  final String? mainImage;

  ProductModel({
    required this.id,
    this.productName,
    this.sellingPrice,
    this.discountPercentage,
    this.priceAfterDiscount,
    this.status,
    this.mainImage,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      productName: json['product_name'],
      sellingPrice: json['selling_price'],
      discountPercentage: json['discount_percentage'],
      priceAfterDiscount: json['price_after_discount'] != null
          ? double.tryParse(json['price_after_discount'].toString())
          : null,
      status: json['status'],
      mainImage: json['main_image'],
    );
  }
}
