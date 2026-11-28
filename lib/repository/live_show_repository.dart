import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/live_show_model.dart';
import '../res/appUrl.dart';

/// Repository for handling Live Shows API operations.
///
/// Implements endpoints documented for Catch & Watch Live Shows:
/// - GET /api/live-shows
/// - GET /api/live-shows/featured
/// - GET /api/live-shows/:id
/// - POST /api/live-shows/:id/view
class LiveShowRepository {
  final BaseApiService _apiService;

  LiveShowRepository({BaseApiService? apiService})
      : _apiService = apiService ?? NetworkApiService();

  /// Fetches paginated list of live shows with optional filters.
  Future<List<LiveShowModel>> getLiveShows({
    String? status,
    String? category,
    String? search,
    int? limit,
    int? page,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status.trim().isNotEmpty) {
        queryParams['status'] = status.trim();
      }
      if (category != null && category.trim().isNotEmpty) {
        queryParams['category'] = category.trim();
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (limit != null && limit > 0) {
        queryParams['limit'] = limit.toString();
      }
      if (page != null && page > 0) {
        queryParams['page'] = page.toString();
      }

      String url = AppUrl.liveShows;
      if (queryParams.isNotEmpty) {
        final queryString = Uri(queryParameters: queryParams).query;
        url = '$url?$queryString';
      }

      final dynamic response = await _apiService.getApi(url);

      if (response == null) return <LiveShowModel>[];

      // Handle raw List response
      if (response is List) {
        return response
            .whereType<Map>()
            .map((e) => LiveShowModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      // Handle Map response with wrapped keys (e.g., { "success": true, "data": { "shows": [...] } })
      if (response is Map) {
        dynamic listData = response['shows'] ??
            response['liveShows'] ??
            response['items'];

        if (listData == null && response['data'] != null) {
          final data = response['data'];
          if (data is List) {
            listData = data;
          } else if (data is Map) {
            listData = data['shows'] ??
                data['liveShows'] ??
                data['items'] ??
                data['data'] ??
                (data.containsKey('_id') || data.containsKey('id') ? [data] : null);
          }
        }

        if (listData is List) {
          return listData
              .whereType<Map>()
              .map((e) => LiveShowModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }

        if (listData is Map) {
          return [LiveShowModel.fromJson(Map<String, dynamic>.from(listData))];
        }
      }

      return <LiveShowModel>[];
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches the current featured live show.
  Future<LiveShowModel?> getFeaturedLiveShow() async {
    try {
      final dynamic response =
          await _apiService.getApi(AppUrl.featuredLiveShow);

      if (response == null) return null;

      if (response is Map) {
        final dynamic data = response['data'];
        final dynamic showData = response['show'] ??
            response['featuredShow'] ??
            (data is Map ? (data['show'] ?? data['featuredShow'] ?? data) : null) ??
            (response.containsKey('id') || response.containsKey('_id')
                ? response
                : null);

        if (showData is Map) {
          return LiveShowModel.fromJson(Map<String, dynamic>.from(showData));
        }

        if (showData is List && showData.isNotEmpty && showData[0] is Map) {
          return LiveShowModel.fromJson(Map<String, dynamic>.from(showData[0]));
        }
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches details and stream URLs for a single live show.
  Future<LiveShowModel?> getLiveShowDetails(String showId) async {
    if (showId.trim().isEmpty) return null;

    try {
      final dynamic response =
          await _apiService.getApi(AppUrl.liveShowDetails(showId.trim()));

      if (response == null) return null;

      if (response is Map) {
        final dynamic data = response['data'];
        final dynamic showData = response['show'] ??
            (data is Map ? (data['show'] ?? data) : null) ??
            (response.containsKey('id') || response.containsKey('_id')
                ? response
                : null);

        if (showData is Map) {
          return LiveShowModel.fromJson(Map<String, dynamic>.from(showData));
        }
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Records viewer heartbeat ping when viewing a live show.
  Future<bool> recordLiveShowView(String showId) async {
    if (showId.trim().isEmpty) return false;

    try {
      final dynamic response = await _apiService.postApi(
        AppUrl.recordLiveShowView(showId.trim()),
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
