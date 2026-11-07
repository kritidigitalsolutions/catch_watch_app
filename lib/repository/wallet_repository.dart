import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/creator_dashboard_model.dart';
import '../models/leaderboard_model.dart';
import '../models/wallet_model.dart';
import '../res/appUrl.dart';

class WalletRepository {
  final BaseApiService _apiService = NetworkApiService();

  /// Resolves the effective payload from a `/creator/*` response.
  ///
  /// The backend may return the payload either at the top level (`{...}`) or
  /// wrapped in an envelope (`{success: true, data: {...}}` / `{data: [...]}`).
  /// Only a Map/List `data` value is treated as an envelope so a top-level
  /// response carrying an unrelated `data` scalar/null is left untouched.
  ///
  /// Returns `null` when the body is not a usable Map or List.
  static dynamic _unwrapPayload(dynamic response) {
    if (response is Map) {
      final dynamic data = response['data'];
      if (data is Map || data is List) return data;
      return response;
    }
    if (response is List) return response;
    return null;
  }

  /// Unwraps [response] and requires the result to be a JSON object.
  ///
  /// Throws a [FormatException] when the payload is missing or of an unexpected
  /// structure so the provider surfaces an error instead of rendering zeroed
  /// (but valid-looking) balances.
  static Map<String, dynamic> _requireMap(dynamic response, String endpoint) {
    final dynamic payload = _unwrapPayload(response);
    if (payload is Map) return Map<String, dynamic>.from(payload);
    throw FormatException('Unexpected response structure for $endpoint');
  }

  Future<CreatorDashboardData> getDashboardData({String? range}) async {
    try {
      String url = AppUrl.creatorDashboard;
      if (range != null) {
        url += '?range=$range';
      }
      dynamic response = await _apiService.getApi(url);
      return CreatorDashboardData.fromJson(
        _requireMap(response, AppUrl.creatorDashboard),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<LeaderboardResponse> getLeaderboard({String? range}) async {
    try {
      String url = AppUrl.creatorLeaderboard;
      if (range != null) {
        url += '?timeframe=$range&range=$range';
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
      return WalletSummary.fromJson(
        _requireMap(response, AppUrl.creatorWallet),
      );
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

  /// Parses one redeem-history list (`history` / `requests`).
  ///
  /// The value must be a JSON array; a missing, null or non-list value is
  /// treated as a malformed response and throws a [FormatException] instead of
  /// silently degrading to an empty list.
  static List<RedeemHistory> _parseRedeemList(dynamic value, String key) {
    if (value is! List) {
      throw FormatException(
        "Invalid or missing '$key' list in ${AppUrl.creatorRedeemHistory} response",
      );
    }
    return value.map((dynamic item) {
      if (item is! Map) {
        throw FormatException(
          "Invalid '$key' entry (expected a JSON object) "
          "in ${AppUrl.creatorRedeemHistory} response",
        );
      }
      return RedeemHistory.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  Future<Map<String, List<RedeemHistory>>> getRedeemHistory() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.creatorRedeemHistory);
      final dynamic payload = _unwrapPayload(response);
      if (payload is! Map) {
        throw FormatException(
          'Unexpected response structure for ${AppUrl.creatorRedeemHistory}',
        );
      }

      return {
        'history': _parseRedeemList(payload['history'], 'history'),
        'requests': _parseRedeemList(payload['requests'], 'requests'),
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<PointsSummary> getPointsSummary() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.creatorPoints);
      return PointsSummary.fromJson(
        _requireMap(response, AppUrl.creatorPoints),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Parses the creator point-history response.
  ///
  /// Supported shapes are a bare list (`[...]`) or an object carrying a
  /// `history` list (`{history: [...]}` and its `{data: {...}}` envelope). A
  /// malformed body — an unexpected root type, or a `history` value that is
  /// absent/null/not-a-list — throws a [FormatException] instead of being
  /// reported as a successfully empty history.
  Future<List<PointHistoryLog>> getPointHistory() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.creatorPointHistory);
      final dynamic payload = _unwrapPayload(response);

      // A bare list is itself the history; an object must expose `history`.
      final dynamic history = payload is Map ? payload['history'] : payload;

      if (history is! List) {
        throw FormatException(
          'Unexpected response structure for ${AppUrl.creatorPointHistory}',
        );
      }

      return history.map((dynamic item) {
        if (item is! Map) {
          throw FormatException(
            'Unexpected point history entry (expected a JSON object) '
            'for ${AppUrl.creatorPointHistory}',
          );
        }
        return PointHistoryLog.fromJson(Map<String, dynamic>.from(item));
      }).toList();
    } catch (e) {
      rethrow;
    }
  }
}
