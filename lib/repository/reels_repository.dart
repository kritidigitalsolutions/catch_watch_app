import 'package:catch_watch/res/appUrl.dart';
import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';

class ReelsRepository {
  final BaseApiService _apiService = NetworkApiService();


  Future<dynamic> getMyReels({int page = 1, int limit = 10}) async {
    try {
      dynamic response = await _apiService.getApi('${AppUrl.myReels}?page=$page&limit=$limit');
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> getReelsFeed() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.reelsFeed);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> uploadReel(dynamic data, {Function(int, int)? onSendProgress}) async {
    try {
      if (_apiService is NetworkApiService) {
        return await (_apiService as NetworkApiService).postApiWithProgress(AppUrl.uploadReel, data, onSendProgress: onSendProgress);
      }
      dynamic response = await _apiService.postApi(AppUrl.uploadReel, data);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> getReelById(String id) async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.reelById(id));
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> searchReels(String query) async {
    try {
      dynamic response = await _apiService.getApi('${AppUrl.searchReels}?q=$query');
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> deleteReel(String id) async {
    try {
      dynamic response = await _apiService.deleteApi(AppUrl.deleteReel(id), null);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> recordReelView(String reelId, int watchDuration) async {
    try {
      final response = await _apiService.postApi(
        AppUrl.viewReel(reelId),
        {'watchDuration': watchDuration},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> incrementShares(String reelId) async {
    try {
      final response = await _apiService.postApi(AppUrl.shareReel(reelId), {});
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> getCommentCount(String reelId) async {
    try {
      final response = await _apiService.getApi(AppUrl.reelCommentCount(reelId));
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> saveReel(String reelId) async {
    try {
      final response = await _apiService.postApi(AppUrl.saveReel(reelId), {});
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> unsaveReel(String reelId) async {
    try {
      final response = await _apiService.postApi(AppUrl.unsaveReel(reelId), {});
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> recordAdEvent({
    required String adId,
    required String campaignId,
    required String eventType,
    int? watchDuration,
  }) async {
    try {
      final response = await _apiService.postApi(
        AppUrl.adEvent,
        {
          'adId': adId,
          'campaignId': campaignId,
          'eventType': eventType,
          if (watchDuration != null) 'watchDuration': watchDuration,
        },
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
