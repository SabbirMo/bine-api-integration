import 'package:flutter/material.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiServices _apiServices = ApiServices();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  int _currentPage = 1;
  int get currentPage => _currentPage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications => _notifications;

  List<NotificationModel> _parseNotifications(dynamic data) {
    List<dynamic> list = [];
    if (data is List) {
      list = data;
    } else if (data is Map<String, dynamic>) {
      if (data['results'] is List) {
        list = data['results'];
      } else if (data['data'] is List) {
        list = data['data'];
      } else if (data['data'] is Map && data['data']['results'] is List) {
        list = data['data']['results'];
      } else if (data['notifications'] is List) {
        list = data['notifications'];
      }
    }

    return list
        .where((item) => item != null && item is Map)
        .map((item) => NotificationModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<dynamic> _getNotificationsApi(Map<String, dynamic> params) async {
    try {
      return await _apiServices.get(
        '/api/mobile/notifications/',
        queryParameters: params,
      );
    } catch (_) {
      // Fallback to legacy endpoint if mobile endpoint fails
      return await _apiServices.get(
        '/api/notifications/',
        queryParameters: params,
      );
    }
  }

  Future<void> fetchNotifications({
    bool forceRefresh = false,
    bool refresh = true,
  }) async {
    if (refresh || forceRefresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    if (_notifications.isEmpty || forceRefresh || refresh) {
      _isLoading = true;
      notifyListeners();
    }

    _errorMessage = null;

    try {
      final response = await _getNotificationsApi({'page': _currentPage});
      final dynamic data = response.data;
      final parsed = _parseNotifications(data);

      if (data is Map) {
        if (data['next'] != null) {
          _hasMore = true;
        } else if (parsed.length < 5) {
          _hasMore = false;
        } else {
          _hasMore = true;
        }
      } else {
        _hasMore = parsed.length >= 5;
      }

      if (refresh || forceRefresh) {
        _notifications = parsed;
      } else {
        for (final item in parsed) {
          if (!_notifications.any((n) => n.id == item.id)) {
            _notifications.add(item);
          }
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchNextNotifications() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final response = await _getNotificationsApi({'page': nextPage});
      final dynamic data = response.data;
      final parsed = _parseNotifications(data);

      if (parsed.isNotEmpty) {
        _currentPage = nextPage;
        for (final item in parsed) {
          if (!_notifications.any((n) => n.id == item.id)) {
            _notifications.add(item);
          }
        }
      }

      if (data is Map && data['next'] == null) {
        _hasMore = false;
      } else if (parsed.isEmpty || parsed.length < 5) {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('Error fetching next notifications: $e');
    } finally {
      _isLoadingMore = false;
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
