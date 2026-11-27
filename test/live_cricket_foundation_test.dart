import 'package:catch_watch/data/network/base_api_service.dart';
import 'package:catch_watch/models/live_match_model.dart';
import 'package:catch_watch/repository/live_cricket_repository.dart';
import 'package:catch_watch/res/appUrl.dart';
import 'package:flutter_test/flutter_test.dart';

class MockApiService implements BaseApiService {
  dynamic getApiResponse;
  dynamic postApiResponse;
  String? lastGetUrl;
  String? lastPostUrl;
  dynamic lastPostData;

  @override
  Future<dynamic> getApi(String url) async {
    lastGetUrl = url;
    return getApiResponse;
  }

  @override
  Future<dynamic> postApi(String url, dynamic data) async {
    lastPostUrl = url;
    lastPostData = data;
    return postApiResponse;
  }

  @override
  Future<dynamic> deleteApi(String url, dynamic data) async => throw UnimplementedError();

  @override
  Future<dynamic> patchApi(String url, dynamic data) async => throw UnimplementedError();

  @override
  Future<dynamic> putApi(String url, dynamic data) async => throw UnimplementedError();
}

void main() {
  group('Live Cricket Foundation Tests - Phase 1', () {
    test('Endpoint URLs avoid /api/api duplication', () {
      expect(AppUrl.liveMatches.contains('/api/api'), isFalse);
      expect(AppUrl.liveMatches.endsWith('/api/live-matches'), isTrue);

      expect(AppUrl.featuredLiveMatch.contains('/api/api'), isFalse);
      expect(AppUrl.featuredLiveMatch.endsWith('/api/live-matches/featured'), isTrue);

      final detailsUrl = AppUrl.liveMatchDetails('match-999');
      expect(detailsUrl.contains('/api/api'), isFalse);
      expect(detailsUrl.endsWith('/api/live-matches/match-999'), isTrue);

      final viewUrl = AppUrl.recordLiveMatchView('match-999');
      expect(viewUrl.contains('/api/api'), isFalse);
      expect(viewUrl.endsWith('/api/live-matches/match-999/view'), isTrue);
    });

    test('Case-insensitive match status parsing', () {
      expect(LiveMatchStatus.fromString('LIVE'), LiveMatchStatus.live);
      expect(LiveMatchStatus.fromString('live'), LiveMatchStatus.live);
      expect(LiveMatchStatus.fromString('Live '), LiveMatchStatus.live);
      expect(LiveMatchStatus.fromString('IN_PROGRESS'), LiveMatchStatus.live);

      expect(LiveMatchStatus.fromString('UPCOMING'), LiveMatchStatus.upcoming);
      expect(LiveMatchStatus.fromString('upcoming'), LiveMatchStatus.upcoming);
      expect(LiveMatchStatus.fromString('SCHEDULED'), LiveMatchStatus.upcoming);

      expect(LiveMatchStatus.fromString('COMPLETED'), LiveMatchStatus.completed);
      expect(LiveMatchStatus.fromString('completed'), LiveMatchStatus.completed);
      expect(LiveMatchStatus.fromString('FINISHED'), LiveMatchStatus.completed);

      expect(LiveMatchStatus.fromString('UNKNOWN_VAL'), LiveMatchStatus.unknown);
      expect(LiveMatchStatus.fromString(null), LiveMatchStatus.unknown);
    });

    test('LiveMatchModel null-safe JSON parsing with teams and streams', () {
      final json = {
        'id': 'match-101',
        'title': 'India vs Australia 1st T20I',
        'series': 'Border-Gavaskar Trophy',
        'matchType': 'T20',
        'venue': 'Wankhede Stadium, Mumbai',
        'status': 'LIVE',
        'statusNote': 'IND need 32 runs in 24 balls',
        'team1': {
          'id': 'team-ind',
          'name': 'India',
          'shortName': 'IND',
          'score': '168/4',
          'overs': '16.0',
          'runs': 168,
          'wickets': 4,
        },
        'team2': {
          'id': 'team-aus',
          'name': 'Australia',
          'shortName': 'AUS',
          'score': '199/6',
          'overs': '20.0',
          'runs': 199,
          'wickets': 6,
        },
        'streamUrl': 'https://cdn.example.com/hls/live.m3u8',
        'backupStreamUrl': 'https://backup.example.com/hls/live.m3u8',
        'isPremium': true,
        'isFeatured': true,
        'viewerCount': 12540,
        'banner': 'https://cdn.example.com/banner.jpg',
        'poster': 'https://cdn.example.com/poster.jpg',
        'startTime': '2026-11-20T14:00:00.000Z',
      };

      final model = LiveMatchModel.fromJson(json);

      expect(model.id, 'match-101');
      expect(model.title, 'India vs Australia 1st T20I');
      expect(model.series, 'Border-Gavaskar Trophy');
      expect(model.isLive, isTrue);
      expect(model.isUpcoming, isFalse);
      expect(model.isCompleted, isFalse);
      expect(model.team1?.name, 'India');
      expect(model.team1?.shortName, 'IND');
      expect(model.team1?.score, '168/4');
      expect(model.team2?.name, 'Australia');
      expect(model.hasLiveStream, isTrue);
      expect(model.streamUrl, 'https://cdn.example.com/hls/live.m3u8');
      expect(model.hasBackupStream, isTrue);
      expect(model.backupStreamUrl, 'https://backup.example.com/hls/live.m3u8');
      expect(model.isPremium, isTrue);
      expect(model.isFeatured, isTrue);
      expect(model.viewerCount, 12540);
      expect(model.startTime, isNotNull);
    });

    test('LiveMatchModel handles missing optional fields gracefully', () {
      final minimalJson = {
        'id': 'match-min-1',
        'title': 'Practice Match',
      };

      final model = LiveMatchModel.fromJson(minimalJson);

      expect(model.id, 'match-min-1');
      expect(model.title, 'Practice Match');
      expect(model.isLive, isFalse);
      expect(model.isUpcoming, isTrue); // default status is UPCOMING
      expect(model.hasLiveStream, isFalse);
      expect(model.hasBackupStream, isFalse);
      expect(model.isPremium, isFalse);
      expect(model.isFeatured, isFalse);
      expect(model.viewerCount, 0);
      expect(model.team1, isNull);
      expect(model.team2, isNull);
    });

    test('LiveCricketRepository fetches matches and featured match correctly', () async {
      final mock = MockApiService();
      final repo = LiveCricketRepository(apiService: mock);

      // 1. Test getLiveMatches with query parameters
      mock.getApiResponse = {
        'success': true,
        'matches': [
          {'id': 'm1', 'title': 'Match 1', 'status': 'LIVE'},
          {'id': 'm2', 'title': 'Match 2', 'status': 'UPCOMING'},
        ],
      };

      final matches = await repo.getLiveMatches(
        status: 'LIVE',
        tournament: 'IPL 2026',
        format: 'T20',
        limit: 10,
      );
      expect(matches.length, 2);
      expect(matches[0].id, 'm1');
      expect(matches[0].isLive, isTrue);
      expect(matches[1].id, 'm2');
      expect(matches[1].isUpcoming, isTrue);
      expect(mock.lastGetUrl, contains('status=LIVE'));
      expect(mock.lastGetUrl, contains('tournament=IPL+2026'));
      expect(mock.lastGetUrl, contains('format=T20'));
      expect(mock.lastGetUrl, contains('limit=10'));

      // 2. Test getFeaturedLiveMatch
      mock.getApiResponse = {
        'success': true,
        'match': {'id': 'm-featured', 'title': 'Featured Match', 'status': 'LIVE', 'isFeatured': true},
      };

      final featured = await repo.getFeaturedLiveMatch();
      expect(featured, isNotNull);
      expect(featured!.id, 'm-featured');
      expect(featured.isFeatured, isTrue);
      expect(mock.lastGetUrl, AppUrl.featuredLiveMatch);

      // 3. Test recordLiveMatchView
      mock.postApiResponse = {'success': true, 'message': 'View recorded'};
      final recorded = await repo.recordLiveMatchView('m1');
      expect(recorded, isTrue);
      expect(mock.lastPostUrl, AppUrl.recordLiveMatchView('m1'));
    });
  });
}
