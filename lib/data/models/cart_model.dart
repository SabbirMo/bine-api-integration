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
    required this.quantity,
    this.colorName,
    this.colorCode,
    this.size,
  });

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

    return CartItemModel(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? (json['product'] is Map ? json['product']['id'] ?? 0 : 0),
      variantId: parsedVariantId,
      productName: json['product_name'] ?? (json['product'] is Map ? json['product']['product_name'] ?? '' : ''),
      sellingPrice: CartModel._parseDouble(json['selling_price'] ?? (json['product'] is Map ? json['product']['selling_price'] : null)),
      priceAfterDiscount: CartModel._parseDouble(json['price_after_discount'] ?? (json['product'] is Map ? json['product']['price_after_discount'] : null)),
      mainImage: json['main_image'] ?? (json['product'] is Map ? json['product']['main_image'] : null),
      quantity: json['quantity'] ?? 0,
      colorName: variantData != null ? variantData['color_name'] : json['color_name'],
      colorCode: variantData != null ? variantData['color_code'] : json['color_code'],
      size: variantData != null ? variantData['size'] : json['size'],
    );
  }
}
