import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/live_show_model.dart';
import '../res/appUrl.dart';

class LiveShowRepository {
  final BaseApiService _apiService = NetworkApiService();

  Future<LiveShowsResponse> getShows({
    String status = 'LIVE',
    String category = 'ALL',
    String search = '',
    int limit = 20,
    int page = 1,
  }) async {
    try {
      String url = '${AppUrl.liveShows}?status=$status&category=$category&search=$search&limit=$limit&page=$page';
      dynamic response = await _apiService.getApi(url);
      return LiveShowsResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<LiveShow?> getFeaturedShow() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.featuredLiveShow);
      if (response is Map) {
        final data = response['data'] ?? response['show'] ?? response['featuredShow'] ?? response;
        if (data is Map) {
          return LiveShow.fromJson(Map<String, dynamic>.from(data));
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<LiveShow?> getShowDetails(String showId) async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.liveShowDetails(showId));
      if (response is Map) {
        final data = response['data'] ?? response['show'] ?? response['match'] ?? response;
        if (data is Map) {
          return LiveShow.fromJson(Map<String, dynamic>.from(data));
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> pingViewCount(String showId) async {
    try {
      await _apiService.postApi(AppUrl.liveShowViewHeartbeat(showId), {});
    } catch (e) {
      // Non-blocking
    }
  }
}
