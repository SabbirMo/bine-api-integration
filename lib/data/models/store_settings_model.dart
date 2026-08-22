class StoreSettingsModel {
  final String? deliveryMessage;
  final String? deliveryHeading;

  StoreSettingsModel({this.deliveryMessage, this.deliveryHeading});

  factory StoreSettingsModel.fromJson(Map<String, dynamic> json) {
    return StoreSettingsModel(
      deliveryMessage: json['delivery_message'] as String?,
      deliveryHeading: json['delivery_heading'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'delivery_message': deliveryMessage,
      'delivery_heading': deliveryHeading,
    };
  }
}
