class OrderDetailModel {
  final int id;
  final String orderNumber;
  final String status;
  final String createdAt;
  final List<TrackingStepModel> trackingSteps;
  final List<OrderItemModel> items;
  final String customerName;
  final String customerSurname;
  final String customerPhone;
  final String customerPhone2;
  final String customerAddress;
  final String deliveryDate;
  final String deliveryTime;
  final String deliveryTimeEnd;
  final String deliveryNote;
  final String deliveryFee;
  final String paymentMethod;
  final String paymentStatus;
  final String subtotalAmount;
  final String totalAmount;

  OrderDetailModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.createdAt,
    required this.trackingSteps,
    required this.items,
    required this.customerName,
    required this.customerSurname,
    required this.customerPhone,
    required this.customerPhone2,
    required this.customerAddress,
    required this.deliveryDate,
    required this.deliveryTime,
    required this.deliveryTimeEnd,
    required this.deliveryNote,
    required this.deliveryFee,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotalAmount,
    required this.totalAmount,
  });

  static int asInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double asDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) {
      final clean = value.replaceAll(' ', '').replaceAll(',', '.').trim();
      return double.tryParse(clean) ?? fallback;
    }
    return fallback;
  }

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    return OrderDetailModel(
      id: asInt(json['id']),
      orderNumber: json['order_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      trackingSteps: json['tracking_steps'] is List
          ? (json['tracking_steps'] as List)
              .whereType<Map>()
              .map((i) => TrackingStepModel.fromJson(Map<String, dynamic>.from(i)))
              .toList()
          : [],
      items: json['items'] is List
          ? (json['items'] as List)
              .whereType<Map>()
              .map((i) => OrderItemModel.fromJson(Map<String, dynamic>.from(i)))
              .toList()
          : [],
      customerName: json['customer_name']?.toString() ?? '',
      customerSurname: json['customer_surname']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? '',
      customerPhone2: json['customer_phone2']?.toString() ?? '',
      customerAddress: json['customer_address']?.toString() ?? '',
      deliveryDate: json['delivery_date']?.toString() ?? '',
      deliveryTime: json['delivery_time']?.toString() ?? '',
      deliveryTimeEnd: json['delivery_time_end']?.toString() ?? '',
      deliveryNote: json['delivery_note']?.toString() ?? '',
      deliveryFee: json['delivery_fee']?.toString() ?? '0.00',
      paymentMethod: json['payment_method']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString() ?? '',
      subtotalAmount: json['subtotal_amount']?.toString() ?? '0.00',
      totalAmount: json['total_amount']?.toString() ?? '0.00',
    );
  }
}

class TrackingStepModel {
  final String key;
  final String label;
  final String description;
  final String state;
  final String? timestamp;

  TrackingStepModel({
    required this.key,
    required this.label,
    required this.description,
    required this.state,
    this.timestamp,
  });

  factory TrackingStepModel.fromJson(Map<String, dynamic> json) {
    return TrackingStepModel(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      timestamp: json['timestamp']?.toString(),
    );
  }
}

class OrderItemModel {
  final int id;
  final int productId;
  final String productName;
  final String mainImage;
  final int? variantId;
  final String? colorName;
  final String? colorCode;
  final String? size;
  final int quantity;
  final String unitPrice;
  final double subtotal;
  final bool isReviewed;
  final int? reviewId;

  OrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.mainImage,
    this.variantId,
    this.colorName,
    this.colorCode,
    this.size,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.isReviewed = false,
    this.reviewId,
  });

  bool get hasVariant =>
      (colorName != null && colorName!.isNotEmpty) ||
      (size != null && size!.isNotEmpty) ||
      (variantId != null && variantId! > 0);

  String get variantDescription {
    final parts = <String>[];
    if (colorName != null && colorName!.isNotEmpty) parts.add(colorName!);
    if (size != null && size!.isNotEmpty) parts.add("Taille: $size");
    return parts.isNotEmpty ? parts.join(" ") : "Sans préférence";
  }

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final variantData = json['variant'] is Map
        ? Map<String, dynamic>.from(json['variant'] as Map)
        : null;

    final rawVariantId = variantData != null
        ? variantData['id']
        : json['variant_id'];

    final int? parsedVariantId = rawVariantId != null && rawVariantId != 0
        ? (rawVariantId is num
            ? rawVariantId.toInt()
            : int.tryParse(rawVariantId.toString()))
        : null;

    final rawProductId = json['product_id'] ??
        (json['product'] is Map ? (json['product'] as Map)['id'] : null);
    final int parsedProductId = OrderDetailModel.asInt(rawProductId);

    final rawReviewId = json['review_id'];
    final int? parsedReviewId = rawReviewId != null
        ? OrderDetailModel.asInt(rawReviewId)
        : null;

    return OrderItemModel(
      id: OrderDetailModel.asInt(json['id']),
      productId: parsedProductId,
      productName: (json['product_name'] ??
              (json['product'] is Map
                  ? (json['product'] as Map)['product_name']
                  : ''))
          ?.toString() ??
          '',
      mainImage: (json['main_image'] ??
              (json['product'] is Map
                  ? (json['product'] as Map)['main_image']
                  : ''))
          ?.toString() ??
          '',
      variantId: parsedVariantId,
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
      quantity: OrderDetailModel.asInt(json['quantity']),
      unitPrice: json['unit_price']?.toString() ?? '0.00',
      subtotal: OrderDetailModel.asDouble(json['subtotal']),
      isReviewed: json['is_reviewed'] == true,
      reviewId: parsedReviewId,
    );
  }
}
