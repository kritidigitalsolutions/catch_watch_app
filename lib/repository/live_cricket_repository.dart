import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/live_match_model.dart';
import '../res/appUrl.dart';

/// Repository for handling Live Cricket API operations.
///
/// Implements endpoints documented for Catch & Watch Live Cricket:
/// - GET /api/live-matches
/// - GET /api/live-matches/upcoming
/// - GET /api/live-matches/completed
/// - GET /api/live-matches/featured
/// - GET /api/live-matches/:id
/// - GET /api/live-matches/:id/live-activity
/// - GET /api/live-matches/:id/scorecard
/// - GET /api/live-matches/:id/commentary
/// - GET /api/live-matches/:id/squads
/// - POST /api/live-matches/:id/view
class LiveCricketRepository {
  final BaseApiService _apiService;

  LiveCricketRepository({BaseApiService? apiService})
      : _apiService = apiService ?? NetworkApiService();

  Future<List<LiveMatchModel>> getLiveMatches({
    String? status,
    String? tournament,
    String? format,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (tournament != null && tournament.trim().isNotEmpty) {
        queryParams['tournament'] = tournament.trim();
      }
      if (format != null && format.trim().isNotEmpty) {
        queryParams['format'] = format.trim();
      }
      if (limit != null && limit > 0) {
        queryParams['limit'] = limit.toString();
      }

      String url = AppUrl.liveMatches;
      if (status != null && status.trim().isNotEmpty) {
        final st = status.trim().toUpperCase();
        if (st == 'UPCOMING') {
          url = AppUrl.upcomingLiveMatches;
        } else if (st == 'COMPLETED' || st == 'ENDED') {
          url = AppUrl.completedLiveMatches;
        } else {
          queryParams['status'] = st;
        }
      }

      if (queryParams.isNotEmpty) {
        final queryString = Uri(queryParameters: queryParams).query;
        url = '$url?$queryString';
      }

      final dynamic response = await _apiService.getApi(url);

      if (response == null) return <LiveMatchModel>[];

      if (response is List) {
        return response
            .whereType<Map>()
            .map((e) => LiveMatchModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (response is Map) {
        final dynamic listData = response['matches'] ??
            response['data'] ??
            response['liveMatches'] ??
            response['items'];

        if (listData is List) {
          return listData
              .whereType<Map>()
              .map((e) => LiveMatchModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }

      return <LiveMatchModel>[];
    } catch (e) {
      rethrow;
    }
  }

  Future<LiveMatchModel?> getFeaturedLiveMatch() async {
    try {
      final dynamic response =
          await _apiService.getApi(AppUrl.featuredLiveMatch);

      if (response == null) return null;

      if (response is Map) {
        final dynamic data = response['data'];
        final dynamic matchData = response['match'] ??
            response['featuredMatch'] ??
            (data is Map ? (data['match'] ?? data['featuredMatch'] ?? data) : null) ??
            (response.containsKey('id') || response.containsKey('_id')
                ? response
                : null);

        if (matchData is Map) {
          return LiveMatchModel.fromJson(Map<String, dynamic>.from(matchData));
        }
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<LiveMatchModel?> getLiveMatchDetails(String matchId) async {
    if (matchId.trim().isEmpty) return null;

    try {
      final dynamic response =
          await _apiService.getApi(AppUrl.liveMatchDetails(matchId.trim()));

      if (response == null) return null;

      if (response is Map) {
        final dynamic data = response['data'];
        final dynamic matchData = response['match'] ??
            (data is Map ? (data['match'] ?? data) : null) ??
            (response.containsKey('id') || response.containsKey('_id')
                ? response
                : null);

        if (matchData is Map) {
          return LiveMatchModel.fromJson(Map<String, dynamic>.from(matchData));
        }
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getLiveMatchActivity(String matchId) async {
    if (matchId.trim().isEmpty) return null;
    try {
      final res = await _apiService.getApi(AppUrl.liveMatchLiveActivity(matchId.trim()));
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMatchScorecard(String matchId) async {
    if (matchId.trim().isEmpty) return null;
    try {
      final res = await _apiService.getApi(AppUrl.liveMatchScorecard(matchId.trim()));
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMatchCommentary(String matchId) async {
    if (matchId.trim().isEmpty) return null;
    try {
      final res = await _apiService.getApi(AppUrl.liveMatchCommentary(matchId.trim()));
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMatchSquads(String matchId) async {
    if (matchId.trim().isEmpty) return null;
    try {
      final res = await _apiService.getApi(AppUrl.liveMatchSquads(matchId.trim()));
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> recordLiveMatchView(String matchId) async {
    if (matchId.trim().isEmpty) return false;

    try {
      final dynamic response = await _apiService.postApi(
        AppUrl.recordLiveMatchView(matchId.trim()),
        <String, dynamic>{},
      );

      if (response is Map) {
        return response['success'] == true || response['status'] == 'success';
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
