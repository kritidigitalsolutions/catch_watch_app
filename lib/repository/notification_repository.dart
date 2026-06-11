import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/notification_model.dart';
import '../res/appUrl.dart';

class NotificationRepository {
  final BaseApiService _apiService = NetworkApiService();

  Future<NotificationResponse> getNotifications() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getNotifications);
      return NotificationResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> markNotificationRead(String id) async {
    try {
      dynamic response = await _apiService.patchApi(AppUrl.markNotificationRead(id), null);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> markAllNotificationsRead() async {
    try {
      dynamic response = await _apiService.patchApi(AppUrl.markAllNotificationsRead, null);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> deleteNotification(String id) async {
    try {
      dynamic response = await _apiService.deleteApi(AppUrl.deleteNotification(id), null);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> deleteAllNotifications() async {
    try {
      dynamic response = await _apiService.deleteApi(AppUrl.deleteAllNotifications, null);
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
