import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareHelper {
  static const String appStoreLink = 'https://apps.apple.com/app/catch-watch/id6819192529';
  static const String playStoreLink = 'https://play.google.com/store/apps/details?id=com.catchandwatch1.app';
  static const String websiteUrl = 'https://catchandwatch.com';

  /// Test hook to inject custom SharePlus platform in unit/widget tests.
  @visibleForTesting
  static SharePlus? debugSharePlusInstance;

  static SharePlus get _sharePlus => debugSharePlusInstance ?? SharePlus.instance;

  /// Resolves whether the current target platform is iOS.
  ///
  /// Respects [isIOSOverride] when provided (e.g. for testing) and defaults
  /// to checking [defaultTargetPlatform].
  static bool isIOSPlatform({bool? isIOSOverride}) {
    if (isIOSOverride != null) return isIOSOverride;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Builds the compliant share message text.
  ///
  /// On iOS, the Android Play Store URL is strictly excluded to comply with
  /// Apple App Store Review Guideline 2.3.10. On Android (and other platforms),
  /// the Google Play Store URL is preserved.
  static String buildShareMessage({
    required String text,
    String? contentId,
    String contentType = 'video',
    bool? isIOS,
  }) {
    String shareMessage = '$text\n\n';

    if (contentId != null && contentId.isNotEmpty) {
      shareMessage += 'Watch here: $websiteUrl/$contentType/$contentId\n\n';
    }

    final bool isApple = isIOSPlatform(isIOSOverride: isIOS);

    shareMessage += 'Download Catch Watch App:\n';
    if (!isApple) {
      shareMessage += 'Android: $playStoreLink\n';
    }
    shareMessage += 'iOS: $appStoreLink';

    return shareMessage;
  }

  /// Resolves a guaranteed non-zero, valid [Rect] to anchor share popovers on iPadOS.
  ///
  /// Order of precedence:
  /// 1. An explicit, valid, non-zero [origin] passed by the caller.
  /// 2. The global bounds of the caller's [BuildContext] widget (if mounted and non-zero).
  /// 3. A centered anchor derived from [MediaQuery] (if available).
  /// 4. A centered anchor derived from the primary [FlutterView] physical dimensions.
  /// 5. A safe fallback rect centered on standard screen dimensions.
  static Rect resolveSharePositionOrigin({
    Rect? origin,
    BuildContext? context,
  }) {
    if (origin != null &&
        origin.isFinite &&
        origin.width > 0 &&
        origin.height > 0) {
      return origin;
    }

    if (context != null && context.mounted) {
      try {
        final RenderObject? renderObject = context.findRenderObject();
        if (renderObject is RenderBox &&
            renderObject.hasSize &&
            renderObject.size.width > 0 &&
            renderObject.size.height > 0) {
          final Offset globalOffset = renderObject.localToGlobal(Offset.zero);
          final Rect boxRect = globalOffset & renderObject.size;
          if (boxRect.isFinite && boxRect.width > 0 && boxRect.height > 0) {
            return boxRect;
          }
        }
      } catch (_) {}

      try {
        final MediaQueryData? mq = MediaQuery.maybeOf(context);
        if (mq != null && mq.size.width > 0 && mq.size.height > 0) {
          final double w = mq.size.width;
          final double h = mq.size.height;
          final double anchorWidth = w > 120 ? 120 : w;
          final double anchorHeight = h > 120 ? 120 : h;
          return Rect.fromCenter(
            center: Offset(w / 2, h / 2),
            width: anchorWidth,
            height: anchorHeight,
          );
        }
      } catch (_) {}
    }

    try {
      final FlutterView? view =
          WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
      if (view != null) {
        final Size physical = view.physicalSize;
        final double dpr = view.devicePixelRatio > 0 ? view.devicePixelRatio : 1.0;
        final double logicalWidth = physical.width / dpr;
        final double logicalHeight = physical.height / dpr;
        if (logicalWidth > 0 && logicalHeight > 0) {
          final double anchorWidth = logicalWidth > 120 ? 120 : logicalWidth;
          final double anchorHeight = logicalHeight > 120 ? 120 : logicalHeight;
          return Rect.fromCenter(
            center: Offset(logicalWidth / 2, logicalHeight / 2),
            width: anchorWidth,
            height: anchorHeight,
          );
        }
      }
    } catch (_) {}

    // Infallible non-zero fallback safe for any screen size
    return const Rect.fromLTWH(100, 100, 120, 120);
  }

  /// Shares text and optional preview image using the platform share sheet.
  ///
  /// Guarantees that:
  /// - `sharePositionOrigin` is non-zero so iPad `UIPopoverPresentationController`
  ///   never crashes.
  /// - On iOS, the Android Play Store URL is excluded to avoid Guideline 2.3.10 rejections.
  /// - On Android, the Google Play Store link is preserved.
  static Future<void> shareContent({
    required String title,
    required String text,
    String? imageUrl,
    String? contentId,
    String contentType = 'video',
    BuildContext? context,
    Rect? sharePositionOrigin,
    bool? isIOSOverride,
  }) async {
    final Rect origin = resolveSharePositionOrigin(
      origin: sharePositionOrigin,
      context: context,
    );

    final String shareMessage = buildShareMessage(
      text: text,
      contentId: contentId,
      contentType: contentType,
      isIOS: isIOSOverride,
    );

    try {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final Uri? parsedUri = Uri.tryParse(imageUrl);
        if (parsedUri != null && parsedUri.hasScheme) {
          final response = await http.get(parsedUri);
          if (response.statusCode == 200) {
            final temp = await getTemporaryDirectory();
            final path = '${temp.path}/shared_image.jpg';
            File(path).writeAsBytesSync(response.bodyBytes);

            await _sharePlus.share(
              ShareParams(
                files: [XFile(path)],
                text: shareMessage,
                subject: title,
                sharePositionOrigin: origin,
              ),
            );
            return;
          }
        }
      }

      // Fallback to text only if image fails or not provided
      await _sharePlus.share(
        ShareParams(
          text: shareMessage,
          subject: title,
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      debugPrint('Error sharing content: $e');
      // Final fallback
      try {
        await _sharePlus.share(
          ShareParams(
            text: text,
            subject: title,
            sharePositionOrigin: origin,
          ),
        );
      } catch (fallbackError) {
        debugPrint('Fallback share failed: $fallbackError');
      }
    }
  }

  /// Shares a local file using the platform share sheet with safe iPad popover anchoring.
  static Future<void> shareFile({
    required String path,
    String? text,
    String? subject,
    BuildContext? context,
    Rect? sharePositionOrigin,
  }) async {
    final Rect origin = resolveSharePositionOrigin(
      origin: sharePositionOrigin,
      context: context,
    );

    try {
      await _sharePlus.share(
        ShareParams(
          files: [XFile(path)],
          text: text,
          subject: subject,
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      debugPrint('Error sharing file: $e');
    }
  }
}
