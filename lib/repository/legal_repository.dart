import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/legal_model.dart';
import '../models/help_model.dart';
import '../res/appUrl.dart';

class LegalRepository {
  final BaseApiService _apiService = NetworkApiService();

  Future<LegalResponse> getLegalDocuments() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getLegal);
      return LegalResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<HelpResponse> getHelpData() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getHelp);
      return HelpResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }
}
