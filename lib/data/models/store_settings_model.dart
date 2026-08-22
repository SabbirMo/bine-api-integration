class StoreSettingsModel {
  final String? deliveryMessage;

  StoreSettingsModel({this.deliveryMessage});

  factory StoreSettingsModel.fromJson(Map<String, dynamic> json) {
    return StoreSettingsModel(
      deliveryMessage: json['delivery_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'delivery_message': deliveryMessage};
  }
}
