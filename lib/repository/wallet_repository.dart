import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/creator_dashboard_model.dart';
import '../models/leaderboard_model.dart';
import '../models/wallet_model.dart';
import '../res/appUrl.dart';

class WalletRepository {
  final BaseApiService _apiService = NetworkApiService();

  Future<CreatorDashboardData> getDashboardData({String? range}) async {
    try {
      String url = AppUrl.creatorDashboard;
      if (range != null) {
        url += '?range=$range';
      }
      dynamic response = await _apiService.getApi(url);
      return CreatorDashboardData.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<LeaderboardResponse> getLeaderboard({String? range}) async {
    try {
      String url = AppUrl.creatorLeaderboard;
      if (range != null) {
        url += '?timeframe=$range';
      }
      dynamic response = await _apiService.getApi(url);
      return LeaderboardResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<WalletSummary> getWalletSummary() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.creatorWallet);
      return WalletSummary.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> redeemPoints(dynamic data) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.creatorRedeem, data);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, List<RedeemHistory>>> getRedeemHistory() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.creatorRedeemHistory);
      
      final List<RedeemHistory> history = (response['history'] as List? ?? [])
          .map((e) => RedeemHistory.fromJson(e))
          .toList();
          
      final List<RedeemHistory> requests = (response['requests'] as List? ?? [])
          .map((e) => RedeemHistory.fromJson(e))
          .toList();
          
      return {
        'history': history,
        'requests': requests,
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<PointsSummary> getPointsSummary() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.creatorPoints);
      return PointsSummary.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PointHistoryLog>> getPointHistory() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.creatorPointHistory);
      return (response['history'] as List).map((e) => PointHistoryLog.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }
}
