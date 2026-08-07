class AppUrl {
  static const String serverUrl = 'http://192.168.1.44:5000';
  // static const String serverUrl = 'https://api.catchandwatch.com';
  // static const String serverUrl = 'https://catch-watch.vercel.app';
  static const String baseUrl = '$serverUrl/api';

  // Auth Endpoints
  static const String sendOtp = '$baseUrl/auth/send-otp';
  static const String verifyOtp = '$baseUrl/auth/verify-otp';
  static const String completeProfile = '$baseUrl/user/complete-profile';
  static const String getProfile = '$baseUrl/user/profile';
  static String getOtherProfileDetails(String username) => '$baseUrl/user/profile-details/$username';
  static String getOtherProfileStats(String userId) => '$baseUrl/user/profile-stats/$userId';
  static const String updateProfile = '$baseUrl/user/update-profile';
  static const String getLegal = '$baseUrl/legal';
  static const String getHelp = '$baseUrl/help';
  static const String watchlist = '$baseUrl/watchlist';
  static const String addToWatchlist = '$baseUrl/watchlist';

  /// plans & subscriptions
  static const String getPlans = '$baseUrl/plan';
  static const String getBluetickPlans = '$baseUrl/plan/bluetick';
  static const String subscribe = '$baseUrl/subscription/subscribe';
  static const String cancelSubscription = '$baseUrl/subscription/cancel';
  static const String subscriptionStatus = '$baseUrl/subscription/status';
  
  /// verification
  static const String applyVerification = '$baseUrl/verification/apply';
  static const String verificationStatus = '$baseUrl/verification/status';
  static const String cancelVerification = '$baseUrl/verification/cancel';
  static const String updateVerification = '$baseUrl/verification/update';
  static const String getContent = '$baseUrl/content';
  static const String getCategories = '$baseUrl/categories';
  static const String getMovies = '$baseUrl/movies';
  static const String getTvShows = '$baseUrl/tv-shows';
  static const String getShortFilms = '$baseUrl/short-films';
  static String getTvShowEpisodes(String tvShowId) => '$baseUrl/tv-shows-episodes/$tvShowId';

  /// reels
  static const String uploadReel = '$baseUrl/reels/upload';
  static const String reelsFeed = '$baseUrl/reels/feed';
  static String reelById(String id) => '$baseUrl/reels/$id';
  static String deleteReel(String id) => '$baseUrl/reels/$id';
  static String viewReel(String id) => '$baseUrl/reels/$id/view';
  static String shareReel(String id) => '$baseUrl/reels/$id/share';
  static String saveReel(String id) => '$baseUrl/reels/$id/save';
  static String unsaveReel(String id) => '$baseUrl/reels/$id/unsave';
  static String reelCommentCount(String id) => '$baseUrl/reels/$id/comment-count';
  static const String myReels = '$baseUrl/reels/my-reels';
  static String getUserReels(String userId) => '$baseUrl/reels/user/$userId';
  static const String searchReels = '$baseUrl/reels/search';
  // user profile and interaction
  static String searchUser(String query) => '$baseUrl/user/search?q=$query';
  static String toggleFollow(String userId) => '$baseUrl/user/toggle-follow/$userId';
  static String followUser(String userId) => '$baseUrl/user/follow/$userId';
  static String unfollowUser(String userId) => '$baseUrl/user/unfollow/$userId';
  static String getFollowStatus(String userId) => '$baseUrl/user/follow-status/$userId';
  static String getFollowers(String userId) => '$baseUrl/user/followers/$userId';
  static String getFollowing(String userId) => '$baseUrl/user/following/$userId';
  static String interactionStats(String contentId) => '$baseUrl/interaction/stats/$contentId';
  static String toggleDislike(String contentId) => '$baseUrl/interaction/toggle/dislike/$contentId';
  static String toggleLike(String contentId) => '$baseUrl/interaction/toggle/like/$contentId';
  static String toggleBookmark(String contentId) => '$baseUrl/interaction/toggle/bookmark/$contentId';
  static const String getBookmarks = '$baseUrl/interaction/bookmarks';

  /// comments
  static String reelComments(String reelId) => '$baseUrl/comments/$reelId';
  static String deleteComment(String commentId) => '$baseUrl/comments/$commentId';
  static String pinComment(String commentId) => '$baseUrl/comments/pin/$commentId';
  /// fcm
  static const String updateFcmToken = '$baseUrl/user/fcm-token';
  /// notifications
  static const String getNotifications = '$baseUrl/notifications';
  static String markNotificationRead(String id) => '$baseUrl/notifications/$id/read';
  static const String markAllNotificationsRead = '$baseUrl/notifications/read-all';
  static String deleteNotification(String id) => '$baseUrl/notifications/$id';
  static const String deleteAllNotifications = '$baseUrl/notifications';
  /// payment
  static const String createOrder = '$baseUrl/payment/create-order';
  static const String verifyPayment = '$baseUrl/payment/verify';

  /// ads
  static const String adEvent = '$baseUrl/ads/event';

  /// creator & wallet
  static const String creatorDashboard = '$baseUrl/creator/dashboard';
  static const String creatorLeaderboard = '$baseUrl/creator/leaderboard';
  static const String creatorWallet = '$baseUrl/creator/wallet';
  static const String creatorRedeem = '$baseUrl/creator/redeem';
  static const String creatorRedeemHistory = '$baseUrl/creator/redeem/history';
  static const String creatorPoints = '$baseUrl/creator/points';
  static const String creatorPointHistory = '$baseUrl/creator/point-history';

  /// vip support
  static const String vipAccessCheck = '$baseUrl/support/vip/access-check';
  static const String vipTickets = '$baseUrl/support/vip';
  static String vipTicketDetail(String ticketId) => '$baseUrl/support/vip/$ticketId';
  static String vipReplyTicket(String ticketId) => '$baseUrl/support/vip/reply/$ticketId';
}
