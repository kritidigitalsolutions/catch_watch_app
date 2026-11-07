import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:catch_watch/utils/share_helper.dart';

class _FakeSharePlatform extends SharePlatform {
  ShareParams? lastParams;
  Completer<ShareResult>? pendingCompleter;

  @override
  Future<ShareResult> share(ShareParams params) {
    lastParams = params;
    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }
    return Future.value(const ShareResult('success', ShareResultStatus.success));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSharePlatform fakeSharePlatform;
  late SharePlatform originalPlatform;

  setUp(() {
    originalPlatform = SharePlatform.instance;
    fakeSharePlatform = _FakeSharePlatform();
    SharePlatform.instance = fakeSharePlatform;
    ShareHelper.debugSharePlusInstance = SharePlus.custom(fakeSharePlatform);
  });

  tearDown(() {
    SharePlatform.instance = originalPlatform;
    ShareHelper.debugSharePlusInstance = null;
    debugDefaultTargetPlatformOverride = null;
  });

  group('ShareHelper.buildShareMessage Compliance & Formatting', () {
    test('iOS share text strictly excludes Android link and retains iOS link (Guideline 2.3.10)', () {
      final String message = ShareHelper.buildShareMessage(
        text: 'Check out this amazing movie',
        contentId: 'movie_123',
        contentType: 'movie',
        isIOS: true,
      );

      // Must NOT contain any Android or Google Play reference on iOS
      expect(message, isNot(contains('Android:')));
      expect(message, isNot(contains('play.google.com')));

      // Must contain iOS App Store link and website URL
      expect(message, contains('iOS: https://apps.apple.com/app/catch-watch/id6819192529'));
      expect(message, contains('Watch here: https://catchandwatch.com/movie/movie_123'));
      expect(message, contains('Check out this amazing movie'));
      expect(message, contains('Download Catch Watch App:'));
    });

    test('Android share text preserves both Android Play Store link and iOS link', () {
      final String message = ShareHelper.buildShareMessage(
        text: 'Check out this trending reel',
        contentId: 'reel_456',
        contentType: 'reel',
        isIOS: false,
      );

      // Must contain both Android and iOS download links on Android
      expect(message, contains('Android: https://play.google.com/store/apps/details?id=com.catchandwatch1.app'));
      expect(message, contains('iOS: https://apps.apple.com/app/catch-watch/id6819192529'));
      expect(message, contains('Watch here: https://catchandwatch.com/reel/reel_456'));
      expect(message, contains('Check out this trending reel'));
    });

    test('Omits content link when contentId is null or empty', () {
      final String iosMsg = ShareHelper.buildShareMessage(
        text: 'General App Invitation',
        contentId: null,
        isIOS: true,
      );

      expect(iosMsg, isNot(contains('Watch here:')));
      expect(iosMsg, contains('General App Invitation'));
      expect(iosMsg, contains('iOS: https://apps.apple.com/app/catch-watch/id6819192529'));
      expect(iosMsg, isNot(contains('Android:')));
    });

    test('isIOSPlatform respects debugDefaultTargetPlatformOverride', () {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(ShareHelper.isIOSPlatform(), isTrue);

        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        expect(ShareHelper.isIOSPlatform(), isFalse);

        // Explicit override takes precedence over platform default
        expect(ShareHelper.isIOSPlatform(isIOSOverride: true), isTrue);
        expect(ShareHelper.isIOSPlatform(isIOSOverride: false), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('ShareHelper.resolveSharePositionOrigin iPad & Dimension Safety', () {
    test('Returns explicit non-zero origin when passed by caller', () {
      const Rect customRect = Rect.fromLTWH(50, 60, 200, 300);
      final Rect resolved = ShareHelper.resolveSharePositionOrigin(
        origin: customRect,
      );

      expect(resolved, equals(customRect));
      expect(resolved.width, equals(200));
      expect(resolved.height, equals(300));
    });

    test('Ignores zero or negative dimension rects and falls back safely', () {
      const Rect zeroRect = Rect.fromLTWH(0, 0, 0, 0);
      final Rect resolved = ShareHelper.resolveSharePositionOrigin(
        origin: zeroRect,
      );

      expect(resolved.width, greaterThan(0));
      expect(resolved.height, greaterThan(0));
      expect(resolved.isFinite, isTrue);
    });

    test('Returns safe non-zero origin even when context is null', () {
      final Rect resolved = ShareHelper.resolveSharePositionOrigin(
        origin: null,
        context: null,
      );

      expect(resolved, isNotNull);
      expect(resolved.width, greaterThan(0));
      expect(resolved.height, greaterThan(0));
      expect(resolved.left, greaterThanOrEqualTo(0));
      expect(resolved.top, greaterThanOrEqualTo(0));
    });

    testWidgets('Extracts non-zero button Rect from mounted BuildContext on iPad viewport', (WidgetTester tester) async {
      // Simulate iPad portrait dimensions (768 x 1024)
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Rect? capturedOrigin;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      capturedOrigin = ShareHelper.resolveSharePositionOrigin(context: context);
                    },
                    child: const SizedBox(
                      width: 140,
                      height: 48,
                      child: Center(child: Text('Share')),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Share'));
      await tester.pump();

      expect(capturedOrigin, isNotNull);
      expect(capturedOrigin!.width, greaterThanOrEqualTo(140));
      expect(capturedOrigin!.height, greaterThanOrEqualTo(48));
      expect(capturedOrigin!.left, greaterThan(0));
      expect(capturedOrigin!.top, greaterThan(0));
      expect(capturedOrigin!.right, lessThanOrEqualTo(768));
      expect(capturedOrigin!.bottom, lessThanOrEqualTo(1024));
    });
  });

  group('ShareHelper.shareContent End-to-End Execution', () {
    testWidgets('shareContent on iOS passes valid non-zero origin and excludes Android link', (WidgetTester tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        // iPad landscape viewport (1024 x 768)
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        await ShareHelper.shareContent(
                          title: 'Test Share Title',
                          text: 'Stream Catch Watch Today',
                          contentId: 'mov_99',
                          contentType: 'movie',
                          context: context,
                        );
                      },
                      child: const Text('Share Button'),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Share Button'));
        await tester.pumpAndSettle();

        final ShareParams? params = fakeSharePlatform.lastParams;
        expect(params, isNotNull);

        // Verify iOS text excludes Android link
        expect(params!.text, isNot(contains('Android:')));
        expect(params.text, contains('iOS: https://apps.apple.com/app/catch-watch/id6819192529'));
        expect(params.text, contains('Watch here: https://catchandwatch.com/movie/mov_99'));
        expect(params.subject, equals('Test Share Title'));

        // Verify iPad popover anchor is non-zero
        expect(params.sharePositionOrigin, isNotNull);
        expect(params.sharePositionOrigin!.width, greaterThan(0));
        expect(params.sharePositionOrigin!.height, greaterThan(0));
        expect(params.sharePositionOrigin!.isFinite, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('shareContent on Android preserves Play Store link and includes non-zero origin', (WidgetTester tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        await ShareHelper.shareContent(
                          title: 'Android Share Title',
                          text: 'Catch Watch on Android',
                          contentId: 'reel_88',
                          contentType: 'reel',
                          context: context,
                        );
                      },
                      child: const Text('Share Button'),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Share Button'));
        await tester.pumpAndSettle();

        final ShareParams? params = fakeSharePlatform.lastParams;
        expect(params, isNotNull);

        // Android text must contain Google Play Store link
        expect(params!.text, contains('Android: https://play.google.com/store/apps/details?id=com.catchandwatch1.app'));
        expect(params.text, contains('iOS: https://apps.apple.com/app/catch-watch/id6819192529'));
        expect(params.text, contains('Watch here: https://catchandwatch.com/reel/reel_88'));
        expect(params.subject, equals('Android Share Title'));

        // Non-zero origin is safely provided across all platforms
        expect(params.sharePositionOrigin, isNotNull);
        expect(params.sharePositionOrigin!.width, greaterThan(0));
        expect(params.sharePositionOrigin!.height, greaterThan(0));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('shareContent without BuildContext falls back to non-zero origin without throwing', () async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await ShareHelper.shareContent(
          title: 'Background Share',
          text: 'Text without context',
          contentId: 'c1',
        );

        final ShareParams? params = fakeSharePlatform.lastParams;
        expect(params, isNotNull);
        expect(params!.text, contains('iOS:'));
        expect(params.text, isNot(contains('Android:')));

        // Infallible non-zero origin
        expect(params.sharePositionOrigin, isNotNull);
        expect(params.sharePositionOrigin!.width, greaterThan(0));
        expect(params.sharePositionOrigin!.height, greaterThan(0));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('shareFile passes valid non-zero origin and attaches file payload on iPad', (WidgetTester tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        await ShareHelper.shareFile(
                          path: '/tmp/test_export.mp4',
                          text: 'Exported Reel',
                          context: context,
                        );
                      },
                      child: const Text('Share File Button'),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Share File Button'));
        await tester.pumpAndSettle();

        final ShareParams? params = fakeSharePlatform.lastParams;
        expect(params, isNotNull);
        expect(params!.files, isNotNull);
        expect(params.files!.length, equals(1));
        expect(params.files!.first.path, equals('/tmp/test_export.mp4'));
        expect(params.text, equals('Exported Reel'));

        // Non-zero origin on iPad
        expect(params.sharePositionOrigin, isNotNull);
        expect(params.sharePositionOrigin!.width, greaterThan(0));
        expect(params.sharePositionOrigin!.height, greaterThan(0));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
