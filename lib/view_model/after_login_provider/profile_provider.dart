import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/models/user_model.dart';
import 'package:catch_watch/models/watchlist_model.dart';
import 'package:catch_watch/repository/auth_repository.dart';
import 'package:catch_watch/repository/reels_repository.dart';
import 'package:catch_watch/repository/watchlist_repository.dart';
import 'package:catch_watch/repository/interaction_repository.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/data/network/socket_service.dart';
import 'package:catch_watch/data/exception/app_exception.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:catch_watch/view_model/before_login_provider/auth_providers.dart';
import 'package:catch_watch/view_model/after_login_provider/chat_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:catch_watch/data/network/notification_service.dart';
import 'package:catch_watch/services/iap_service.dart';

enum ProfileTab { videos, cuts, saved, liked }

class ProfileProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final ReelsRepository _reelsRepository = ReelsRepository();
  final WatchlistRepository _watchlistRepository = WatchlistRepository();

  ProfileTab _activeTab = ProfileTab.videos;

  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  String? _selectedImagePath;
  bool _isDeletingAccount = false;
  String? _deleteAccountError;

  List<ReelModel> _myReels = [];
  List<ReelModel> _bookmarkedReels = [];
  List<WatchlistItem> _watchlist = [];
  List<ReelModel> _localDrafts = [];
  List<UserModel> _followersList = [];
  List<UserModel> _followingList = [];
  final Set<String> _followingIds = {};

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedImagePath => _selectedImagePath;
  bool get isDeletingAccount => _isDeletingAccount;
  String? get deleteAccountError => _deleteAccountError;
  List<ReelModel> get myReels => _myReels;
  List<ReelModel> get bookmarkedReels => _bookmarkedReels;
  List<WatchlistItem> get watchlist => _watchlist;
  List<ReelModel> get localDrafts => _localDrafts;
  List<UserModel> get followersList => _followersList;
  List<UserModel> get followingList => _followingList;

  bool isUserFollowed(String userId) => _followingIds.contains(userId);

  ProfileProvider() {
    _loadUserFromHive();
    _loadStatsFromCache();
    // Fetch following list immediately if logged in to sync follow buttons globally
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (HiveService.isLogin()) {
        fetchFollowing();
      }
    });
  }

  void _loadStatsFromCache() {
    final userId = HiveService.userId;
    if (userId != null) {
      final stats = HiveService.getUserStats(userId);
      if (stats != null && _user != null) {
        _user!.followersCount = stats['followers'];
        _user!.followingCount = stats['following'];
        _user!.reelsCount = stats['reels'];
        notifyListeners();
      }
    }
  }

  void _loadUserFromHive() {
    final hiveUser = HiveService.getUser();
    if (hiveUser != null) {
      _user = UserModel(
        id: hiveUser.sId,
        name: hiveUser.name,
        phone: hiveUser.phone,
        profileImage: hiveUser.image,
      );
    }
  }

  bool _isFetchingProfile = false;
  bool get isFetchingProfile => _isFetchingProfile;
  bool _isFetchingMyReels = false;
  bool _isFetchingBookmarked = false;
  bool _hasFetchedMyReels = false;
  bool _hasFetchedBookmarks = false;

  Future<void> fetchProfile({bool forceRefresh = false}) async {
    if (_isFetchingProfile) {
      debugPrint('[PROFILE_PROVIDER_TRACE] fetchProfile SKIPPED: already in-flight');
      return;
    }
    _isFetchingProfile = true;
    _isLoading = true;
    _error = null;
    debugPrint('[PROFILE_PROVIDER_TRACE] fetchProfile START');
    notifyListeners();

    try {
      final response = await _authRepository.getProfile();
      if (response['success'] == true) {
        final newUser = UserModel.fromJson(response['user']);
        
        // Merge stats if missing in the 'user' object but present at response root
        newUser.followersCount = response['followersCount'] ?? response['followers'] ?? newUser.followersCount;
        newUser.followingCount = response['followingCount'] ?? response['following'] ?? newUser.followingCount;
        newUser.reelsCount = response['reelsCount'] ?? response['postsCount'] ?? response['totalReels'] ?? newUser.reelsCount;

        // Merge with EXISTING user object if we have one to prevent resetting to 0
        if (_user != null) {
          newUser.followersCount = newUser.followersCount ?? _user!.followersCount;
          newUser.followingCount = newUser.followingCount ?? _user!.followingCount;
          newUser.reelsCount = newUser.reelsCount ?? _user!.reelsCount;
          newUser.bio = newUser.bio ?? _user!.bio;
          newUser.genres = newUser.genres ?? _user!.genres;
        }

        _user = newUser;

        // Update Hive with latest data
        final currentHiveUser = HiveService.getUser();
        if (currentHiveUser != null) {
          currentHiveUser.name = _user?.name;
          currentHiveUser.phone = _user?.phone;
          currentHiveUser.image = _user?.profileImage;
          await HiveService.saveUser(currentHiveUser);
        }

        // Fetch following FIRST to populate _followingIds set correctly
        await fetchFollowing();

        // Fetch others
        await Future.wait([
          fetchMyReels(),
          fetchWatchlist(),
          fetchBookmarkedReels(),
          fetchFollowers(),
        ]);

        // Save to cache after fetching all
        if (_user?.id != null) {
          await HiveService.saveUserStats(
            _user!.id!,
            _user!.followersCount ?? 0,
            _user!.followingCount ?? 0,
            _user!.reelsCount ?? 0,
          );
        }
      } else {
        _error = response['message'] ?? 'Failed to fetch profile';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isFetchingProfile = false;
      _isLoading = false;
      notifyListeners();
      debugPrint('[PROFILE_PROVIDER_TRACE] fetchProfile END');
    }
  }

  Future<void> fetchMyReels() async {
    if (_isFetchingMyReels) {
      debugPrint('[PROFILE_PROVIDER_TRACE] fetchPosts SKIPPED: already in-flight');
      return;
    }
    _isFetchingMyReels = true;
    debugPrint('[PROFILE_PROVIDER_TRACE] fetchPosts START');
    try {
      final response = await _reelsRepository.getMyReels();
      if (response['success'] == true) {
        _myReels = (response['reels'] as List)
            .map((e) => ReelModel.fromJson(e))
            .toList();
        _hasFetchedMyReels = true;
      }
    } catch (e) {
      debugPrint('Error fetching my reels: $e');
    } finally {
      _isFetchingMyReels = false;
      notifyListeners();
      debugPrint('[PROFILE_PROVIDER_TRACE] fetchPosts END');
    }
  }

  Future<void> fetchWatchlist() async {
    try {
      final response = await _watchlistRepository.getWatchlist();
      if (response.success == true) {
        _watchlist = response.data ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching watchlist: $e');
    }
    notifyListeners();
  }

  Future<void> fetchBookmarkedReels() async {
    if (_isFetchingBookmarked) {
      debugPrint('[PROFILE_PROVIDER_TRACE] fetchSaved SKIPPED: already in-flight');
      return;
    }
    _isFetchingBookmarked = true;
    debugPrint('[PROFILE_PROVIDER_TRACE] fetchSaved START');
    try {
      final response = await InteractionRepository().getBookmarks();
      if (response['success'] == true) {
        _bookmarkedReels = (response['bookmarks'] as List)
            .where((e) => e['contentType'] == 'reel' && e['contentDetails'] != null)
            .map((e) => ReelModel.fromJson(e['contentDetails']))
            .toList();
        _hasFetchedBookmarks = true;
      }
    } catch (e) {
      debugPrint('Error fetching bookmarked reels: $e');
    } finally {
      _isFetchingBookmarked = false;
      notifyListeners();
      debugPrint('[PROFILE_PROVIDER_TRACE] fetchSaved END');
    }
  }

  Future<void> fetchFollowers({String? userId}) async {
    final targetId = userId ?? _user?.id;
    if (targetId == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await InteractionRepository().getFollowers(targetId);
      if (response['success'] == true) {
        _followersList = (response['followers'] as List)
            .map((e) {
              Map<String, dynamic> userData;
              if (e is Map<String, dynamic>) {
                if (e.containsKey('user') && e['user'] is Map) {
                  userData = Map<String, dynamic>.from(e['user']);
                } else if (e.containsKey('follower') && e['follower'] is Map) {
                  userData = Map<String, dynamic>.from(e['follower']);
                } else {
                  userData = e;
                }
              } else {
                return UserModel();
              }
              final u = UserModel.fromJson(userData);
              if (u.id != null) u.isFollowing = _followingIds.contains(u.id);
              return u;
            })
            .toList();
        
        // Sync count if it's the current user
        if (targetId == _user?.id) {
          _user?.followersCount = _followersList.length;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error fetching followers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFollowing({String? userId}) async {
    final targetId = userId ?? _user?.id;
    if (targetId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await InteractionRepository().getFollowing(targetId);
      if (response['success'] == true) {
        _followingList = (response['following'] as List)
            .map((e) {
              // Handle both direct user objects and follow objects containing user field
              Map<String, dynamic> userData;
              if (e is Map<String, dynamic>) {
                if (e.containsKey('user') && e['user'] is Map) {
                  userData = Map<String, dynamic>.from(e['user']);
                } else if (e.containsKey('following') && e['following'] is Map) {
                  userData = Map<String, dynamic>.from(e['following']);
                } else {
                  userData = e;
                }
              } else {
                return UserModel(); // Should not happen
              }
              
              final u = UserModel.fromJson(userData);
              if (u.id != null) u.isFollowing = _followingIds.contains(u.id);
              return u;
            })
            .toList();

        // Sync count and followingIds set if it's the current user
        if (targetId == _user?.id) {
          _user?.followingCount = _followingList.length;
          _followingIds.clear();
          for (var u in _followingList) {
            if (u.id != null) _followingIds.add(u.id!);
          }
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error fetching following: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFollow(String userId) async {
    final bool wasFollowing = _followingIds.contains(userId);
    
    // Update locally first
    if (wasFollowing) {
      _followingIds.remove(userId);
      _user?.followingCount = (_user?.followingCount ?? 1) - 1;
    } else {
      _followingIds.add(userId);
      _user?.followingCount = (_user?.followingCount ?? 0) + 1;
    }

    // Sync followers/following list properties (legacy support)
    for (var u in _followersList) {
      if (u.id == userId) u.isFollowing = !wasFollowing;
    }
    for (var u in _followingList) {
      if (u.id == userId) u.isFollowing = !wasFollowing;
    }
    notifyListeners();

    try {
      final response = await InteractionRepository().toggleFollow(userId);
      if (response['success'] == true) {
        // Optionally sync with exact count from server
        if (response['followingCount'] != null) {
          _user?.followingCount = response['followingCount'];
        }
        // fetchProfile(); // Too heavy to call every time, but good for total sync
      } else {
        // Rollback local update on failure
        if (wasFollowing) {
          _followingIds.add(userId);
          _user?.followingCount = (_user?.followingCount ?? 0) + 1;
        } else {
          _followingIds.remove(userId);
          _user?.followingCount = (_user?.followingCount ?? 1) - 1;
        }
        for (var u in _followersList) {
          if (u.id == userId) u.isFollowing = wasFollowing;
        }
        for (var u in _followingList) {
          if (u.id == userId) u.isFollowing = wasFollowing;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      // Rollback
      if (wasFollowing) {
        _followingIds.add(userId);
        _user?.followingCount = (_user?.followingCount ?? 0) + 1;
      } else {
        _followingIds.remove(userId);
        _user?.followingCount = (_user?.followingCount ?? 1) - 1;
      }
      for (var u in _followersList) {
        if (u.id == userId) u.isFollowing = wasFollowing;
      }
      for (var u in _followingList) {
        if (u.id == userId) u.isFollowing = wasFollowing;
      }
      notifyListeners();
    }
  }

  Future<void> logout(BuildContext context) async {
    // Reset AuthProvider and ChatProvider state
    if (context.mounted) {
      try {
        Provider.of<AuthProvider>(context, listen: false).resetAuthState(clearPhone: true);
      } catch (e) {
        debugPrint('Error resetting AuthProvider during logout: $e');
      }
      try {
        Provider.of<ChatProvider>(context, listen: false).clearSession();
      } catch (e) {
        debugPrint('Error clearing ChatProvider during logout: $e');
      }
    }
    await NotificationService.clearTokenOnLogout();
    await HiveService.logout();
    _resetUserData();
    SocketService().disconnect();
    // Navigate directly to login
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  /// Clears local user state in memory after logout or account deletion
  void _resetUserData() {
    _user = null;
    _selectedImagePath = null;
    _myReels = [];
    _bookmarkedReels = [];
    _watchlist = [];
    _localDrafts = [];
    _followersList = [];
    _followingList = [];
    _followingIds.clear();
    notifyListeners();
  }

  /// Deletes the current user's account permanently via `DELETE /api/user/delete-account`.
  ///
  /// Prevents concurrent calls with [_isDeletingAccount].
  /// Clears local session, token, in-memory state, and socket connection ONLY upon confirmed API success.
  /// Accepts optional [reason], [reasonDetails], and [context] parameters.
  ///
  /// Contract Compliance:
  /// The confirmed backend specification defines:
  /// - Method: DELETE /api/user/delete-account
  /// - Headers: `Authorization: Bearer <USER_ACCESS_TOKEN>`, Content-Type: application/json
  /// Because no request body is documented in the confirmed backend contract, the request
  /// is called without a body (data: null). If the backend team confirms request body support,
  /// the payload can be passed directly to `_authRepository.deleteAccount(data: payload)`.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> deleteAccount({String? reason, String? reasonDetails, BuildContext? context}) async {
    if (_isDeletingAccount) return false;

    // 1. Session verification: ensure user is authenticated
    final token = HiveService.getToken();
    if (token == null || token.isEmpty) {
      _deleteAccountError = 'You must be logged in to delete your account.';
      notifyListeners();
      return false;
    }

    _isDeletingAccount = true;
    _deleteAccountError = null;
    notifyListeners();

    try {
      // 2. Request body handling strictly based on confirmed backend contract
      // The confirmed contract does not document or accept a request body on DELETE.
      // Calling without a body (data: null) to avoid rejection by proxies/gateways.
      final response = await _authRepository.deleteAccount(data: null);

      // 3. Evaluate response
      bool isSuccess = true;
      String? errorMessage;

      if (response is Map) {
        if (response['success'] == false ||
            response['status'] == false ||
            response['status'] == 'error' ||
            response['status'] == 'fail') {
          isSuccess = false;
          errorMessage = response['message']?.toString() ?? response['error']?.toString();
        } else if (response['success'] == true ||
            response['status'] == true ||
            response['status'] == 'success') {
          isSuccess = true;
        } else if (response.containsKey('error') && response['error'] != null) {
          isSuccess = false;
          errorMessage = response['error'].toString();
        }
      }

      if (isSuccess) {
        // 4. Success handling: Permanently delete private keys, clear push tokens, auth tokens, session data, user state, IAP state, and sockets
        try {
          await NotificationService.clearTokenOnLogout();
        } catch (e) {
          debugPrint('Error clearing NotificationService token during deleteAccount: $e');
        }
        await HiveService.deleteAccountPermanent();
        _resetUserData();
        SocketService().disconnect();
        try {
          IapService.instance.dispose();
        } catch (e) {
          debugPrint('Error disposing IapService during deleteAccount: $e');
        }
        if (context != null && context.mounted) {
          try {
            Provider.of<AuthProvider>(context, listen: false).resetAuthState(clearPhone: true);
          } catch (e) {
            debugPrint('Error resetting AuthProvider during deleteAccount: $e');
          }
          try {
            Provider.of<ChatProvider>(context, listen: false).clearSession();
          } catch (e) {
            debugPrint('Error clearing ChatProvider during deleteAccount: $e');
          }
          try {
            Provider.of<SubscriptionProvider>(context, listen: false).clearSubscriptionState();
          } catch (e) {
            debugPrint('Error clearing SubscriptionProvider during deleteAccount: $e');
          }
        }
        return true;
      } else {
        // 5. Failure handling: Retain session, do not navigate, store error
        _deleteAccountError = errorMessage ?? 'Unable to delete your account right now. Please try again.';
        return false;
      }
    } catch (e) {
      if (e is AppException) {
        _deleteAccountError = e.message;
      } else {
        _deleteAccountError = e.toString().replaceAll('Exception: ', '').trim();
      }
      if (_deleteAccountError == null ||
          _deleteAccountError!.isEmpty ||
          _deleteAccountError == 'Unknown error') {
        _deleteAccountError = 'Unable to delete your account right now. Please try again.';
      }
      return false;
    } finally {
      _isDeletingAccount = false;
      notifyListeners();
    }
  }

  Future<void> pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 50);
    if (image != null) {
      _selectedImagePath = image.path;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String username,
    required String bio,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      dio.FormData formData = dio.FormData.fromMap({
        'name': name,
        'username': username,
        'bio': bio,
        'genres': _user?.genres ?? [],
      });

      if (_selectedImagePath != null) {
        formData.files.add(MapEntry(
          'profileImage',
          await dio.MultipartFile.fromFile(_selectedImagePath!, filename: 'profile.jpg'),
        ));
      }

      final response = await _authRepository.updateProfile(formData);

      if (response['success'] == true) {
        _user = UserModel.fromJson(response['user']);
        _selectedImagePath = null; // Reset after success

        // Update Hive
        final currentHiveUser = HiveService.getUser();
        if (currentHiveUser != null) {
          currentHiveUser.name = _user?.name;
          currentHiveUser.image = _user?.profileImage;
          await HiveService.saveUser(currentHiveUser);
        }
        return true;
      } else {
        _error = response['message'] ?? 'Failed to update profile';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String get name => _user?.name ?? 'Guest User';
  String get handle => _user?.username ?? '@guest';
  String get avatarAsset => _user?.profileImage ?? 'assets/images/logo.jpg';
  String get videosCount => _myReels.length.toString();
  String get followers => _user?.followersCount?.toString() ?? '0';
  String get following => _user?.followingCount?.toString() ?? '0';

  ProfileTab get activeTab => _activeTab;

  List<dynamic> get currentTabItems {
    switch (_activeTab) {
      case ProfileTab.videos:
        return _myReels;
      // case ProfileTab.cuts:
      //   return []; // cuts ko empty rakho
      case ProfileTab.saved:
        return _bookmarkedReels; // saved show bookmark reels
      default:
        return [];
    }
  }

  Future<void> deleteReel(String reelId) async {
    try {
      final response = await _reelsRepository.deleteReel(reelId);
      if (response['success'] == true) {
        _myReels.removeWhere((r) => r.id == reelId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting reel: $e');
    }
  }

  void setTab(ProfileTab tab) {
    if (_activeTab == tab) return;
    _activeTab = tab;
    notifyListeners();
    
    // Auto-fetch data when switching tabs only if not yet fetched
    if (tab == ProfileTab.videos) {
      if (!_hasFetchedMyReels) {
        fetchMyReels();
      }
    } else if (tab == ProfileTab.saved) {
      if (!_hasFetchedBookmarks) {
        fetchBookmarkedReels();
      }
    }
  }

  void syncFollowStatus(String userId, bool isFollowing) {
    if (isFollowing) {
      if (!_followingIds.contains(userId)) {
        _followingIds.add(userId);
        _user?.followingCount = (_user?.followingCount ?? 0) + 1;
        notifyListeners();
      }
    } else {
      if (_followingIds.contains(userId)) {
        _followingIds.remove(userId);
        _user?.followingCount = (_user?.followingCount ?? 1) - 1;
        notifyListeners();
      }
    }
  }
}
