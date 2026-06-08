class OrderHistoryModel {
  final int id;
  final String orderNumber;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String totalAmount;
  final int itemCount;
  final List<String> productNames;
  final String createdAt;

  OrderHistoryModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.totalAmount,
    required this.itemCount,
    required this.productNames,
    required this.createdAt,
  });

  factory OrderHistoryModel.fromJson(Map<String, dynamic> json) {
    return OrderHistoryModel(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? '',
      paymentMethod: json['payment_method'] ?? '',
      paymentStatus: json['payment_status'] ?? '',
      totalAmount: json['total_amount']?.toString() ?? '0.00',
      itemCount: json['item_count'] ?? 0,
      productNames: json['product_names'] != null
          ? List<String>.from(json['product_names'])
          : [],
      createdAt: json['created_at'] ?? '',
    );
  }
}
