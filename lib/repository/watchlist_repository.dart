import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/watchlist_model.dart';
import '../res/appUrl.dart';

class WatchlistRepository {
  final BaseApiService _apiService = NetworkApiService();

  Future<WatchlistResponse> getWatchlist() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.watchlist);
      return WatchlistResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> addToWatchlist(String itemId) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.addToWatchlist, {'itemId': itemId});
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> removeFromWatchlist(String id) async {
    try {
      dynamic response = await _apiService.deleteApi('${AppUrl.watchlist}/$id', null);
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
