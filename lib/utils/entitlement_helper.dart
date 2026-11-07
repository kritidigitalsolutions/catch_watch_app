import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:catch_watch/views/after_login_pages/movie_details_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/subsrciption_screen.dart';
import 'package:catch_watch/views/after_login_pages/short_video_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Centralized entitlement validation and content navigation for video content.
///
/// Every video entry point (movie/TV details, short films and reels) must
/// consult this helper instead of re-implementing the premium check, so a
/// paywall bypass cannot be introduced by adding a new screen.
class EntitlementHelper {
  EntitlementHelper._();

  /// Returns `true` when [content] is watchable by the current user.
  ///
  /// Free content (or content whose premium flag is not set) is always
  /// watchable. Premium content requires an active, non-expired subscription
  /// or a valid cancellation-period entitlement.
  static bool canWatch(BuildContext context, Content content) {
    if (content.isPremium != true) return true;

    final subProvider = context.read<SubscriptionProvider>();
    final subscription = subProvider.currentSubscription;
    if (subscription == null) return false;

    // Explicitly reject non-entitled statuses: inactive, pending, failed, created
    final status = (subscription.status ?? '').toLowerCase().trim();
    if (status == 'inactive' ||
        status == 'pending' ||
        status == 'failed' ||
        status == 'created') {
      return false;
    }

    return subscription.isCurrentlyValid(
      remainingDays: subProvider.remainingDays,
    );
  }

  /// Safely opens [content] (movie, TV show, or short film) with unified entitlement gating.
  ///
  /// - If content is free or already entitled, directly navigates to [MovieDetailScreen]
  ///   (or [ShortVideoPlayerScreen] for short films).
  /// - If content is locked (premium and user is not entitled), pushes [SubscriptionScreen].
  /// - Upon successful StoreKit purchase (modal returns `true`), refreshes subscription status
  ///   from the backend, confirms entitlement, and navigates to the target screen so the user
  ///   can immediately play the purchased content.
  /// - If the user exits the subscription flow without purchasing, returns `false` and does
  ///   not navigate to the locked content, preventing access bypasses.
  static Future<bool> openContent(
    BuildContext context,
    Content content, {
    Duration? resumePosition,
  }) async {
    final isShort = content.type == 'shortFilm' ||
        content.type == 'short' ||
        content.type == 'shortfilm';

    if (canWatch(context, content)) {
      if (!context.mounted) return false;
      _navigateToContent(
        context,
        content,
        isShort: isShort,
        resumePosition: resumePosition,
      );
      return true;
    }

    // Locked content: push SubscriptionScreen as its own route
    final subscribed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );

    if (!context.mounted) return false;

    if (subscribed == true) {
      // Refresh subscription status from backend to ensure latest entitlement is in memory
      await context.read<SubscriptionProvider>().fetchSubscriptionStatus();
      if (!context.mounted) return false;

      if (canWatch(context, content)) {
        _navigateToContent(
          context,
          content,
          isShort: isShort,
          resumePosition: resumePosition,
        );
        return true;
      }
    }

    return false;
  }

  static void _navigateToContent(
    BuildContext context,
    Content content, {
    required bool isShort,
    Duration? resumePosition,
  }) {
    if (isShort) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShortVideoPlayerScreen(
            isVisible: true,
            initialReels: [ReelModel.fromContent(content)],
            showBackButton: true,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailScreen(
            content: content,
            resumePosition: resumePosition,
          ),
        ),
      );
    }
  }
}
