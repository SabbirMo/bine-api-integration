class NotificationModel {
  final int id;
  final String title;
  final String body;
  final String notificationType;
  final dynamic data;
  final bool isRead;
  final DateTime? readAt;
  final String pushStatus;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.notificationType,
    required this.data,
    required this.isRead,
    required this.readAt,
    required this.pushStatus,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: _asInt(json['id']),
      title: _asString(json['title']),
      body: _asString(json['body']),
      notificationType: _asString(json['notification_type'], 'general'),
      data: json['data'],
      isRead: json['is_read'] == true,
      readAt: _parseDateTime(json['read_at']),
      pushStatus: _asString(json['push_status']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  NotificationModel copyWith({bool? isRead, DateTime? readAt}) {
    return NotificationModel(
      id: id,
      title: title,
      body: body,
      notificationType: notificationType,
      data: data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      pushStatus: pushStatus,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static String _asString(dynamic value, [String fallback = '']) {
    if (value == null) {
      return fallback;
    }

    if (value is String) {
      return value;
    }

    return value.toString();
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
