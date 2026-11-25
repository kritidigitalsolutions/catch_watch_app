import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/live_cricket_model.dart';
import '../res/appUrl.dart';

class LiveCricketRepository {
  final BaseApiService _apiService = NetworkApiService();

  Future<LiveMatchesResponse> getMatches({
    String status = 'ALL',
    String format = 'ALL',
    String? tournament,
    int limit = 50,
  }) async {
    try {
      String url = '${AppUrl.liveMatches}?status=$status&format=$format&limit=$limit';
      if (tournament != null && tournament.isNotEmpty) {
        url += '&tournament=$tournament';
      }
      dynamic response = await _apiService.getApi(url);
      return LiveMatchesResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<CricketMatch?> getFeaturedMatch() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.featuredLiveMatch);
      if (response['success'] == true && response['match'] != null) {
        return CricketMatch.fromJson(response['match']);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CricketMatch>> getLiveMatchesOnly() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.liveNowMatches);
      if (response['success'] == true && response['matches'] != null) {
        return (response['matches'] as List)
            .map((e) => CricketMatch.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CricketMatch>> getUpcomingMatchesOnly() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.upcomingMatches);
      if (response['success'] == true && response['matches'] != null) {
        return (response['matches'] as List)
            .map((e) => CricketMatch.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CricketMatch>> getCompletedMatchesOnly() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.completedMatches);
      if (response['success'] == true && response['matches'] != null) {
        return (response['matches'] as List)
            .map((e) => CricketMatch.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<CricketMatch?> getMatchDetails(String matchId) async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.matchDetails(matchId));
      if (response['success'] == true && response['match'] != null) {
        return CricketMatch.fromJson(response['match']);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> pingViewCount(String matchId) async {
    try {
      await _apiService.postApi(AppUrl.matchViewHeartbeat(matchId), {});
    } catch (e) {
      // Non-blocking
    }
  }

  Future<LiveCrease?> getLiveActivity(String matchId) async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.matchLiveActivity(matchId));
      if (response['success'] == true) {
        if (response['liveCrease'] != null) {
          return LiveCrease.fromJson(response['liveCrease']);
        }
        return LiveCrease.fromJson(response);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<ScorecardModel?> getScorecard(String matchId) async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.matchScorecard(matchId));
      if (response['success'] == true) {
        if (response['scorecard'] != null) {
          return ScorecardModel.fromJson(response['scorecard']);
        }
        return ScorecardModel.fromJson(response);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CommentaryItem>> getCommentary(String matchId, {int limit = 30}) async {
    try {
      dynamic response = await _apiService.getApi('${AppUrl.matchCommentary(matchId)}?limit=$limit');
      if (response['success'] == true && response['commentary'] != null) {
        return (response['commentary'] as List)
            .map((e) => CommentaryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<SquadsInfo?> getSquads(String matchId) async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.matchSquads(matchId));
      if (response['success'] == true) {
        if (response['squads'] != null) {
          return SquadsInfo.fromJson(response['squads']);
        }
        return SquadsInfo.fromSquadsApiJson(response);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }
}
