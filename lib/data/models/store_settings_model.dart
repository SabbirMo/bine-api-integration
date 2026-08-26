class StoreSettingsModel {
  final String? deliveryMessage;
  final String? deliveryHeading;

  StoreSettingsModel({this.deliveryMessage, this.deliveryHeading});

  factory StoreSettingsModel.fromJson(Map<String, dynamic> json) {
    return StoreSettingsModel(
      deliveryMessage: json['delivery_message']?.toString(),
      deliveryHeading: json['delivery_heading']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'delivery_message': deliveryMessage,
      'delivery_heading': deliveryHeading,
    };
  }
}
