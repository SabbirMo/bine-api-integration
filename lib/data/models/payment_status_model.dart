class PaymentStatusModel {
  final int transactionId;
  final String status;
  final String orderNumber;

  PaymentStatusModel({
    required this.transactionId,
    required this.status,
    required this.orderNumber,
  });

  factory PaymentStatusModel.fromJson(Map<String, dynamic> json) {
    int parsedTxId = 0;
    if (json['transaction_id'] is int) {
      parsedTxId = json['transaction_id'];
    } else if (json['transaction_id'] != null) {
      parsedTxId = int.tryParse(json['transaction_id'].toString()) ?? 0;
    }

    return PaymentStatusModel(
      transactionId: parsedTxId,
      status: json['status']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction_id': transactionId,
      'status': status,
      'order_number': orderNumber,
    };
  }

  bool get isSuccess {
    final s = status.toLowerCase().trim();
    return s == 'success' ||
        s == 'successful' ||
        s == 'paid' ||
        s == 'completed' ||
        s == 'complete' ||
        s == 'done' ||
        s == 'validated';
  }

  bool get isFailed {
    final s = status.toLowerCase().trim();
    return s == 'failed' ||
        s == 'failure' ||
        s == 'cancelled' ||
        s == 'canceled' ||
        s == 'expired' ||
        s == 'error' ||
        s == 'rejected' ||
        s == 'declined';
  }

  bool get isPending => !isSuccess && !isFailed;
}
