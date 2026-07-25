import 'package:flutter/material.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiServices _apiServices = ApiServices();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications => _notifications;

  Future<void> fetchNotifications({bool forceRefresh = false}) async {
    if (_notifications.isEmpty || forceRefresh) {
      _isLoading = true;
      notifyListeners();
    }

    _errorMessage = null;

    try {
      final response = await _apiServices.get('/api/notifications/');
      final dynamic data = response.data;

      if (data is List) {
        _notifications = data
            .map((item) => NotificationModel.fromJson(item))
            .toList();
      } else if (data is Map<String, dynamic> && data['results'] is List) {
        _notifications = (data['results'] as List)
            .map((item) => NotificationModel.fromJson(item))
            .toList();
      } else {
        _notifications = [];
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    final unreadIds = _notifications
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toList();

    if (unreadIds.isEmpty) return;

    // Optimistically update the UI state
    final previousNotifications = List<NotificationModel>.from(_notifications);
    _notifications = _notifications
        .map(
          (notification) => notification.isRead
              ? notification
              : notification.copyWith(isRead: true, readAt: DateTime.now()),
        )
        .toList();
    notifyListeners();

    try {
      await _apiServices.post(
        '/api/notifications/mark-all-read/',
        data: {'ids': unreadIds},
      );
    } catch (e) {
      // Rollback on error
      _notifications = previousNotifications;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  int get unreadCount => _notifications.where((item) => !item.isRead).length;

  void clearNotifications() {
    _notifications = [];
    _errorMessage = null;
    notifyListeners();
  }
}
