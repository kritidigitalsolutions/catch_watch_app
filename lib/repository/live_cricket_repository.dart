import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/live_match_model.dart';
import '../res/appUrl.dart';

/// Repository for handling Live Cricket API operations.
///
/// Implements endpoints documented for Catch & Watch Live Cricket:
/// - GET /api/live-matches
/// - GET /api/live-matches/featured
/// - GET /api/live-matches/:id
/// - POST /api/live-matches/:id/view
///
/// Note: Authentication is optional per the backend contract.
class LiveCricketRepository {
  final BaseApiService _apiService;

  LiveCricketRepository({BaseApiService? apiService})
      : _apiService = apiService ?? NetworkApiService();

  /// Fetches list of live, upcoming, and completed cricket matches.
  ///
  /// Supports documented query parameters:
  /// - [status]: Filter by match status ('LIVE', 'UPCOMING', 'COMPLETED').
  /// - [tournament]: Filter by tournament or series name.
  /// - [format]: Filter by match format ('T20', 'ODI', 'TEST').
  /// - [limit]: Limit number of returned matches.
  Future<List<LiveMatchModel>> getLiveMatches({
    String? status,
    String? tournament,
    String? format,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status.trim().isNotEmpty) {
        queryParams['status'] = status.trim();
      }
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
      if (queryParams.isNotEmpty) {
        final queryString = Uri(queryParameters: queryParams).query;
        url = '$url?$queryString';
      }

      final dynamic response = await _apiService.getApi(url);

      if (response == null) return <LiveMatchModel>[];

      // Handle raw List response
      if (response is List) {
        return response
            .whereType<Map>()
            .map((e) => LiveMatchModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      // Handle Map response with wrapped keys
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

  /// Fetches the current featured live cricket match.
  Future<LiveMatchModel?> getFeaturedLiveMatch() async {
    try {
      final dynamic response =
          await _apiService.getApi(AppUrl.featuredLiveMatch);

      if (response == null) return null;

      if (response is Map) {
        // If response has a wrapped object
        final dynamic matchData = response['match'] ??
            response['featuredMatch'] ??
            response['data'] ??
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

  /// Fetches complete details and live stream URLs for a single match.
  Future<LiveMatchModel?> getLiveMatchDetails(String matchId) async {
    if (matchId.trim().isEmpty) return null;

    try {
      final dynamic response =
          await _apiService.getApi(AppUrl.liveMatchDetails(matchId.trim()));

      if (response == null) return null;

      if (response is Map) {
        final dynamic matchData = response['match'] ??
            response['data'] ??
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

  /// Records a single view event when video playback starts.
  /// Note: This is a single-shot registration call, not a periodic heartbeat.
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
      // Non-critical metric: do not crash user experience if view counting fails
      return false;
    }
  }
}
