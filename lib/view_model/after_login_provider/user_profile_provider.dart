import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/models/user_model.dart';
import 'package:catch_watch/repository/auth_repository.dart';
import 'package:catch_watch/repository/reels_repository.dart';
import 'package:catch_watch/repository/interaction_repository.dart';
import 'package:catch_watch/res/appUrl.dart';
import 'package:catch_watch/data/network/api_network_service.dart';
import 'package:catch_watch/data/network/base_api_service.dart';
import 'package:flutter/material.dart';

class UserProfileProvider extends ChangeNotifier {
  final BaseApiService _apiService = NetworkApiService();
  final InteractionRepository _interactionRepository = InteractionRepository();

  UserModel? _user;
  List<ReelModel> _userReels = [];
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  List<ReelModel> get userReels => _userReels;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchUserProfile(String username) async {
    // Reset state if we are fetching a different user or if user is null
    if (_user == null || _user!.username != username) {
      _user = null;
      _userReels = [];
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Fetch profile details by username
      final profileUrl = AppUrl.getOtherProfileDetails(username);
      debugPrint('--- Fetching Profile Details ---');
      debugPrint('URL: $profileUrl');
      
      final profileResponse = await _apiService.getApi(profileUrl);
      debugPrint('Profile Details Response: $profileResponse');

      if (profileResponse['success'] == true) {
        final newUser = UserModel.fromJson(profileResponse['user']);
        // Merge stats from the root of the response if available
        newUser.followersCount = profileResponse['followersCount'] ?? profileResponse['followers'] ?? newUser.followersCount;
        newUser.followingCount = profileResponse['followingCount'] ?? profileResponse['following'] ?? newUser.followingCount;
        newUser.reelsCount = profileResponse['postsCount'] ?? profileResponse['reelsCount'] ?? profileResponse['totalReels'] ?? newUser.reelsCount;
        
        // Use isFollowing from response, or keep existing if same user
        if (profileResponse['isFollowing'] != null) {
          newUser.isFollowing = profileResponse['isFollowing'];
        } else if (_user != null && _user!.id == newUser.id) {
          newUser.isFollowing = _user!.isFollowing;
        }

        _user = newUser;
      } else {
        throw Exception(profileResponse['message'] ?? 'Failed to fetch user profile');
      }

      // 2. Fetch stats by userId if we have it
      if (_user?.id != null) {
        try {
          // Also fetch follow status explicitly if it was null
          if (_user!.isFollowing == null) {
            final followStatusUrl = AppUrl.getFollowStatus(_user!.id!);
            final followResponse = await _apiService.getApi(followStatusUrl);
            if (followResponse['success'] == true) {
              _user!.isFollowing = followResponse['isFollowing'] ?? false;
            }
          }

          final statsUrl = AppUrl.getOtherProfileStats(_user!.id!);
          debugPrint('--- Fetching Profile Stats ---');
          debugPrint('URL: $statsUrl');
          
          final statsResponse = await _apiService.getApi(statsUrl);
          debugPrint('Profile Stats Response: $statsResponse');

          if (statsResponse['success'] == true) {
            _user!.followersCount = statsResponse['followersCount'] ?? statsResponse['followers'];
            _user!.followingCount = statsResponse['followingCount'] ?? statsResponse['following'];
            _user!.reelsCount = statsResponse['postsCount'] ?? statsResponse['totalReels'];
          }
        } catch (e) {
          debugPrint('Profile Stats API failed: $e');
          // Don't fail the whole process if only stats fail
        }
      }

      // 3. Fetch reels by userId if we have it
      if (_user?.id != null) {
        try {
          final reelsUrl = AppUrl.getUserReels(_user!.id!);
          debugPrint('--- Fetching User Reels ---');
          debugPrint('URL: $reelsUrl');

          final reelsResponse = await _apiService.getApi(reelsUrl);
          debugPrint('User Reels Response: $reelsResponse');

          if (reelsResponse['success'] == true) {
            _userReels = (reelsResponse['reels'] as List)
                .map((e) => ReelModel.fromJson(e))
                .toList();
          }
        } catch (e) {
          debugPrint('User Reels API failed: $e');
        }
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      debugPrint('General error in fetchUserProfile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFollow(String userId, {VoidCallback? onSuccess}) async {
    final bool wasFollowing = _user?.isFollowing ?? false;
    
    // Optimistic update
    _updateLocalFollow(wasFollowing ? false : true);

    try {
      final response = await _interactionRepository.toggleFollow(userId);
      if (response['success'] == true) {
        final bool actualFollowing = response['isFollowing'] ?? !wasFollowing;
        _updateLocalFollow(actualFollowing);
        if (onSuccess != null) onSuccess();
      } else {
        _updateLocalFollow(wasFollowing);
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      _updateLocalFollow(wasFollowing);
    }
  }

  void _updateLocalFollow(bool isFollowing) {
    if (_user != null) {
      final bool currentlyFollowing = _user!.isFollowing ?? false;
      if (currentlyFollowing == isFollowing) return;

      _user!.isFollowing = isFollowing;
      if (isFollowing) {
        _user!.followersCount = (_user!.followersCount ?? 0) + 1;
      } else {
        _user!.followersCount = (_user!.followersCount ?? 1) - 1;
      }
      notifyListeners();
    }
  }

  void syncFollowStatus(bool isFollowing) {
    if (_user != null && _user!.isFollowing != isFollowing) {
      _user!.isFollowing = isFollowing;
      notifyListeners();
    }
  }
}
