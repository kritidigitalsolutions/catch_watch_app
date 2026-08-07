import 'package:catch_watch/data/network/api_network_service.dart';
import 'package:catch_watch/data/network/base_api_service.dart';
import 'package:catch_watch/res/appUrl.dart';

class UserRepository {
  final BaseApiService _apiService = NetworkApiService();

  Future<dynamic> searchUsers(String query) async {
    try {
      final response = await _apiService.getApi(AppUrl.searchUser(query));
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
