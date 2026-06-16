class NotificationModel {
  final int id;
  final String title;
  final String body;
  final String notificationType;
  final String data;
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
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      notificationType: json['notification_type'] ?? 'general',
      data: json['data'] ?? '',
      isRead: json['is_read'] ?? false,
      readAt: _parseDateTime(json['read_at']),
      pushStatus: json['push_status'] ?? '',
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
}
