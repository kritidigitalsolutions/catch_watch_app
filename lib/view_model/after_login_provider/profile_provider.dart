import 'dart:io';

import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/models/user_model.dart';
import 'package:catch_watch/models/watchlist_model.dart';
import 'package:catch_watch/repository/auth_repository.dart';
import 'package:catch_watch/repository/reels_repository.dart';
import 'package:catch_watch/repository/watchlist_repository.dart';
import 'package:catch_watch/repository/interaction_repository.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/utils/hive_service/userdetail.dart';
import 'package:catch_watch/view_model/after_login_provider/reels_provider.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

enum ProfileTab { videos, cuts, saved, liked }
enum TimeFilter { today, week, month, year }
enum DashboardMetric { reels, views, likes, comments, shares, saves, points }

class ProfileProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final ReelsRepository _reelsRepository = ReelsRepository();
  final WatchlistRepository _watchlistRepository = WatchlistRepository();

  ProfileTab _activeTab = ProfileTab.videos;

  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  String? _selectedImagePath;

  List<ReelModel> _myReels = [];
  List<ReelModel> _bookmarkedReels = [];
  List<WatchlistItem> _watchlist = [];
  List<ReelModel> _localDrafts = [];
  List<UserModel> _followersList = [];
  List<UserModel> _followingList = [];
  final Set<String> _followingIds = {};

  // Dashboard Stats (Dummy for now)
  int _totalViews = 12500;
  int _totalLikes = 4500;
  int _totalShares = 850;
  int _totalComments = 1200;
  int _totalSaves = 620;
  int _redeemedPoints = 0;
  
  // Growth percentages
  double _reelsGrowth = 5.2;
  double _viewsGrowth = 12.8;
  double _likesGrowth = -2.4;
  double _sharesGrowth = 15.0;
  double _commentsGrowth = 8.3;
  double _savesGrowth = 10.5;
  double _pointsGrowth = 11.2;

  TimeFilter _selectedTimeFilter = TimeFilter.week;
  DashboardMetric _selectedGraphMetric = DashboardMetric.views;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedImagePath => _selectedImagePath;
  List<ReelModel> get myReels => _myReels;
  List<ReelModel> get bookmarkedReels => _bookmarkedReels;
  List<WatchlistItem> get watchlist => _watchlist;
  List<ReelModel> get localDrafts => _localDrafts;
  List<UserModel> get followersList => _followersList;
  List<UserModel> get followingList => _followingList;

  // Getters for Dashboard
  int get totalViews => _totalViews;
  int get totalLikes => _totalLikes;
  int get totalShares => _totalShares;
  int get totalComments => _totalComments;
  int get totalSaves => _totalSaves;
  int get totalReels => _myReels.length;

  double get reelsGrowth => _reelsGrowth;
  double get viewsGrowth => _viewsGrowth;
  double get likesGrowth => _likesGrowth;
  double get sharesGrowth => _sharesGrowth;
  double get commentsGrowth => _commentsGrowth;
  double get savesGrowth => _savesGrowth;
  double get pointsGrowth => _pointsGrowth;

  TimeFilter get selectedTimeFilter => _selectedTimeFilter;
  DashboardMetric get selectedGraphMetric => _selectedGraphMetric;
  
  // Logic: Views*1 + Likes*2 + Comments*5 + Shares*10
  int get totalPoints => ((_totalViews * 1) + (_totalLikes * 2) + (_totalComments * 5) + (_totalShares * 10) + (_totalSaves * 3)) - _redeemedPoints;

  List<Map<String, dynamic>> _pointsHistory = [
    {'title': 'Points Earned from Reels', 'amount': '+4,550', 'date': 'Today', 'isCredit': true},
    {'title': 'Bonus for 10k Views', 'amount': '+10,000', 'date': 'Yesterday', 'isCredit': true},
    {'title': 'Points Redeemed', 'amount': '-2,500', 'date': '28 Jul', 'isCredit': false},
    {'title': 'Weekly Engagement Reward', 'amount': '+1,275', 'date': '25 Jul', 'isCredit': true},
  ];

  List<Map<String, dynamic>> get transactionHistory => _pointsHistory;

  void redeemPoints(int points) {
    if (points <= totalPoints && points > 0) {
      _redeemedPoints += points;
      _pointsHistory.insert(0, {
        'title': 'Points Redeemed',
        'amount': '-$points',
        'date': 'Just now',
        'isCredit': false,
      });
      notifyListeners();
    }
  }

  void setTimeFilter(TimeFilter filter) {
    _selectedTimeFilter = filter;
    // In a real app, we would fetch new data here
    notifyListeners();
  }

  void setGraphMetric(DashboardMetric metric) {
    _selectedGraphMetric = metric;
    notifyListeners();
  }

  List<double> getGraphData() {
    final Random random = Random();
    int count = 7;
    double baseValue = 50.0;

    switch (_selectedTimeFilter) {
      case TimeFilter.today:
        count = 12; // Every 2 hours
        break;
      case TimeFilter.week:
        count = 7; // Days
        break;
      case TimeFilter.month:
        count = 4; // Weeks
        break;
      case TimeFilter.year:
        count = 12; // Months
        break;
    }

    switch (_selectedGraphMetric) {
      case DashboardMetric.reels: baseValue = 10.0; break;
      case DashboardMetric.views: baseValue = 500.0; break;
      case DashboardMetric.likes: baseValue = 100.0; break;
      case DashboardMetric.comments: baseValue = 30.0; break;
      case DashboardMetric.shares: baseValue = 20.0; break;
      case DashboardMetric.saves: baseValue = 15.0; break;
      case DashboardMetric.points: baseValue = 1000.0; break;
    }

    return List.generate(count, (i) => baseValue + random.nextDouble() * (baseValue / 2));
  }

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

  Future<void> fetchProfile() async {
    _isLoading = true;
    _error = null;
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
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyReels() async {
    try {
      final response = await _reelsRepository.getMyReels();
      if (response['success'] == true) {
        _myReels = (response['reels'] as List)
            .map((e) => ReelModel.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching my reels: $e');
    }
    notifyListeners();
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
    try {
      final response = await InteractionRepository().getBookmarks();
      if (response['success'] == true) {
        _bookmarkedReels = (response['bookmarks'] as List)
            .where((e) => e['contentType'] == 'reel' && e['contentDetails'] != null)
            .map((e) => ReelModel.fromJson(e['contentDetails']))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching bookmarked reels: $e');
    }
    notifyListeners();
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
    await HiveService.logout();
    // Navigate to onboarding
    Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
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
    _activeTab = tab;
    notifyListeners();
    
    // Auto-refresh data when switching tabs
    if (tab == ProfileTab.videos) {
      fetchMyReels();
    } else if (tab == ProfileTab.saved) {
      fetchBookmarkedReels();
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
