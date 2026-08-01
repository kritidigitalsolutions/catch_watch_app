import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/repository/reels_repository.dart';
import 'package:catch_watch/repository/interaction_repository.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:flutter/material.dart';

class ReelsProvider extends ChangeNotifier {
  final ReelsRepository _reelsRepository = ReelsRepository();
  final InteractionRepository _interactionRepository = InteractionRepository();

  ReelsProvider() {
    _fetchInitialInteractions();
  }

  List<ReelModel> _reels = [];
  bool _isLoading = false;
  String? _error;

  List<ReelModel> get reels => _reels;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String? _targetReelId;
  void setTargetReelId(String? id) {
    _targetReelId = id;
    notifyListeners();
  }

  String? get targetReelId => _targetReelId;

  final Set<String> _likedIds = {};
  final Set<String> _bookmarkedIds = {};
  final Set<String> _followingIds = {};
  bool _hasFetchedInitialInteractions = false;

  bool isUserFollowed(String userId) => _followingIds.contains(userId);

  Future<void> applyInteractionsTo(List<ReelModel> reelList) async {
    if (!_hasFetchedInitialInteractions) {
      await _fetchInitialInteractions();
    }
    _applyLocalInteractions(reelList);
    notifyListeners();
  }

  void _applyLocalInteractions(List<ReelModel> reelList) {
    for (var reel in reelList) {
      if (reel.id != null) {
        if (_likedIds.contains(reel.id)) {
          reel.userInteraction = 'LIKE';
        }
        if (_bookmarkedIds.contains(reel.id)) {
          reel.isBookmarked = true;
        }
      }
      if (reel.user?.id != null) {
        if (_followingIds.contains(reel.user!.id)) {
          reel.user!.isFollowing = true;
        } else if (reel.user!.isFollowing == true) {
          // If the reel data already says we are following, trust it and update local set
          _followingIds.add(reel.user!.id!);
        } else {
          reel.user!.isFollowing = false;
        }
      }
    }
  }

  Future<void> fetchReelsFeed({bool forceRefresh = false}) async {
    if (!forceRefresh && _reels.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Re-fetch interactions on force refresh to sync following state
      if (forceRefresh || !_hasFetchedInitialInteractions) {
        await _fetchInitialInteractions();
      }

      final response = await _reelsRepository.getReelsFeed();
      if (response['success'] == true) {
        final List<ReelModel> fetchedReels = (response['reels'] as List)
            .map((e) => ReelModel.fromJson(e))
            .toList();

        // Sync with local sets
        _applyLocalInteractions(fetchedReels);

        // Also update local sets from fetched data
        for (var reel in fetchedReels) {
          if (reel.userInteraction == 'LIKE') {
            _likedIds.add(reel.id!);
            HiveService.toggleLikeLocal(reel.id!, true);
          }
          if (reel.isBookmarked == true) _bookmarkedIds.add(reel.id!);
        }

        _reels = fetchedReels;
      } else {
        _error = 'Failed to fetch reels';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchInitialInteractions() async {
    try {
      // Load local likes from Hive
      final localLikes = HiveService.getLikedIds();
      _likedIds.addAll(localLikes);

      // Fetch Bookmarks
      final bookmarkResponse = await _interactionRepository.getBookmarks();
      if (bookmarkResponse['success'] == true) {
        _bookmarkedIds.clear();
        final bookmarks = bookmarkResponse['bookmarks'] as List;
        for (var b in bookmarks) {
          if (b['contentType'] == 'reel' && b['contentId'] != null) {
            _bookmarkedIds.add(b['contentId'].toString());
          }
        }
      }

      // Fetch Following for current user to sync follow buttons
      final currentUser = HiveService.getUser();
      if (currentUser?.sId != null) {
        final followingResponse = await _interactionRepository.getFollowing(currentUser!.sId!);
        if (followingResponse['success'] == true) {
          _followingIds.clear();
          final following = followingResponse['following'] as List;
          for (var f in following) {
            if (f == null) continue;
            
            // Handle plain string IDs or user objects
            String? fId;
            if (f is String) {
              fId = f;
            } else if (f is Map) {
              fId = f['_id'] ?? f['id'] ?? f['user']?['_id'] ?? f['user']?['id'] ?? f['following']?['_id'] ?? f['following']?['id'];
            }
            
            if (fId != null) _followingIds.add(fId.toString());
          }
        }
      }

      _hasFetchedInitialInteractions = true;
    } catch (e) {
      debugPrint('Error fetching initial interactions: $e');
    }
  }

  Future<void> ensureReelVisible(String reelId) async {
    final index = _reels.indexWhere((r) => r.id == reelId);
    if (index != -1) return; // Already there

    // Not in current list, fetch it and insert at top
    try {
      final response = await _reelsRepository.getReelById(reelId);
      if (response['success'] == true) {
        final targetReel = ReelModel.fromJson(response['reel']);

        // Sync with local sets
        if (_likedIds.contains(targetReel.id)) targetReel.userInteraction = 'LIKE';
        if (_bookmarkedIds.contains(targetReel.id)) targetReel.isBookmarked = true;

        _reels.insert(0, targetReel);
        _reels = List.from(_reels);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching specific reel: $e');
    }
  }

  Future<void> searchReels(String query) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _reelsRepository.searchReels(query);
      if (response['success'] == true) {
        final List<ReelModel> fetchedReels = (response['reels'] as List)
            .map((e) => ReelModel.fromJson(e))
            .toList();

        _applyLocalInteractions(fetchedReels);

        _reels = fetchedReels;
      } else {
        _error = 'No reels found';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(String reelId, {ReelModel? reel}) async {
    // Find all unique instances of this reel in our provider and the one passed from UI
    final Set<ReelModel> targetReels = {};
    if (reel != null) targetReels.add(reel);
    
    final mainIndex = _reels.indexWhere((r) => r.id == reelId);
    if (mainIndex != -1) targetReels.add(_reels[mainIndex]);

    final bool wasLiked = _likedIds.contains(reelId);
    
    // Optimistic Update
    if (wasLiked) {
      _likedIds.remove(reelId);
      await HiveService.toggleLikeLocal(reelId, false);
      for (var r in targetReels) {
        r.userInteraction = null;
        r.likesCount = (r.likesCount ?? 1) - 1;
      }
    } else {
      _likedIds.add(reelId);
      await HiveService.toggleLikeLocal(reelId, true);
      for (var r in targetReels) {
        r.userInteraction = 'LIKE';
        r.likesCount = (r.likesCount ?? 0) + 1;
      }
    }

    _reels = List.from(_reels);
    notifyListeners();

    try {
      final response = await _interactionRepository.toggleLike(reelId);
      if (response['success'] != true) {
        // Rollback on failure
        if (wasLiked) {
          _likedIds.add(reelId);
          await HiveService.toggleLikeLocal(reelId, true);
          for (var r in targetReels) {
            r.userInteraction = 'LIKE';
            r.likesCount = (r.likesCount ?? 0) + 1;
          }
        } else {
          _likedIds.remove(reelId);
          await HiveService.toggleLikeLocal(reelId, false);
          for (var r in targetReels) {
            r.userInteraction = null;
            r.likesCount = (r.likesCount ?? 1) - 1;
          }
        }
        _reels = List.from(_reels);
        notifyListeners();
      }
    } catch (e) {
      // Rollback on error
      if (wasLiked) {
        _likedIds.add(reelId);
        await HiveService.toggleLikeLocal(reelId, true);
        for (var r in targetReels) {
          r.userInteraction = 'LIKE';
          r.likesCount = (r.likesCount ?? 0) + 1;
        }
      } else {
        _likedIds.remove(reelId);
        await HiveService.toggleLikeLocal(reelId, false);
        for (var r in targetReels) {
          r.userInteraction = null;
          r.likesCount = (r.likesCount ?? 1) - 1;
        }
      }
      _reels = List.from(_reels);
      notifyListeners();
      debugPrint('Error toggling like: $e');
    }
  }

  Future<void> toggleBookmark(String reelId, {ReelModel? reel}) async {
    final Set<ReelModel> targetReels = {};
    if (reel != null) targetReels.add(reel);
    
    final mainIndex = _reels.indexWhere((r) => r.id == reelId);
    if (mainIndex != -1) targetReels.add(_reels[mainIndex]);

    final bool wasBookmarked = _bookmarkedIds.contains(reelId);

    // Optimistic UI update
    if (wasBookmarked) {
      _bookmarkedIds.remove(reelId);
      for (var r in targetReels) r.isBookmarked = false;
    } else {
      _bookmarkedIds.add(reelId);
      for (var r in targetReels) r.isBookmarked = true;
    }

    _reels = List.from(_reels);
    notifyListeners();

    try {
      final response = await _interactionRepository.toggleBookmark(reelId);
      if (response['success'] != true) {
        // Rollback
        if (wasBookmarked) {
          _bookmarkedIds.add(reelId);
          for (var r in targetReels) r.isBookmarked = true;
        } else {
          _bookmarkedIds.remove(reelId);
          for (var r in targetReels) r.isBookmarked = false;
        }
        _reels = List.from(_reels);
        notifyListeners();
      }
    } catch (e) {
      // Rollback
      if (wasBookmarked) {
        _bookmarkedIds.add(reelId);
        for (var r in targetReels) r.isBookmarked = true;
      } else {
        _bookmarkedIds.remove(reelId);
        for (var r in targetReels) r.isBookmarked = false;
      }
      _reels = List.from(_reels);
      notifyListeners();
      debugPrint('Error toggling bookmark: $e');
    }
  }

  // --- Comments logic ---
  List<dynamic> _currentComments = [];
  bool _isCommentsLoading = false;
  List<dynamic> get currentComments => _currentComments;
  bool get isCommentsLoading => _isCommentsLoading;

  Future<void> fetchComments(String reelId) async {
    _isCommentsLoading = true;
    _currentComments = [];
    notifyListeners();
    try {
      final response = await _interactionRepository.getComments(reelId);
      if (response['success'] == true) {
        _currentComments = response['comments'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    } finally {
      _isCommentsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> postComment(String reelId, String text, {ReelModel? reel}) async {
    try {
      final response = await _interactionRepository.postComment(reelId, text);
      if (response['success'] == true) {
        // Update local counts
        if (reel != null) {
          reel.commentsCount = (reel.commentsCount ?? 0) + 1;
        }
        final index = _reels.indexWhere((r) => r.id == reelId);
        if (index != -1) {
          _reels[index].commentsCount = (_reels[index].commentsCount ?? 0) + 1;
        }
        _reels = List.from(_reels);

        // Add to list if current
        _currentComments.insert(0, response['comment']);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error posting comment: $e');
    }
    return false;
  }

  Future<void> toggleFollow(String userId, {ReelModel? reel}) async {
    final bool wasFollowing = _followingIds.contains(userId);

    _updateLocalFollowState(userId, !wasFollowing, reel: reel);

    try {
      final response = await _interactionRepository.toggleFollow(userId);
      if (response['success'] == true) {
        final bool actualFollowing = response['isFollowing'] ?? !wasFollowing;
        _updateLocalFollowState(userId, actualFollowing, reel: reel);
      } else {
        _rollbackFollow(userId, wasFollowing, reel);
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      _rollbackFollow(userId, wasFollowing, reel);
    }
  }

  void _updateLocalFollowState(String userId, bool isFollowing, {ReelModel? reel}) {
    if (isFollowing) {
      _followingIds.add(userId);
    } else {
      _followingIds.remove(userId);
    }

    // Apply to all reels by this user in the current list
    for (var r in _reels) {
      if (r.user?.id == userId) {
        r.user?.isFollowing = isFollowing;
      }
    }
    // Also update the specific reel instance passed from UI
    if (reel?.user?.id == userId) {
      reel!.user!.isFollowing = isFollowing;
    }
    notifyListeners();
  }

  void updateFollowStatus(String userId, bool isFollowing) {
    _updateLocalFollowState(userId, isFollowing);
  }

  void _rollbackFollow(String userId, bool wasFollowing, ReelModel? reel) {
    _updateLocalFollowState(userId, wasFollowing, reel: reel);
  }

  Future<void> recordReelView(String reelId, int duration) async {
    try {
      final response = await _reelsRepository.recordReelView(reelId, duration);
      if (response['success'] == true && response['viewsCount'] != null) {
        // Update local views count for this reel
        final index = _reels.indexWhere((r) => r.id == reelId);
        if (index != -1) {
          _reels[index].viewsCount = response['viewsCount'];
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error recording reel view: $e');
    }
  }

  Future<void> recordAdEvent({
    required String adId,
    required String campaignId,
    required String eventType,
    int? watchDuration,
  }) async {
    try {
      await _reelsRepository.recordAdEvent(
        adId: adId,
        campaignId: campaignId,
        eventType: eventType,
        watchDuration: watchDuration,
      );
    } catch (e) {
      debugPrint('Error recording ad event ($eventType): $e');
    }
  }
}
