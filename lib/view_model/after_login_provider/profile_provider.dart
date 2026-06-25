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
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedImagePath => _selectedImagePath;
  List<ReelModel> get myReels => _myReels;
  List<ReelModel> get bookmarkedReels => _bookmarkedReels;
  List<WatchlistItem> get watchlist => _watchlist;
  List<ReelModel> get localDrafts => _localDrafts;

  ProfileProvider() {
    _loadUserFromHive();
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
        _user = UserModel.fromJson(response['user']);
        
        // Update Hive with latest data
        final currentHiveUser = HiveService.getUser();
        if (currentHiveUser != null) {
          currentHiveUser.name = _user?.name;
          currentHiveUser.phone = _user?.phone;
          currentHiveUser.image = _user?.profileImage;
          await HiveService.saveUser(currentHiveUser);
        }

        // Fetch reels and watchlist too
        await fetchMyReels();
        await fetchWatchlist();
        await fetchBookmarkedReels();
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
  }
}
