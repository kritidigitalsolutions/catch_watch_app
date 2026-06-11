import 'package:catch_watch/models/notification_model.dart';
import 'package:catch_watch/repository/notification_repository.dart';
import 'package:flutter/material.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _notificationRepository = NotificationRepository();

  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  String? _error;

  List<NotificationItem> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get unreadCount => _notifications.where((n) => n.isRead == false).length;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _notificationRepository.getNotifications();
      if (response.success == true) {
        _notifications = response.notifications ?? [];
      } else {
        _error = 'Failed to load notifications';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _notificationRepository.markNotificationRead(id);
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index].isRead = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _notificationRepository.markAllNotificationsRead();
      for (var n in _notifications) {
        n.isRead = true;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<bool> deleteNotification(String id) async {
    try {
      await _notificationRepository.deleteNotification(id);
      _notifications.removeWhere((n) => n.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return false;
    }
  }

  Future<bool> deleteAllNotifications() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _notificationRepository.deleteAllNotifications();
      _notifications.clear();
      return true;
    } catch (e) {
      debugPrint('Error deleting all notifications: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
