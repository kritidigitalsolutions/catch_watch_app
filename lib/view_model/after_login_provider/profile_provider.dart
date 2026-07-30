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
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

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

  List<ReelModel> _myReels = [];
  List<ReelModel> _bookmarkedReels = [];
  List<WatchlistItem> _watchlist = [];
  List<ReelModel> _localDrafts = [];
  List<UserModel> _followersList = [];
  List<UserModel> _followingList = [];

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

  ProfileProvider() {
    _loadUserFromHive();
    _loadStatsFromCache();
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

        // Fetch reels, watchlist, and stats too
        await Future.wait([
          fetchMyReels(),
          fetchWatchlist(),
          fetchBookmarkedReels(),
          fetchFollowers(),
          fetchFollowing(),
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
            .map((e) => UserModel.fromJson(e))
            .toList();
        
        // Sync count if it's the current user
        if (targetId == _user?.id) {
          _user?.followersCount = _followersList.length;
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
            .map((e) => UserModel.fromJson(e))
            .toList();

        // Sync count if it's the current user
        if (targetId == _user?.id) {
          _user?.followingCount = _followingList.length;
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
    // Update locally first for followers/following list
    for (var u in _followersList) {
      if (u.id == userId) u.isFollowing = !(u.isFollowing ?? false);
    }
    for (var u in _followingList) {
      if (u.id == userId) u.isFollowing = !(u.isFollowing ?? false);
    }
    notifyListeners();

    try {
      final response = await InteractionRepository().toggleFollow(userId);
      if (response['success'] == true) {
        // Sync state from response if available
        if (response['followersCount'] != null) {
          // If we're toggling someone ELSE, but the response gives counts for US,
          // we need to be careful. Usually these APIs return counts for the target user.
          // But if it's "followersCount" in a global toggle, it might be for the current user.
          // Let's refresh profile just to be safe as previously implemented, 
          // but also update current counts if returned.
        }
        fetchProfile();
      } else {
        // Rollback local update on failure
        for (var u in _followersList) {
          if (u.id == userId) u.isFollowing = !(u.isFollowing ?? false);
        }
        for (var u in _followingList) {
          if (u.id == userId) u.isFollowing = !(u.isFollowing ?? false);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      // Rollback
      for (var u in _followersList) {
        if (u.id == userId) u.isFollowing = !(u.isFollowing ?? false);
      }
      for (var u in _followingList) {
        if (u.id == userId) u.isFollowing = !(u.isFollowing ?? false);
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
}
