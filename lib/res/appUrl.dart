class AppUrl {
  static const String serverUrl = 'http://192.168.1.18:5000';
  static const String baseUrl = '$serverUrl/api';

  // Auth Endpoints
  static const String sendOtp = '$baseUrl/auth/send-otp';
  static const String verifyOtp = '$baseUrl/auth/verify-otp';
  static const String completeProfile = '$baseUrl/user/complete-profile';
  static const String getProfile = '$baseUrl/user/profile';
  static const String updateProfile = '$baseUrl/user/update-profile';
  static const String getLegal = '$baseUrl/legal';
  static const String getHelp = '$baseUrl/help';
  static const String watchlist = '$baseUrl/watchlist';
  static const String addToWatchlist = '$baseUrl/watchlist';

  /// plans & subscriptions
  static const String getPlans = '$baseUrl/plan';
  static const String subscribe = '$baseUrl/subscription/subscribe';
  static const String cancelSubscription = '$baseUrl/subscription/cancel';
  static const String subscriptionStatus = '$baseUrl/subscription/status';
  static const String getContent = '$baseUrl/content';

  /// reels
  static const String uploadReel = '$baseUrl/reels/upload';
  static const String reelsFeed = '$baseUrl/reels/feed';
  static String reelById(String id) => '$baseUrl/reels/$id';
  static String deleteReel(String id) => '$baseUrl/reels/$id';
  static String viewReel(String id) => '$baseUrl/reels/$id/view';
  static String shareReel(String id) => '$baseUrl/reels/$id/share';
  static const String myReels = '$baseUrl/reels/my-reels';
  static const String searchReels = '$baseUrl/reels/search';
  // intrection
  static String toggleFollow(String userId) => '$baseUrl/interaction/toggle/follow/$userId';
  static String interactionStats(String contentId) => '$baseUrl/interaction/stats/$contentId';
  static String followStatus(String userId) => '$baseUrl/interaction/follow/$userId';
  static String toggleDislike(String contentId) => '$baseUrl/interaction/toggle/dislike/$contentId';
  static String toggleLike(String contentId) => '$baseUrl/interaction/toggle/like/$contentId';
  static String toggleBookmark(String contentId) => '$baseUrl/interaction/toggle/bookmark/$contentId';
  static const String getBookmarks = '$baseUrl/interaction/bookmarks';

  /// comments
  static String reelComments(String reelId) => '$baseUrl/comments/$reelId';
  static String deleteComment(String commentId) => '$baseUrl/comments/$commentId';
  // /// fcm
  // static const String updateFcmToken = '$baseUrl/notifications/fcm-token';
  //
  // /// support
  // static const String createTicket = '$baseUrl/support';
  // static const String getTickets = '$baseUrl/support';
  // static String replyTicket(String id) => '$baseUrl/support/reply/$id';
  // static String getConversation(String id) => '$baseUrl/support/conversation/$id';
  //
  /// notifications
  static const String getNotifications = '$baseUrl/notifications';
  static String markNotificationRead(String id) => '$baseUrl/notifications/$id/read';
  static const String markAllNotificationsRead = '$baseUrl/notifications/read-all';
  static String deleteNotification(String id) => '$baseUrl/notifications/$id';
  static const String deleteAllNotifications = '$baseUrl/notifications';
  //
  // /// legal
  // static const String privacyPolicyUrl = '$baseUrl/legal/privacy-policy';
  // static const String termsAndConditionsUrl = '$baseUrl/legal/terms-conditions';
  // static const String refundPolicy = '$baseUrl/legal/refund-policy';
  // static const String helpSupport = '$baseUrl/help';
  //
  // /// content
  // static const String getAllContent = '$baseUrl/content';
  // static String getEpisodes(String seriesId) => '$baseUrl/series/episodes/$seriesId';
  //
  // /// shorts
  // static const String getShortDramas = '$baseUrl/shortdramas';
  // static String getShortEpisodes(String dramaId) => '$baseUrl/drama-episodes/$dramaId';
  //
  /// payment
  static const String createOrder = '$baseUrl/payment/create-order';
  static const String verifyPayment = '$baseUrl/payment/verify';

  /// watchlist
  // static const String addWatchlist = '$baseUrl/watchlist';
  // static const String getWatchlist = '$baseUrl/watchlist';
  // static const String removeWatchlist = '$baseUrl/watchlist';
  // /// interaction
  // static const String toggleInteraction = '$baseUrl/interaction/toggle';
  // static const String interactionStats = '$baseUrl/interaction/stats';
  //
  // /// review
  // static const String rateApp = '$baseUrl/rating/rate';
  // /// plans
  // static const String planList = '$baseUrl/plan';
  // static const String buyPlan = '$baseUrl/subscription/subscribe';
  // static const String planCheck = '$baseUrl/subscription/status';
  // static const String cancelPlan = '$baseUrl/subscription/status';
  //
  // /// voucher
  // static const String redeemVoucher = '$baseUrl/voucher/redeem';
}
