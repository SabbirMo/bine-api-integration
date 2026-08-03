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

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    return OrderDetailModel(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      trackingSteps: json['tracking_steps'] != null
          ? (json['tracking_steps'] as List)
                .map((i) => TrackingStepModel.fromJson(i))
                .toList()
          : [],
      items: json['items'] != null
          ? (json['items'] as List)
                .map((i) => OrderItemModel.fromJson(i))
                .toList()
          : [],
      customerName: json['customer_name'] ?? '',
      customerSurname: json['customer_surname'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      customerPhone2: json['customer_phone2'] ?? '',
      customerAddress: json['customer_address'] ?? '',
      deliveryDate: json['delivery_date'] ?? '',
      deliveryTime: json['delivery_time'] ?? '',
      deliveryTimeEnd: json['delivery_time_end'] ?? '',
      deliveryNote: json['delivery_note'] ?? '',
      deliveryFee: json['delivery_fee']?.toString() ?? '0.00',
      paymentMethod: json['payment_method'] ?? '',
      paymentStatus: json['payment_status'] ?? '',
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
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      description: json['description'] ?? '',
      state: json['state'] ?? '',
      timestamp: json['timestamp'],
    );
  }
}

class OrderItemModel {
  final int id;
  final int productId;
  final String productName;
  final String mainImage;
  final int variantId;
  final String colorName;
  final String colorCode;
  final String size;
  final int quantity;
  final String unitPrice;
  final double subtotal;

  OrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.mainImage,
    required this.variantId,
    required this.colorName,
    required this.colorCode,
    required this.size,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      mainImage: json['main_image'] ?? '',
      variantId: json['variant_id'] ?? 0,
      colorName: json['color_name'] ?? '',
      colorCode: json['color_code'] ?? '',
      size: json['size'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: json['unit_price']?.toString() ?? '0.00',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
