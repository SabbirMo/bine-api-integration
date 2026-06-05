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
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? 0,
      productName: json['product_name'] ?? '',
      categoryId: json['category_id'] ?? 0,
      categoryName: json['category_name'] ?? '',
      subcategoryId: json['subcategory_id'],
      subcategoryName: json['subcategory_name'],
      sellingPrice: json['selling_price']?.toString() ?? '0',
      discountPercentage: json['discount_percentage']?.toString() ?? '0',
      priceAfterDiscount:
          (json['price_after_discount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? '',
      mainImage: json['main_image'],
      media: json['media'] != null
          ? (json['media'] as List).map((i) => MediaModel.fromJson(i)).toList()
          : [],
      actualPrice: json['actual_price']?.toString(),
      deliveryPrice: json['delivery_price']?.toString(),
      description: json['description'],
      deliveryMessage: json['delivery_message'],
      variants: json['variants'] != null
          ? (json['variants'] as List)
                .map((i) => ProductVariantModel.fromJson(i))
                .toList()
          : [],
      createdAt: json['created_at'],
    );
  }
}

class MediaModel {
  final int id;
  final String mediaType; // "image", "video", "audio"
  final String mediaUrl;

  MediaModel({
    required this.id,
    required this.mediaType,
    required this.mediaUrl,
  });

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    return MediaModel(
      id: json['id'] ?? 0,
      mediaType: json['media_type'] ?? '',
      mediaUrl: json['media_url'] ?? '',
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
      id: json['id'] ?? 0,
      colorName: json['color_name'] ?? '',
      colorCode: json['color_code'] ?? '',
      size: json['size'] ?? '',
      stockQuantity: json['stock_quantity'] ?? 0,
    );
  }
}
