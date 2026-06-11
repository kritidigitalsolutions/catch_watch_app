import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/content_model.dart';
import '../res/appUrl.dart';

class ContentRepository {
  final BaseApiService _apiService = NetworkApiService();

  Future<ContentModel> getContent() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getContent);
      return ContentModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }
}
