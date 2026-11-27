import 'package:catch_watch/data/network/base_api_service.dart';
import 'package:catch_watch/models/live_match_model.dart';
import 'package:catch_watch/repository/live_cricket_repository.dart';
import 'package:catch_watch/view_model/after_login_provider/live_cricket_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class MockApiService implements BaseApiService {
  dynamic getApiResponse;
  dynamic postApiResponse;
  int getApiCallCount = 0;
  String? lastGetUrl;

  @override
  Future<dynamic> getApi(String url) async {
    getApiCallCount++;
    lastGetUrl = url;
    if (getApiResponse is Exception) {
      throw getApiResponse;
    }
    return getApiResponse;
  }

  @override
  Future<dynamic> postApi(String url, dynamic data) async {
    return postApiResponse ?? {'success': true};
  }

  @override
  Future<dynamic> deleteApi(String url, dynamic data) async => throw UnimplementedError();

  @override
  Future<dynamic> patchApi(String url, dynamic data) async => throw UnimplementedError();

  @override
  Future<dynamic> putApi(String url, dynamic data) async => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveCricketProvider Phase 2 Tests', () {
    late MockApiService mockApi;
    late LiveCricketRepository repo;
    late LiveCricketProvider provider;

    setUp(() {
      mockApi = MockApiService();
      repo = LiveCricketRepository(apiService: mockApi);
      provider = LiveCricketProvider(repository: repo);
    });

    tearDown(() {
      provider.dispose();
    });

    test('Initial states are idle, empty, and clean', () {
      expect(provider.featuredMatch, isNull);
      expect(provider.isFeaturedLoading, isFalse);
      expect(provider.hasFeaturedMatch, isFalse);
      expect(provider.featuredError, isNull);

      expect(provider.liveMatches, isEmpty);
      expect(provider.isLiveLoading, isFalse);
      expect(provider.hasLiveMatches, isFalse);
      expect(provider.liveError, isNull);

      expect(provider.upcomingMatches, isEmpty);
      expect(provider.isUpcomingLoading, isFalse);

      expect(provider.completedMatches, isEmpty);
      expect(provider.isCompletedLoading, isFalse);

      expect(provider.selectedMatch, isNull);
      expect(provider.isDetailLoading, isFalse);
      expect(provider.useBackupStream, isFalse);
      expect(provider.isPollingActive, isFalse);
    });

    test('fetchFeaturedMatch sets loading and populates featured match', () async {
      mockApi.getApiResponse = {
        'success': true,
        'match': {
          'id': 'feat-1',
          'title': 'IND vs AUS Final',
          'status': 'LIVE',
          'isFeatured': true,
        },
      };

      final future = provider.fetchFeaturedMatch();
      expect(provider.isFeaturedLoading, isTrue);

      await future;
      expect(provider.isFeaturedLoading, isFalse);
      expect(provider.hasFeaturedMatch, isTrue);
      expect(provider.featuredMatch?.id, 'feat-1');
      expect(provider.featuredError, isNull);
    });

    test('Independent failure isolation: featured failure does not affect live matches', () async {
      // 1. Featured fails with Exception
      mockApi.getApiResponse = Exception('Featured API 500 error');
      await provider.fetchFeaturedMatch();
      expect(provider.hasFeaturedMatch, isFalse);
      expect(provider.featuredError, isNotNull);

      // 2. Live matches succeed
      mockApi.getApiResponse = {
        'success': true,
        'matches': [
          {'id': 'live-1', 'title': 'Live Match 1', 'status': 'LIVE'},
        ],
      };
      await provider.fetchLiveMatches();
      expect(provider.hasLiveMatches, isTrue);
      expect(provider.liveMatches.length, 1);
      expect(provider.liveError, isNull);

      // Featured error remains isolated
      expect(provider.featuredError, isNotNull);
    });

    test('Stream switching toggles primary and backup stream URLs', () {
      final match = LiveMatchModel.fromJson({
        'id': 'm-stream',
        'title': 'Stream Test Match',
        'status': 'LIVE',
        'streamUrl': 'https://cdn.example.com/primary.m3u8',
        'backupStreamUrl': 'https://backup.example.com/secondary.m3u8',
      });

      provider.setSelectedMatch(match);
      expect(provider.activeStreamUrl, 'https://cdn.example.com/primary.m3u8');
      expect(provider.useBackupStream, isFalse);

      provider.switchToBackupStream();
      expect(provider.useBackupStream, isTrue);
      expect(provider.activeStreamUrl, 'https://backup.example.com/secondary.m3u8');

      provider.resetStreamSelection();
      expect(provider.useBackupStream, isFalse);
      expect(provider.activeStreamUrl, 'https://cdn.example.com/primary.m3u8');
    });

    test('25-second polling lifecycle, in-flight guard, and stop', () async {
      mockApi.getApiResponse = {
        'success': true,
        'match': {
          'id': 'm-poll-1',
          'title': 'Polling Match',
          'status': 'LIVE',
          'statusNote': 'Score updated 1',
        },
      };

      // 1. Start polling
      provider.startLiveScorePolling('m-poll-1');
      expect(provider.isPollingActive, isTrue);
      expect(provider.pollingMatchId, 'm-poll-1');
      expect(mockApi.getApiCallCount, 1);

      // 2. Calling start again with the same matchId does not duplicate timer or poll
      provider.startLiveScorePolling('m-poll-1');
      expect(mockApi.getApiCallCount, 1);

      // 3. Pause and Resume polling
      provider.pausePolling();
      expect(provider.isPollingActive, isFalse);

      provider.resumePolling();
      expect(provider.isPollingActive, isTrue);

      // 4. Stop polling cleans up state
      provider.stopLiveScorePolling();
      expect(provider.isPollingActive, isFalse);
      expect(provider.pollingMatchId, isNull);
    });

    test('clearSelectedMatch stops polling and resets selection cleanly', () {
      final match = LiveMatchModel.fromJson({
        'id': 'm-clear',
        'title': 'Clear Match',
        'status': 'LIVE',
      });
      provider.setSelectedMatch(match);
      provider.startLiveScorePolling('m-clear');
      provider.switchToBackupStream();

      expect(provider.selectedMatch, isNotNull);
      expect(provider.isPollingActive, isTrue);

      provider.clearSelectedMatch();
      expect(provider.selectedMatch, isNull);
      expect(provider.isPollingActive, isFalse);
      expect(provider.useBackupStream, isFalse);
    });
  });
}
