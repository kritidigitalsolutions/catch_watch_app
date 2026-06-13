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
      dynamic response = await _apiService.getApi('${AppUrl.searchReels}?caption=$query');
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
}
