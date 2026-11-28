import 'package:catch_watch/data/network/base_api_service.dart';
import 'package:catch_watch/models/live_show_model.dart';
import 'package:catch_watch/repository/live_show_repository.dart';
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
  group('Live Shows Foundation Tests', () {
    test('Endpoint URLs avoid /api/api duplication', () {
      expect(AppUrl.liveShows.contains('/api/api'), isFalse);
      expect(AppUrl.liveShows.endsWith('/api/live-shows'), isTrue);

      expect(AppUrl.featuredLiveShow.contains('/api/api'), isFalse);
      expect(AppUrl.featuredLiveShow.endsWith('/api/live-shows/featured'), isTrue);

      final detailsUrl = AppUrl.liveShowDetails('show-999');
      expect(detailsUrl.contains('/api/api'), isFalse);
      expect(detailsUrl.endsWith('/api/live-shows/show-999'), isTrue);

      final viewUrl = AppUrl.recordLiveShowView('show-999');
      expect(viewUrl.contains('/api/api'), isFalse);
      expect(viewUrl.endsWith('/api/live-shows/show-999/view'), isTrue);
    });

    test('Case-insensitive show status parsing', () {
      expect(LiveShowStatus.fromString('LIVE'), LiveShowStatus.live);
      expect(LiveShowStatus.fromString('live'), LiveShowStatus.live);
      expect(LiveShowStatus.fromString('Live '), LiveShowStatus.live);
      expect(LiveShowStatus.fromString('IN_PROGRESS'), LiveShowStatus.live);

      expect(LiveShowStatus.fromString('UPCOMING'), LiveShowStatus.upcoming);
      expect(LiveShowStatus.fromString('upcoming'), LiveShowStatus.upcoming);
      expect(LiveShowStatus.fromString('SCHEDULED'), LiveShowStatus.upcoming);

      expect(LiveShowStatus.fromString('ENDED'), LiveShowStatus.ended);
      expect(LiveShowStatus.fromString('ended'), LiveShowStatus.ended);
      expect(LiveShowStatus.fromString('COMPLETED'), LiveShowStatus.ended);

      expect(LiveShowStatus.fromString('UNKNOWN_VAL'), LiveShowStatus.unknown);
      expect(LiveShowStatus.fromString(null), LiveShowStatus.unknown);
    });

    test('LiveShowModel null-safe JSON parsing with host and streams', () {
      final json = {
        'id': 'show-101',
        'title': 'Midnight Creator Q&A',
        'description': 'Live interactive discussion with top creators.',
        'category': 'Talk Show',
        'status': 'LIVE',
        'host': {
          'name': 'Alex Rivera',
          'avatar': 'https://cdn.example.com/host.jpg',
        },
        'streamUrl': 'https://cdn.example.com/hls/show.m3u8',
        'backupStreamUrl': 'https://backup.example.com/hls/show.m3u8',
        'viewerCount': 4520,
        'isPremium': false,
        'isFeatured': true,
        'banner': 'https://cdn.example.com/banner.jpg',
        'poster': 'https://cdn.example.com/poster.jpg',
        'startTime': '2026-11-20T18:00:00.000Z',
      };

      final model = LiveShowModel.fromJson(json);

      expect(model.id, 'show-101');
      expect(model.title, 'Midnight Creator Q&A');
      expect(model.category, 'Talk Show');
      expect(model.isLive, isTrue);
      expect(model.hostName, 'Alex Rivera');
      expect(model.hostAvatar, 'https://cdn.example.com/host.jpg');
      expect(model.streamUrl, 'https://cdn.example.com/hls/show.m3u8');
      expect(model.viewerCount, 4520);
      expect(model.isFeatured, isTrue);
    });

    test('LiveShowRepository fetches live shows correctly', () async {
      final mockApi = MockApiService();
      mockApi.getApiResponse = {
        'shows': [
          {
            'id': 's1',
            'title': 'Show 1',
            'status': 'LIVE',
          }
        ]
      };

      final repo = LiveShowRepository(apiService: mockApi);
      final shows = await repo.getLiveShows(status: 'LIVE');

      expect(mockApi.lastGetUrl, '${AppUrl.liveShows}?status=LIVE');
      expect(shows.length, 1);
      expect(shows[0].title, 'Show 1');
    });
  });
}
