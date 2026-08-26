import 'package:binetatour/data/models/order_detail_model.dart';

class OrderHistoryModel {
  final int id;
  final String orderNumber;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String totalAmount;
  final int itemCount;
  final List<String> productNames;
  final List<OrderItemModel>? items;
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
    this.items,
    required this.createdAt,
  });

  factory OrderHistoryModel.fromJson(Map<String, dynamic> json) {
    return OrderHistoryModel(
      id: OrderDetailModel.asInt(json['id']),
      orderNumber: json['order_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString() ?? '',
      totalAmount: json['total_amount']?.toString() ?? '0.00',
      itemCount: OrderDetailModel.asInt(json['item_count']),
      productNames: json['product_names'] is List
          ? (json['product_names'] as List).map((e) => e.toString()).toList()
          : [],
      items: json['items'] is List
          ? (json['items'] as List)
              .whereType<Map>()
              .map((i) => OrderItemModel.fromJson(Map<String, dynamic>.from(i)))
              .toList()
          : null,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
