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
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class CartItemModel {
  final int id;
  final int productId;
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
    return CartItemModel(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      sellingPrice: CartModel._parseDouble(json['selling_price']),
      priceAfterDiscount: CartModel._parseDouble(json['price_after_discount']),
      mainImage: json['main_image'],
      quantity: json['quantity'] ?? 0,
      colorName: json['color_name'],
      colorCode: json['color_code'],
      size: json['size'],
    );
  }
}
