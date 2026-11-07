
import 'dart:async';

import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/repository/reels_repository.dart';
import 'package:catch_watch/res/appUrl.dart';
import 'package:catch_watch/view_model/after_login_provider/block_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/call_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/reels_provider.dart';
import 'package:catch_watch/views/after_login_pages/short_video_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _TestVideoPlayerPlatform extends VideoPlayerPlatform {
  final Map<int, StreamController<VideoEvent>> streams = <int, StreamController<VideoEvent>>{};
  final List<String?> createdUris = <String?>[];
  final Set<int> playingTextures = <int>{};
  final Set<int> disposedTextures = <int>{};
  Size initialSize = const Size(1080, 1920);
  int failuresRemaining = 0;
  Completer<void>? createGate;
  int _nextTextureId = 1;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int textureId) async {
    disposedTextures.add(textureId);
    playingTextures.remove(textureId);
    await streams.remove(textureId)?.close();
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    final int textureId = _nextTextureId++;
    createdUris.add(dataSource.uri);
    final gate = createGate;
    if (gate != null) await gate.future;
    final controller = StreamController<VideoEvent>();
    streams[textureId] = controller;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      controller.addError(
        PlatformException(
          code: 'VideoError',
          message: 'Failed to load video: HTTP 403',
        ),
      );
    } else {
      controller.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 15),
          size: initialSize,
        ),
      );
    }
    return textureId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return streams[textureId]?.stream ?? const Stream<VideoEvent>.empty();
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {}

  @override
  Future<void> play(int textureId) async {
    playingTextures.add(textureId);
  }

  @override
  Future<void> pause(int textureId) async {
    playingTextures.remove(textureId);
  }

  @override
  Future<void> setVolume(int textureId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}

  @override
  Future<void> seekTo(int textureId, Duration position) async {}

  @override
  Future<Duration> getPosition(int textureId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int textureId) {
    return SizedBox.expand(
      key: ValueKey<String>('video_surface_$textureId'),
    );
  }
}

class _FakeReelsRepository extends ReelsRepository {
  dynamic feedResponse;
  dynamic searchResponse;
  final Map<String, dynamic> reelByIdResponses = <String, dynamic>{};
  final List<Map<String, dynamic>> recordedAdEvents = <Map<String, dynamic>>[];

  @override
  Future<dynamic> getReelsFeed() async => feedResponse;

  @override
  Future<dynamic> searchReels(String query) async => searchResponse;

  @override
  Future<dynamic> getReelById(String id) async => reelByIdResponses[id];

  @override
  Future<dynamic> recordAdEvent({
    required String adId,
    required String campaignId,
    required String eventType,
    int? watchDuration,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'adId': adId,
      'campaignId': campaignId,
      'eventType': eventType,
      'watchDuration': ?watchDuration,
    };
    recordedAdEvents.add(payload);
    return <String, dynamic>{'success': true, ...payload};
  }
}

void main() {
  group('ReelsProvider URL & Content Classification', () {
    test('detects YouTube URLs across standard, mobile, shorts, and shortener domains', () {
      expect(
        ReelsProvider.isYoutubeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        isTrue,
      );
      expect(
        ReelsProvider.isYoutubeUrl('https://youtube.com/shorts/abc123XYZ'),
        isTrue,
      );
      expect(
        ReelsProvider.isYoutubeUrl('https://m.youtube.com/watch?v=abc123XYZ'),
        isTrue,
      );
      expect(
        ReelsProvider.isYoutubeUrl('https://youtu.be/dQw4w9WgXcQ?si=test'),
        isTrue,
      );
      expect(
        ReelsProvider.isYoutubeUrl('https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ'),
        isTrue,
      );

      // Legitimate first-party creator video whose filename happens to include "youtube"
      expect(
        ReelsProvider.isYoutubeUrl(
          'https://api.catchandwatch.com/uploads/reels/my_youtube_journey.mp4',
        ),
        isFalse,
      );
      expect(
        ReelsProvider.isYoutubeUrl('https://api.catchandwatch.com/uploads/reels/video1.mp4'),
        isFalse,
      );
    });

    test('detects magnific.com and static image media URLs accurately', () {
      expect(
        ReelsProvider.isExternalAdDomainUrl('https://magnific.com/banners/promo.jpg'),
        isTrue,
      );
      expect(
        ReelsProvider.isExternalAdDomainUrl('https://cdn.magnific.com/ad_asset.png'),
        isTrue,
      );
      expect(
        ReelsProvider.isExternalAdDomainUrl('https://api.catchandwatch.com/reels/1.mp4'),
        isFalse,
      );

      expect(
        ReelsProvider.isImageMediaUrl('https://api.catchandwatch.com/ads/banner.jpg?version=2'),
        isTrue,
      );
      expect(
        ReelsProvider.isImageMediaUrl('https://api.catchandwatch.com/ads/banner.PNG'),
        isTrue,
      );
      expect(
        ReelsProvider.isImageMediaUrl('https://api.catchandwatch.com/ads/banner.webp'),
        isTrue,
      );

      // Video URL with image filename in query parameter must NOT be treated as an image URL
      expect(
        ReelsProvider.isImageMediaUrl(
          'https://api.catchandwatch.com/uploads/reels/clip.mp4?poster=thumb.jpg',
        ),
        isFalse,
      );
    });

    test('preserves legitimate creator videos including MP4, HLS, MOV, and extensionless streams on iOS', () {
      final mp4Reel = ReelModel.fromJson({
        '_id': 'reel_mp4',
        'videoUrl': 'https://api.catchandwatch.com/uploads/reels/creator_1.mp4',
        'thumbnail': 'https://api.catchandwatch.com/uploads/thumbs/creator_1.jpg',
        'caption': 'First-party MP4 reel',
      });
      final hlsReel = ReelModel.fromJson({
        '_id': 'reel_hls',
        'videoUrl': 'https://api.catchandwatch.com/uploads/reels/creator_2/master.m3u8?token=abc',
        'caption': 'First-party HLS reel',
      });
      final movReel = ReelModel.fromJson({
        '_id': 'reel_mov',
        'videoUrl': 'uploads/reels/ios_capture.mov',
        'caption': 'Relative MOV reel',
      });
      final extensionlessStreamReel = ReelModel.fromJson({
        '_id': 'reel_stream',
        'videoUrl': 'https://api.catchandwatch.com/api/reels/stream/65f0123456789abcdef',
        'caption': 'Extensionless streaming endpoint',
      });

      expect(ReelsProvider.isPlayableCreatorReel(mp4Reel, isIOS: true), isTrue);
      expect(ReelsProvider.isPlayableCreatorReel(hlsReel, isIOS: true), isTrue);
      expect(ReelsProvider.isPlayableCreatorReel(movReel, isIOS: true), isTrue);
      expect(ReelsProvider.isPlayableCreatorReel(extensionlessStreamReel, isIOS: true), isTrue);
    });

    test('filters out YouTube URLs and unsupported image/placeholder ads on iOS while allowing legitimate sponsored video ads', () {
      final youtubeReel = ReelModel.fromJson({
        '_id': 'yt_1',
        'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'caption': 'YouTube embed',
      });
      final youtuBeShortReel = ReelModel.fromJson({
        '_id': 'yt_2',
        'videoUrl': 'https://youtu.be/dQw4w9WgXcQ',
        'caption': 'Youtu.be link',
      });
      final magnificAdReel = ReelModel.fromJson({
        '_id': 'ad_magnific',
        'videoUrl': 'https://magnific.com/campaigns/banner1.jpg',
        'isAd': true,
        'adId': 'ad_101',
        'destinationUrl': 'https://magnific.com/landing',
      });
      final imageAdReel = ReelModel.fromJson({
        '_id': 'ad_img',
        'videoUrl': 'https://api.catchandwatch.com/uploads/ads/banner.png',
        'isAd': true,
        'adId': 'ad_img_1',
        'adType': 'image',
        'destinationUrl': 'https://catchandwatch.com/promo',
      });
      final sponsoredMp4VideoAd = ReelModel.fromJson({
        '_id': 'reel_ad_video_1',
        'adId': 'ad_video_201',
        'campaignId': 'camp_501',
        'isAd': true,
        'isSponsored': true,
        'adType': 'video',
        'videoUrl': 'https://api.catchandwatch.com/uploads/ads/promo_video.mp4',
        'advertiser': {
          '_id': 'adv_99',
          'name': 'Acme Studios',
          'logo': 'uploads/brands/acme.png',
        },
        'ctaText': 'Watch Now',
        'destinationUrl': 'https://catchandwatch.com/campaigns/acme',
      });
      final isSponsoredOnlyHlsAd = ReelModel.fromJson({
        '_id': 'ad_hls_301',
        'isSponsored': true,
        'campaignId': 'camp_502',
        'mediaUrl': 'https://api.catchandwatch.com/uploads/ads/stream/master.m3u8',
        'sponsorName': 'StreamBrand',
        'ctaLabel': 'Learn More',
        'clickUrl': 'https://catchandwatch.com/streambrand',
      });
      final imageOnlyReel = ReelModel.fromJson({
        '_id': 'img_only',
        'videoUrl': 'https://api.catchandwatch.com/uploads/static_poster.png',
      });

      // iOS: YouTube links and image-only/magnific placeholder ads are blocked
      expect(ReelsProvider.isPlayableCreatorReel(youtubeReel, isIOS: true), isFalse);
      expect(ReelsProvider.isPlayableCreatorReel(youtuBeShortReel, isIOS: true), isFalse);
      expect(ReelsProvider.isPlayableCreatorReel(magnificAdReel, isIOS: true), isFalse);
      expect(ReelsProvider.isPlayableCreatorReel(imageAdReel, isIOS: true), isFalse);
      expect(ReelsProvider.isPlayableCreatorReel(imageOnlyReel, isIOS: true), isFalse);

      // iOS: Legitimate isAd / isSponsored MP4 & HLS video ads with adId, campaignId, and destinationUrl are ALLOWED
      expect(ReelsProvider.isPlayableCreatorReel(sponsoredMp4VideoAd, isIOS: true), isTrue);
      expect(ReelsProvider.isPlayableCreatorReel(isSponsoredOnlyHlsAd, isIOS: true), isTrue);
      expect(sponsoredMp4VideoAd.isSponsoredAd, isTrue);
      expect(sponsoredMp4VideoAd.adId, equals('ad_video_201'));
      expect(sponsoredMp4VideoAd.campaignId, equals('camp_501'));
      expect(sponsoredMp4VideoAd.advertiserId, equals('adv_99'));
      expect(sponsoredMp4VideoAd.advertiserName, equals('Acme Studios'));
      expect(sponsoredMp4VideoAd.ctaText, equals('Watch Now'));
      expect(sponsoredMp4VideoAd.destinationUrl, equals('https://catchandwatch.com/campaigns/acme'));

      expect(isSponsoredOnlyHlsAd.isSponsoredAd, isTrue);
      expect(isSponsoredOnlyHlsAd.isAd, isTrue);
      expect(isSponsoredOnlyHlsAd.adId, equals('ad_hls_301'));
      expect(isSponsoredOnlyHlsAd.advertiserName, equals('StreamBrand'));
      expect(isSponsoredOnlyHlsAd.ctaText, equals('Learn More'));
      expect(isSponsoredOnlyHlsAd.destinationUrl, equals('https://catchandwatch.com/streambrand'));

      // Android: YouTube embeds, marked ads, and video ads remain allowed; non-ad static image is still rejected
      expect(ReelsProvider.isPlayableCreatorReel(youtubeReel, isIOS: false), isTrue);
      expect(ReelsProvider.isPlayableCreatorReel(youtuBeShortReel, isIOS: false), isTrue);
      expect(ReelsProvider.isPlayableCreatorReel(magnificAdReel, isIOS: false), isTrue);
      expect(ReelsProvider.isPlayableCreatorReel(sponsoredMp4VideoAd, isIOS: false), isTrue);
      expect(ReelsProvider.isPlayableCreatorReel(imageOnlyReel, isIOS: false), isFalse);
    });
  });

  group('ReelsProvider Feed, Search & Target Reel Filtering', () {
    late _FakeReelsRepository fakeRepository;
    late _TestVideoPlayerPlatform fakeVideoPlatform;

    setUp(() {
      fakeRepository = _FakeReelsRepository();
      fakeVideoPlatform = _TestVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakeVideoPlatform;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('fetchReelsFeed filters YouTube and image ads on iOS while keeping creator reels and sponsored video ads in placement order', () async {
      fakeRepository.feedResponse = {
        'success': true,
        'reels': [
          {
            '_id': 'creator_1',
            'videoUrl': 'https://api.catchandwatch.com/uploads/reels/native_1.mp4',
            'caption': 'Creator Reel 1',
          },
          {
            '_id': 'yt_embed',
            'videoUrl': 'https://www.youtube.com/watch?v=abc123xyz',
            'caption': 'Aggregated YouTube Video',
          },
          {
            '_id': 'ad_banner',
            'videoUrl': 'https://magnific.com/ads/promo.jpg',
            'isAd': true,
            'adId': 'ad_1',
            'destinationUrl': 'https://magnific.com',
          },
          {
            '_id': 'sponsored_video_row',
            'adId': 'ad_vid_1',
            'campaignId': 'camp_10',
            'isAd': true,
            'isSponsored': true,
            'adType': 'video',
            'videoUrl': 'https://api.catchandwatch.com/uploads/ads/sponsored_spot.mp4',
            'advertiserName': 'Catch & Watch Originals',
            'ctaText': 'Explore',
            'destinationUrl': 'https://catchandwatch.com/originals',
          },
          {
            '_id': 'creator_2',
            'videoUrl': 'https://api.catchandwatch.com/api/reels/stream/creator_2_hls',
            'caption': 'Creator Reel 2 (Extensionless Stream)',
          },
        ],
      };

      final iosProvider = ReelsProvider(
        reelsRepository: fakeRepository,
        isIOSOverride: true,
        fetchInitialInteractions: false,
      );

      await iosProvider.fetchReelsFeed();

      expect(iosProvider.error, isNull);
      expect(iosProvider.hasFetchedFeed, isTrue);
      expect(
        iosProvider.reels.map((r) => r.id).toList(),
        equals(['creator_1', 'ad_vid_1', 'creator_2']),
      );
      final ReelModel placedAd = iosProvider.reels[1];
      expect(placedAd.isSponsoredAd, isTrue);
      expect(placedAd.advertiserName, equals('Catch & Watch Originals'));
      expect(placedAd.ctaText, equals('Explore'));

      final androidProvider = ReelsProvider(
        reelsRepository: fakeRepository,
        isIOSOverride: false,
        fetchInitialInteractions: false,
      );

      await androidProvider.fetchReelsFeed();

      expect(androidProvider.error, isNull);
      expect(
        androidProvider.reels.map((r) => r.id).toList(),
        equals(['creator_1', 'yt_embed', 'ad_1', 'ad_vid_1', 'creator_2']),
      );
    });

    test('fetchReelsFeed transitions to clean empty state when all items are filtered on iOS', () async {
      fakeRepository.feedResponse = {
        'success': true,
        'reels': [
          {
            '_id': 'yt_only',
            'videoUrl': 'https://youtu.be/abc123xyz',
            'caption': 'YouTube link',
          },
          {
            '_id': 'ad_only',
            'videoUrl': 'https://magnific.com/banner.png',
            'isAd': true,
            'adId': 'ad_99',
          },
        ],
      };

      final iosProvider = ReelsProvider(
        reelsRepository: fakeRepository,
        isIOSOverride: true,
        fetchInitialInteractions: false,
      );

      await iosProvider.fetchReelsFeed();

      expect(iosProvider.reels, isEmpty);
      expect(iosProvider.feedReels, isEmpty);
      expect(iosProvider.hasFetchedFeed, isTrue);
      expect(iosProvider.error, isNull);
    });

    test('searchReels and ensureReelVisible also enforce iOS compliance filtering', () async {
      fakeRepository.searchResponse = {
        'success': true,
        'reels': [
          {
            '_id': 'search_native',
            'videoUrl': 'https://api.catchandwatch.com/uploads/reels/search_hit.mp4',
          },
          {
            '_id': 'search_yt',
            'videoUrl': 'https://www.youtube.com/watch?v=search123',
          },
        ],
      };
      fakeRepository.reelByIdResponses['yt_target'] = {
        'success': true,
        'reel': {
          '_id': 'yt_target',
          'videoUrl': 'https://youtu.be/target123',
        },
      };
      fakeRepository.reelByIdResponses['native_target'] = {
        'success': true,
        'reel': {
          '_id': 'native_target',
          'videoUrl': 'https://api.catchandwatch.com/uploads/reels/target.mp4',
        },
      };

      final iosProvider = ReelsProvider(
        reelsRepository: fakeRepository,
        isIOSOverride: true,
        fetchInitialInteractions: false,
      );

      await iosProvider.searchReels('test');
      expect(iosProvider.searchResults.map((r) => r.id).toList(), equals(['search_native']));

      await iosProvider.ensureReelVisible('yt_target');
      expect(iosProvider.reels.any((r) => r.id == 'yt_target'), isFalse);

      await iosProvider.ensureReelVisible('native_target');
      expect(iosProvider.reels.map((r) => r.id).toList(), equals(['native_target']));
    });

    test('recordAdEvent posts IMPRESSION and CLICK to /api/ads/event and deduplicates IMPRESSION events', () async {
      final iosProvider = ReelsProvider(
        reelsRepository: fakeRepository,
        isIOSOverride: true,
        fetchInitialInteractions: false,
      );

      await iosProvider.recordAdEvent(
        adId: 'ad_555',
        campaignId: 'camp_777',
        eventType: 'IMPRESSION',
      );
      // Duplicate impression for the same ad must be ignored
      await iosProvider.recordAdEvent(
        adId: 'ad_555',
        campaignId: 'camp_777',
        eventType: 'impression',
      );

      expect(iosProvider.hasRecordedAdImpression('ad_555', campaignId: 'camp_777'), isTrue);
      expect(fakeRepository.recordedAdEvents.length, equals(1));
      expect(
        fakeRepository.recordedAdEvents.first,
        equals({
          'adId': 'ad_555',
          'campaignId': 'camp_777',
          'eventType': 'IMPRESSION',
        }),
      );

      // CLICK events are sent whenever user taps CTA/ad
      await iosProvider.recordAdEvent(
        adId: 'ad_555',
        campaignId: 'camp_777',
        eventType: 'CLICK',
      );
      expect(fakeRepository.recordedAdEvents.length, equals(2));
      expect(
        fakeRepository.recordedAdEvents.last,
        equals({
          'adId': 'ad_555',
          'campaignId': 'camp_777',
          'eventType': 'CLICK',
        }),
      );
    });

    test('AppUrl.platformHeaderValue returns x-platform: ios on iOS and android on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AppUrl.platformHeaderValue(), equals('ios'));

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppUrl.platformHeaderValue(), equals('android'));

      expect(AppUrl.platformHeaderValue(isIOS: true), equals('ios'));
      expect(AppUrl.platformHeaderValue(isIOS: false), equals('android'));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('ShortVideoPlayerScreen renders Sponsored label, advertiser details, and CTA on iOS and fires IMPRESSION once + CLICK on tap', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final iosProvider = ReelsProvider(
        reelsRepository: fakeRepository,
        isIOSOverride: true,
        fetchInitialInteractions: false,
      );

      final sponsoredAd = ReelModel.fromJson({
        '_id': 'ad_ui_1',
        'adId': 'ad_ui_1',
        'campaignId': 'camp_ui_99',
        'isAd': true,
        'isSponsored': true,
        'adType': 'video',
        'videoUrl': 'https://api.catchandwatch.com/uploads/ads/promo.mp4',
        'advertiserName': 'CineStream Plus',
        'caption': 'Stream exclusive premieres today',
        'ctaText': 'Subscribe Now',
        'destinationUrl': 'https://catchandwatch.com/subscribe',
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ReelsProvider>.value(value: iosProvider),
            ChangeNotifierProvider<CallProvider>(create: (_) => CallProvider()),
            ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
            ChangeNotifierProvider<BlockProvider>(create: (_) => BlockProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ShortVideoPlayerScreen(
                isVisible: true,
                initialReels: <ReelModel>[sponsoredAd],
                initialIndex: 0,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify Sponsored label, advertiser name, caption, and CTA button render on iOS
      expect(find.text('Sponsored'), findsWidgets);
      expect(find.text('CineStream Plus'), findsOneWidget);
      expect(find.text('Stream exclusive premieres today'), findsOneWidget);
      expect(find.text('Subscribe Now'), findsOneWidget);

      // Verify IMPRESSION event was recorded exactly once
      final impressionEvents = fakeRepository.recordedAdEvents
          .where((e) => e['eventType'] == 'IMPRESSION')
          .toList();
      expect(impressionEvents.length, equals(1));
      expect(impressionEvents.first['adId'], equals('ad_ui_1'));
      expect(impressionEvents.first['campaignId'], equals('camp_ui_99'));

      // Re-pumping does not duplicate the IMPRESSION event
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        fakeRepository.recordedAdEvents
            .where((e) => e['eventType'] == 'IMPRESSION')
            .length,
        equals(1),
      );

      // Tapping the CTA button records a CLICK event
      await tester.tap(find.text('Subscribe Now'));
      await tester.pump();

      final clickEvents = fakeRepository.recordedAdEvents
          .where((e) => e['eventType'] == 'CLICK')
          .toList();
      expect(clickEvents.length, equals(1));
      expect(clickEvents.first['adId'], equals('ad_ui_1'));
      expect(clickEvents.first['campaignId'], equals('camp_ui_99'));

      debugDefaultTargetPlatformOverride = null;
    });

    test('ReelModel.fromJson and isValidThumbnailUrl reject MP4/HLS/stream URLs and null strings from thumbnail and avatar fields', () {
      final adWithMp4Thumbnail = ReelModel.fromJson({
        '_id': 'ad_bad_thumb',
        'adId': 'ad_bad_thumb',
        'isAd': true,
        'isSponsored': true,
        'mediaUrl': 'uploads/ads/spot_video.mp4',
        // Backend accidentally sends video file or "null" string as thumbnail/logo
        'thumbnailUrl': 'uploads/ads/spot_video.mp4',
        'advertiserLogo': 'null',
        'destinationUrl': 'https://catchandwatch.com/offer',
        'url': 'https://catchandwatch.com/offer',
      });

      // Actual videoUrl must be the MP4 stream, never destinationUrl
      expect(
        adWithMp4Thumbnail.videoUrl,
        equals('https://api.catchandwatch.com/uploads/ads/spot_video.mp4'),
      );
      // MP4 URL and "null" string must be rejected from thumbnail and advertiserLogo
      expect(adWithMp4Thumbnail.thumbnail, isNull);
      expect(adWithMp4Thumbnail.advertiserLogo, isNull);

      expect(
        ReelModel.isValidThumbnailUrl(
          'https://api.catchandwatch.com/uploads/ads/spot_video.mp4',
        ),
        isFalse,
      );
      expect(
        ReelModel.isValidThumbnailUrl(
          'https://api.catchandwatch.com/uploads/ads/master.m3u8',
        ),
        isFalse,
      );
      expect(
        ReelModel.isValidThumbnailUrl(
          'https://api.catchandwatch.com/api/reels/stream/65f0123456',
        ),
        isFalse,
      );
      expect(
        ReelModel.isValidThumbnailUrl('https://api.catchandwatch.com/null'),
        isFalse,
      );
      expect(
        ReelModel.isValidThumbnailUrl(
          'https://api.catchandwatch.com/uploads/thumbs/valid_poster.jpg',
          videoUrl: 'https://api.catchandwatch.com/uploads/ads/spot_video.mp4',
        ),
        isTrue,
      );
    });

    testWidgets('Sponsored video surface remains visible on iOS when AVPlayer reports Size.zero or 1080x1920 and when switching between reels and sponsored ads', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      fakeVideoPlatform.initialSize = Size.zero; // Simulate iOS AVPlayer reporting 0x0 on initial readyToPlay

      try {
        final iosProvider = ReelsProvider(
          reelsRepository: fakeRepository,
          isIOSOverride: true,
          fetchInitialInteractions: false,
        );

        final creatorReel = ReelModel.fromJson({
          '_id': 'creator_reel_1',
          'videoUrl': 'https://api.catchandwatch.com/uploads/reels/creator1.mp4',
          'thumbnail': 'https://api.catchandwatch.com/uploads/reels/creator1.mp4', // invalid MP4 thumbnail
          'caption': 'Creator Reel 1',
        });
        final sponsoredReel = ReelModel.fromJson({
          '_id': 'sponsored_ad_2',
          'adId': 'sponsored_ad_2',
          'campaignId': 'camp_202',
          'isAd': true,
          'isSponsored': true,
          'mediaUrl': 'https://api.catchandwatch.com/uploads/ads/sponsored_ad_2.mp4',
          'thumbnailUrl': 'https://api.catchandwatch.com/uploads/ads/sponsored_ad_2.mp4', // invalid MP4 thumbnail
          'advertiserName': 'Apex Brand',
          'ctaText': 'Shop Now',
          'destinationUrl': 'https://catchandwatch.com/apex',
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ReelsProvider>.value(value: iosProvider),
              ChangeNotifierProvider<CallProvider>(create: (_) => CallProvider()),
              ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
              ChangeNotifierProvider<BlockProvider>(create: (_) => BlockProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ShortVideoPlayerScreen(
                  isVisible: true,
                  initialReels: <ReelModel>[sponsoredReel, creatorReel],
                  initialIndex: 0,
                ),
              ),
            ),
          ),
        );

        // Pump microtasks so VideoPlayerController.initialize() completes with Size.zero
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Verify actual mediaUrl was passed to VideoPlayerController, NOT destinationUrl or thumbnailUrl
        expect(
          fakeVideoPlatform.createdUris,
          contains('https://api.catchandwatch.com/uploads/ads/sponsored_ad_2.mp4'),
        );
        expect(
          fakeVideoPlatform.createdUris,
          isNot(contains('https://catchandwatch.com/apex')),
        );
        expect(fakeVideoPlatform.playingTextures, contains(1));

        // VideoPlayer must be mounted and have a non-zero visible size even when controller.value.size is Size.zero
        expect(find.byType(VideoPlayer), findsOneWidget);
        final Size surfaceSizeAtZero = tester.getSize(find.byType(VideoPlayer));
        expect(surfaceSizeAtZero.width, greaterThan(0));
        expect(surfaceSizeAtZero.height, greaterThan(0));

        // Now switch to the next page with standard 1080x1920 dimensions
        fakeVideoPlatform.initialSize = const Size(1080, 1920);
        await tester.drag(find.byType(PageView), const Offset(0, -600));
        await tester.pumpAndSettle();

        expect(
          fakeVideoPlatform.createdUris,
          contains('https://api.catchandwatch.com/uploads/reels/creator1.mp4'),
        );
        expect(find.byType(VideoPlayer), findsWidgets);
        final Size surfaceSizeStandard = tester.getSize(find.byType(VideoPlayer).last);
        expect(surfaceSizeStandard.width, greaterThan(0));
        expect(surfaceSizeStandard.height, greaterThan(0));
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('Reels pull-to-refresh, Retry & playback error handling', () {
    late _FakeReelsRepository fakeRepository;
    late _TestVideoPlayerPlatform fakeVideoPlatform;
    late ReelVideoProbe originalProbe;
    final List<String> probedUrls = <String>[];

    Map<String, dynamic> creator(String id, String file) => <String, dynamic>{
          '_id': id,
          'videoUrl': 'https://api.catchandwatch.com/uploads/reels/$file.mp4',
          'caption': 'Caption $id',
        };

    Map<String, dynamic> sponsored(String id, String file) => <String, dynamic>{
          '_id': id,
          'adId': id,
          'campaignId': 'camp_$id',
          'isAd': true,
          'isSponsored': true,
          'videoUrl': 'https://api.catchandwatch.com/uploads/ads/$file.mp4',
          'advertiserName': 'Brand $id',
          'ctaText': 'Open',
          'destinationUrl': 'https://catchandwatch.com/$id',
        };

    setUp(() {
      fakeRepository = _FakeReelsRepository();
      fakeVideoPlatform = _TestVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakeVideoPlatform;
      originalProbe = debugReelVideoProbe;
      probedUrls.clear();
      debugReelVideoProbe = (String url, Map<String, String> headers) async {
        probedUrls.add(url);
        return const ReelVideoProbeResult(statusCode: 403, contentType: 'text/html');
      };
    });

    tearDown(() {
      debugReelVideoProbe = originalProbe;
    });

    ReelsProvider newProvider() => ReelsProvider(
          reelsRepository: fakeRepository,
          isIOSOverride: true,
          fetchInitialInteractions: false,
        );

    Future<void> pumpFeed(WidgetTester tester, ReelsProvider provider) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ReelsProvider>.value(value: provider),
            ChangeNotifierProvider<CallProvider>(create: (_) => CallProvider()),
            ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
            ChangeNotifierProvider<BlockProvider>(create: (_) => BlockProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ShortVideoPlayerScreen(isVisible: true)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    test('redactReelUrl never exposes query strings, tokens or userinfo', () {
      expect(
        redactReelUrl('https://u:p@cdn.example.com/v/a.mp4?X-Amz-Signature=secret&token=abc'),
        equals('https://cdn.example.com/v/a.mp4?<redacted>'),
      );
      expect(redactReelUrl('https://api.catchandwatch.com/v/a.mp4'),
          equals('https://api.catchandwatch.com/v/a.mp4'));
    });

    test('refreshReelsFeed replaces stale feed, dedupes, keeps ad interleaving, shares in-flight request', () async {
      fakeRepository.feedResponse = {
        'success': true,
        'reels': [creator('old_1', 'old1'), sponsored('ad_old', 'adold')],
      };
      final provider = newProvider();
      await provider.fetchReelsFeed();
      expect(provider.reels.map((r) => r.id), equals(['old_1', 'ad_old']));

      fakeRepository.feedResponse = {
        'success': true,
        'reels': [
          creator('new_1', 'new1'),
          sponsored('ad_new', 'adnew'),
          creator('new_2', 'new2'),
          creator('new_1', 'new1'), // duplicate must be dropped
          sponsored('ad_new', 'adnew'), // duplicate ad must be dropped
        ],
      };
      final Future<bool> first = provider.refreshReelsFeed();
      final Future<bool> second = provider.refreshReelsFeed();
      expect(identical(first, second), isTrue);
      expect(await first, isTrue);

      expect(provider.error, isNull);
      expect(provider.reels.map((r) => r.id), equals(['new_1', 'ad_new', 'new_2']));
      expect(provider.reels[1].isSponsoredAd, isTrue);
    });

    test('refreshReelsFeed returns false and keeps the previous feed when the refresh fails', () async {
      fakeRepository.feedResponse = {
        'success': true,
        'reels': [creator('keep_1', 'keep1'), creator('keep_2', 'keep2')],
      };
      final provider = newProvider();
      await provider.fetchReelsFeed();

      fakeRepository.feedResponse = {'success': false, 'message': 'boom'};
      expect(await provider.refreshReelsFeed(), isFalse);
      expect(provider.error, equals('boom'));
      expect(provider.reels.map((r) => r.id), equals(['keep_1', 'keep_2']));
      expect(provider.isLoading, isFalse);
    });

    testWidgets('Retry reinitializes the same reel with a fresh controller, shows reason, and recovers', (tester) async {
      fakeRepository.feedResponse = {
        'success': true,
        'reels': [creator('r1', 'r1')],
      };
      final provider = newProvider();
      await provider.fetchReelsFeed();
      fakeVideoPlatform.failuresRemaining = 1;

      await pumpFeed(tester, provider);

      expect(find.text('Unable to play video'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // Probe classified the 403 as expired/denied and showed a meaningful message.
      expect(find.textContaining('expired or access was denied'), findsOneWidget);
      expect(probedUrls, equals(['https://api.catchandwatch.com/uploads/reels/r1.mp4']));
      expect(find.byType(VideoPlayer), findsNothing);
      expect(fakeVideoPlatform.createdUris.length, equals(1));

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fakeVideoPlatform.createdUris.length, equals(2));
      expect(
        fakeVideoPlatform.createdUris.last,
        equals('https://api.catchandwatch.com/uploads/reels/r1.mp4'),
      );
      expect(find.text('Unable to play video'), findsNothing);
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(fakeVideoPlatform.playingTextures, isNotEmpty);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('Overlapping Retry taps do not create duplicate controllers', (tester) async {
      fakeRepository.feedResponse = {
        'success': true,
        'reels': [sponsored('ad_r', 'adr')],
      };
      final provider = newProvider();
      await provider.fetchReelsFeed();
      fakeVideoPlatform.failuresRemaining = 1;
      await pumpFeed(tester, provider);
      expect(find.text('Retry'), findsOneWidget);

      // Hold the next create() so the retry stays in flight.
      fakeVideoPlatform.createGate = Completer<void>();
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // While the retry is in flight the error UI is replaced by a loading spinner,
      // so the Retry button cannot be tapped again and no extra controller is created.
      expect(find.text('Unable to play video'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(fakeVideoPlatform.createdUris.length, equals(2)); // initial + exactly one retry

      fakeVideoPlatform.createGate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fakeVideoPlatform.createdUris.length, equals(2));
      expect(find.text('Unable to play video'), findsNothing);
      expect(find.byType(VideoPlayer), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('Switching to another reel and back re-initializes a previously failed sponsored reel', (tester) async {
      fakeRepository.feedResponse = {
        'success': true,
        'reels': [sponsored('ad_s', 'ads'), creator('c2', 'c2')],
      };
      final provider = newProvider();
      await provider.fetchReelsFeed();
      fakeVideoPlatform.failuresRemaining = 1;
      await pumpFeed(tester, provider);
      expect(find.text('Unable to play video'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Unable to play video'), findsNothing);
      expect(
        fakeVideoPlatform.createdUris,
        contains('https://api.catchandwatch.com/uploads/reels/c2.mp4'),
      );

      await tester.drag(find.byType(PageView), const Offset(0, 600));
      await tester.pumpAndSettle();

      expect(find.text('Unable to play video'), findsNothing);
      expect(find.text('Sponsored'), findsWidgets);
      expect(find.text('Open'), findsOneWidget); // CTA preserved
      expect(find.byType(VideoPlayer), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('Pull-to-refresh after a failed video replaces the stale feed and recovers playback', (tester) async {
      fakeRepository.feedResponse = {
        'success': true,
        'reels': [creator('stale', 'stale')],
      };
      final provider = newProvider();
      await provider.fetchReelsFeed();
      fakeVideoPlatform.failuresRemaining = 1;
      await pumpFeed(tester, provider);
      expect(find.text('Unable to play video'), findsOneWidget);

      fakeRepository.feedResponse = {
        'success': true,
        'reels': [creator('fresh_1', 'fresh1'), sponsored('ad_f', 'adf'), creator('fresh_2', 'fresh2')],
      };

      await tester.fling(find.byType(PageView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(provider.reels.map((r) => r.id), equals(['fresh_1', 'ad_f', 'fresh_2']));
      expect(
        fakeVideoPlatform.createdUris,
        contains('https://api.catchandwatch.com/uploads/reels/fresh1.mp4'),
      );
      expect(find.text('Unable to play video'), findsNothing);
      expect(find.byType(VideoPlayer), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('Failed pull-to-refresh keeps the existing feed and shows an error message', (tester) async {
      fakeRepository.feedResponse = {
        'success': true,
        'reels': [creator('k1', 'k1'), creator('k2', 'k2')],
      };
      final provider = newProvider();
      await provider.fetchReelsFeed();
      await pumpFeed(tester, provider);
      expect(find.byType(VideoPlayer), findsOneWidget);

      fakeRepository.feedResponse = {'success': false, 'message': 'server down'};
      await tester.fling(find.byType(PageView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text("Couldn't refresh reels. Showing your previous feed."), findsOneWidget);
      expect(provider.reels.map((r) => r.id), equals(['k1', 'k2']));
      expect(find.byType(VideoPlayer), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('Video Playback Request Header Security (AppUrl.buildVideoRequestHeaders)', () {
    test('attaches JWT Authorization header ONLY to trusted Catch & Watch API HTTPS URLs', () {
      const String sampleJwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.signature';

      final trustedStreamHeaders = AppUrl.buildVideoRequestHeaders(
        'https://api.catchandwatch.com/api/reels/stream/65f0123456789abcdef',
        token: sampleJwt,
      );
      expect(trustedStreamHeaders['Referer'], equals('https://catchandwatch.com'));
      expect(trustedStreamHeaders['Authorization'], equals('Bearer $sampleJwt'));

      final trustedUploadHeaders = AppUrl.buildVideoRequestHeaders(
        'https://api.catchandwatch.com/uploads/reels/creator_video.mp4',
        token: sampleJwt,
      );
      expect(trustedUploadHeaders['Authorization'], equals('Bearer $sampleJwt'));

      final trustedHlsHeaders = AppUrl.buildVideoRequestHeaders(
        'https://api.catchandwatch.com/uploads/movies/master.m3u8',
        token: sampleJwt,
        extraHeaders: const {'User-Agent': 'CustomPlayer/1.0'},
      );
      expect(trustedHlsHeaders['Authorization'], equals('Bearer $sampleJwt'));
      expect(trustedHlsHeaders['User-Agent'], equals('CustomPlayer/1.0'));
    });

    test('never leaks JWT Authorization header to external CDNs, signed S3 URLs, or spoofed hosts', () {
      const String sampleJwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.signature';

      final List<String> untrustedUrls = <String>[
        'https://d111111abcdef8.cloudfront.net/reels/video.mp4',
        'https://catchandwatch-media.s3.amazonaws.com/video.mp4?X-Amz-Signature=abc',
        'https://res.cloudinary.com/demo/video/upload/sample.mp4',
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://magnific.com/ads/banner.jpg',
        // Insecure HTTP downgrade to same host must not carry bearer token
        'http://api.catchandwatch.com/uploads/reels/video.mp4',
        // Authority userInfo spoofing attempt
        'https://api.catchandwatch.com@evil.example.com/video.mp4',
        // Subdomain suffix spoofing attempt
        'https://api.catchandwatch.com.evil.example.com/video.mp4',
        // Non-standard port on trusted host
        'https://api.catchandwatch.com:8443/uploads/reels/video.mp4',
      ];

      for (final String url in untrustedUrls) {
        expect(
          AppUrl.isTrustedApiUrl(url),
          isFalse,
          reason: 'Expected $url to be classified as untrusted',
        );
        final headers = AppUrl.buildVideoRequestHeaders(
          url,
          token: sampleJwt,
          extraHeaders: const {'User-Agent': 'CustomPlayer/1.0'},
        );
        expect(
          headers.containsKey('Authorization'),
          isFalse,
          reason: 'Authorization header must not be attached to $url',
        );
        expect(headers['Referer'], equals('https://catchandwatch.com'));
        expect(headers['User-Agent'], equals('CustomPlayer/1.0'));
      }
    });

    test('omits Authorization header when token is null or blank even for trusted URLs', () {
      const String trustedUrl = 'https://api.catchandwatch.com/uploads/reels/video.mp4';

      expect(
        AppUrl.buildVideoRequestHeaders(trustedUrl, token: null).containsKey('Authorization'),
        isFalse,
      );
      expect(
        AppUrl.buildVideoRequestHeaders(trustedUrl, token: '   ').containsKey('Authorization'),
        isFalse,
      );
    });
  });

  group('Defunct Seed Media, ATS HTTPS Upgrade & Fresh Reel Retry Recovery', () {
    test('isDefunctSampleMediaUrl identifies defunct Google Storage sample bucket and demo reel URLs', () {
      expect(
        ReelsProvider.isDefunctSampleMediaUrl(
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4',
        ),
        isTrue,
      );
      expect(
        ReelsProvider.isDefunctSampleMediaUrl(
          'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        ),
        isTrue,
      );
      expect(
        ReelsProvider.isDefunctSampleMediaUrl(
          'https://catchandwatchzone.b-cdn.net/movies/videos/demo_reel.mp4',
        ),
        isTrue,
      );
      expect(
        ReelsProvider.isDefunctSampleMediaUrl(
          'https://catchandwatchzone.b-cdn.net/movies/videos/1793962645817-877196831.mp4',
        ),
        isFalse,
      );
    });

    test('isPlayableCreatorReel filters out defunct sample media on all platforms', () {
      final defunctReel = ReelModel(
        id: 'defunct_1',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      );
      expect(ReelsProvider.isPlayableCreatorReel(defunctReel, isIOS: true), isFalse);
      expect(ReelsProvider.isPlayableCreatorReel(defunctReel, isIOS: false), isFalse);

      final validReel = ReelModel(
        id: 'valid_1',
        videoUrl: 'https://catchandwatchzone.b-cdn.net/movies/videos/1793962645817-877196831.mp4',
      );
      expect(ReelsProvider.isPlayableCreatorReel(validReel, isIOS: true), isTrue);
      expect(ReelsProvider.isPlayableCreatorReel(validReel, isIOS: false), isTrue);
    });

    test('ReelModel.normalizeMediaUrl upgrades catchandwatch.com HTTP URLs to HTTPS for ATS compliance', () {
      expect(
        ReelModel.normalizeMediaUrl('http://api.catchandwatch.com/uploads/reels/video.mp4'),
        equals('https://api.catchandwatch.com/uploads/reels/video.mp4'),
      );
      expect(
        ReelModel.normalizeMediaUrl('http://catchandwatch.com/uploads/reels/video.mp4'),
        equals('https://catchandwatch.com/uploads/reels/video.mp4'),
      );
    });

    test('ReelsProvider.fetchFreshReel queries repository by ID and updates reel in-place', () async {
      final fakeRepo = _FakeReelsRepository();
      fakeRepo.feedResponse = {
        'success': true,
        'reels': [
          {
            '_id': 'reel_101',
            'videoUrl': 'https://catchandwatchzone.b-cdn.net/movies/videos/old.mp4',
            'caption': 'Initial Caption',
          }
        ]
      };
      final provider = ReelsProvider(
        reelsRepository: fakeRepo,
        isIOSOverride: true,
        fetchInitialInteractions: false,
      );
      await provider.fetchReelsFeed();
      expect(provider.reels.first.videoUrl, equals('https://catchandwatchzone.b-cdn.net/movies/videos/old.mp4'));

      // Simulate updated/fresh videoUrl from backend endpoint GET /api/reels/:id
      fakeRepo.reelByIdResponses['reel_101'] = {
        'success': true,
        'reel': {
          '_id': 'reel_101',
          'videoUrl': 'https://catchandwatchzone.b-cdn.net/movies/videos/fresh_updated.mp4',
          'caption': 'Fresh Caption',
        }
      };

      final freshReel = await provider.fetchFreshReel('reel_101');
      expect(freshReel, isNotNull);
      expect(freshReel!.videoUrl, equals('https://catchandwatchzone.b-cdn.net/movies/videos/fresh_updated.mp4'));
      expect(provider.reels.first.videoUrl, equals('https://catchandwatchzone.b-cdn.net/movies/videos/fresh_updated.mp4'));
    });
  });

  group('iOS AVPlayer Zero Presentation Size, Delayed Dimensions & Resilient Playback', () {
    late _FakeReelsRepository fakeRepo;
    late _TestVideoPlayerPlatform fakePlatform;
    late ReelVideoProbe originalProbe;

    setUp(() {
      fakeRepo = _FakeReelsRepository();
      fakePlatform = _TestVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakePlatform;
      originalProbe = debugReelVideoProbe;
      debugReelVideoProbe = (String url, Map<String, String> headers) async {
        return const ReelVideoProbeResult(statusCode: 200, contentType: 'video/mp4');
      };
    });

    tearDown(() {
      debugReelVideoProbe = originalProbe;
    });

    Widget createTestApp(List<ReelModel> reels, {int initialIndex = 0}) {
      final provider = ReelsProvider(
        reelsRepository: fakeRepo,
        isIOSOverride: true,
        fetchInitialInteractions: false,
      );
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ReelsProvider>.value(value: provider),
          ChangeNotifierProvider<CallProvider>(create: (_) => CallProvider()),
          ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
          ChangeNotifierProvider<BlockProvider>(create: (_) => BlockProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ShortVideoPlayerScreen(
              isVisible: true,
              initialReels: reels,
              initialIndex: initialIndex,
            ),
          ),
        ),
      );
    }

    testWidgets('Initial dimensions 0x0 keeps video texture visible and non-zero without black void', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        fakePlatform.initialSize = Size.zero;

        final adReel = ReelModel.fromJson({
          '_id': 'ad_zero_1',
          'adId': 'ad_zero_1',
          'isAd': true,
          'isSponsored': true,
          'videoUrl': 'https://catchandwatchzone.b-cdn.net/ads/others/1787727173841-776073966.mp4',
          'caption': 'Zero Size Ad',
        });

        await tester.pumpWidget(createTestApp([adReel]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(VideoPlayer), findsOneWidget);
        final Size surfaceSize = tester.getSize(find.byType(VideoPlayer));
        expect(surfaceSize.width, greaterThan(0));
        expect(surfaceSize.height, greaterThan(0));
        expect(find.text('Unable to play video'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Delayed presentation dimensions when controller initializes with dimensions updates layout smoothly', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        fakePlatform.initialSize = Size.zero;

        final adReel = ReelModel.fromJson({
          '_id': 'ad_zero_first',
          'adId': 'ad_zero_first',
          'isAd': true,
          'isSponsored': true,
          'videoUrl': 'https://catchandwatchzone.b-cdn.net/ads/others/1787727173841-776073966.mp4',
          'caption': 'Zero Size First',
        });
        final knownSizeReel = ReelModel.fromJson({
          '_id': 'ad_known_second',
          'adId': 'ad_known_second',
          'isAd': true,
          'isSponsored': true,
          'videoUrl': 'https://catchandwatchzone.b-cdn.net/ads/others/second.mp4',
          'caption': 'Known Size Second',
        });

        await tester.pumpWidget(createTestApp([adReel, knownSizeReel]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(VideoPlayer), findsOneWidget);
        final Size surfaceSizeZero = tester.getSize(find.byType(VideoPlayer));
        expect(surfaceSizeZero.width, greaterThan(0));
        expect(surfaceSizeZero.height, greaterThan(0));

        fakePlatform.initialSize = const Size(720, 1280);
        await tester.drag(find.byType(PageView), const Offset(0, -600));
        await tester.pumpAndSettle();

        expect(find.byType(VideoPlayer), findsWidgets);
        final Size surfaceSizeResolved = tester.getSize(find.byType(VideoPlayer).last);
        expect(surfaceSizeResolved.width, greaterThan(0));
        expect(surfaceSizeResolved.height, greaterThan(0));
        expect(find.text('Unable to play video'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Audio playing while dimensions remain zero does NOT abort playback after 4+ seconds', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        fakePlatform.initialSize = Size.zero;

        final adReel = ReelModel.fromJson({
          '_id': 'ad_audio_only_size_zero',
          'adId': 'ad_audio_only_size_zero',
          'isAd': true,
          'isSponsored': true,
          'videoUrl': 'https://catchandwatchzone.b-cdn.net/ads/others/1787727173841-776073966.mp4',
          'caption': 'Audio playing with moov at end',
        });

        await tester.pumpWidget(createTestApp([adReel]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Advance time beyond 4 seconds
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(seconds: 2));

        // Must NOT fail or show unsupportedFormat
        expect(find.text('Unable to play video'), findsNothing);
        expect(find.text("This video format isn't supported on your device."), findsNothing);
        expect(find.byType(VideoPlayer), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Actual native player error displays retryable error state and recovers on retry', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        fakePlatform.failuresRemaining = 1;

        final creatorReel = ReelModel.fromJson({
          '_id': 'reel_actual_err_1',
          'videoUrl': 'https://catchandwatchzone.b-cdn.net/movies/videos/creator.mp4',
          'caption': 'Creator reel',
        });

        await tester.pumpWidget(createTestApp([creatorReel]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Unable to play video'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Tapping Retry recovers playback
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(VideoPlayer), findsOneWidget);
        expect(find.text('Unable to play video'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Sponsored-to-creator reel switching handles textures and dimensions seamlessly', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        fakePlatform.initialSize = Size.zero;

        final adReel = ReelModel.fromJson({
          '_id': 'ad_switch_1',
          'adId': 'ad_switch_1',
          'isAd': true,
          'isSponsored': true,
          'videoUrl': 'https://catchandwatchzone.b-cdn.net/ads/others/1787727173841-776073966.mp4',
          'caption': 'Sponsored Reel',
        });
        final creatorReel = ReelModel.fromJson({
          '_id': 'creator_switch_2',
          'videoUrl': 'https://catchandwatchzone.b-cdn.net/movies/videos/1793962645817-877196831.mp4',
          'caption': 'Creator Reel',
        });

        await tester.pumpWidget(createTestApp([adReel, creatorReel]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Sponsored'), findsWidgets);
        expect(find.byType(VideoPlayer), findsOneWidget);

        // Swipe to creator reel
        fakePlatform.initialSize = const Size(1080, 1920);
        await tester.drag(find.byType(PageView), const Offset(0, -600));
        await tester.pumpAndSettle();

        expect(find.text('Reels'), findsWidgets);
        expect(find.byType(VideoPlayer), findsWidgets);

        // Swipe back to sponsored reel
        await tester.drag(find.byType(PageView), const Offset(0, 600));
        await tester.pumpAndSettle();

        expect(find.text('Sponsored'), findsWidgets);
        expect(find.byType(VideoPlayer), findsWidgets);
        expect(find.text('Unable to play video'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
