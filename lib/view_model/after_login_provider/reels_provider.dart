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
  List<ReelModel> _feedReels = [];
  List<ReelModel> _searchResults = [];
  bool _isSearching = false;
  bool _hasFetchedFeed = false;
  bool _isLoading = false;
  bool _isSearchLoading = false;
  String? _error;
  String? _searchError;

  List<ReelModel> get reels => _reels;
  List<ReelModel> get feedReels => _feedReels;
  List<ReelModel> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  bool get hasFetchedFeed => _hasFetchedFeed;
  bool get isLoading => _isLoading;
  bool get isSearchLoading => _isSearchLoading;
  String? get error => _error;
  String? get searchError => _searchError;

  void clearSearch() {
    _isSearching = false;
    _searchResults = [];
    _searchError = null;
    notifyListeners();
  }

  void reset() {
    _reels = [];
    _feedReels = [];
    _searchResults = [];
    _isSearching = false;
    _hasFetchedFeed = false;
    _isLoading = false;
    _isSearchLoading = false;
    _error = null;
    _searchError = null;
    _targetReelId = null;
    _likedIds.clear();
    _bookmarkedIds.clear();
    _followingIds.clear();
    _blockedUserIds.clear();
    _hasFetchedInitialInteractions = false;
    notifyListeners();
  }

  String? _targetReelId;
  void setTargetReelId(String? id) {
    _targetReelId = id;
    notifyListeners();
  }

  String? get targetReelId => _targetReelId;

  final Set<String> _likedIds = {};
  final Set<String> _bookmarkedIds = {};
  final Set<String> _followingIds = {};
  final Set<String> _blockedUserIds = {};
  bool _hasFetchedInitialInteractions = false;

  bool isUserFollowed(String userId) => _followingIds.contains(userId);
  bool isCreatorBlocked(String userId) => _blockedUserIds.contains(userId);

  void onUserBlocked(String userId) {
    _blockedUserIds.add(userId);
    _feedReels.removeWhere((r) => r.user?.id == userId);
    _reels.removeWhere((r) => r.user?.id == userId);
    _searchResults.removeWhere((r) => r.user?.id == userId);
    _followingIds.remove(userId);
    notifyListeners();
  }

  void onUserUnblocked(String userId) {
    _blockedUserIds.remove(userId);
    notifyListeners();
  }

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
    // 1. Guard against concurrent in-flight requests
    if (_isLoading) return;

    // 2. Return cached feed if already fetched, not empty, and not force-refreshing
    if (!forceRefresh && _hasFetchedFeed && _reels.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _error = null;
    if (forceRefresh && _feedReels.isEmpty) {
      _hasFetchedFeed = false;
    }
    notifyListeners();

    try {
      // Re-fetch interactions asynchronously without blocking the reels feed request
      if (forceRefresh || !_hasFetchedInitialInteractions) {
        _fetchInitialInteractions().catchError((e) {
          debugPrint('Error fetching initial interactions: $e');
        });
      }

      final response = await _reelsRepository.getReelsFeed();
      
      dynamic rawList;
      bool isSuccess = false;
      String? errorMessage;

      if (response is List) {
        rawList = response;
        isSuccess = true;
      } else if (response is Map) {
        final bool isExplicitFailure = response['success'] == false ||
            response['success']?.toString().toLowerCase() == 'false' ||
            response['status'] == 'error' ||
            response['status'] == 'fail' ||
            (response['status'] is int && response['status'] >= 400) ||
            (response['statusCode'] is int && response['statusCode'] >= 400);

        errorMessage = response['message']?.toString() ?? response['error']?.toString();

        if (!isExplicitFailure) {
          if (response['reels'] is List) {
            rawList = response['reels'];
            isSuccess = true;
          } else if (response['feed'] is List) {
            rawList = response['feed'];
            isSuccess = true;
          } else if (response['data'] is List) {
            rawList = response['data'];
            isSuccess = true;
          } else if (response['data'] is Map) {
            final dataMap = response['data'] as Map;
            if (dataMap['reels'] is List) {
              rawList = dataMap['reels'];
              isSuccess = true;
            } else if (dataMap['feed'] is List) {
              rawList = dataMap['feed'];
              isSuccess = true;
            }
          } else if (response['success'] == true ||
              response['success']?.toString().toLowerCase() == 'true' ||
              response['status'] == 'success' ||
              response['status'] == 200 ||
              response['statusCode'] == 200) {
            isSuccess = true;
          }
        }
      }

      if (isSuccess && rawList is List) {
        if (rawList.isEmpty) {
          // Genuinely empty feed
          _feedReels = [];
          _reels = [];
          _hasFetchedFeed = true;
          _error = null;
        } else {
          final List<ReelModel> fetchedReels = [];
          int invalidCount = 0;
          String? firstError;

          for (var item in rawList) {
            if (item is Map) {
              try {
                final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
                // Validate that the item has reel characteristics
                final bool hasId = itemMap['_id'] != null || itemMap['id'] != null;
                final bool hasMedia = (itemMap['videoUrl'] != null && itemMap['videoUrl'].toString().isNotEmpty) ||
                    (itemMap['mediaUrl'] != null && itemMap['mediaUrl'].toString().isNotEmpty) ||
                    (itemMap['video'] != null && itemMap['video'].toString().isNotEmpty) ||
                    (itemMap['url'] != null && itemMap['url'].toString().isNotEmpty);
                final bool isAd = itemMap['isAd'] == true || itemMap['isAd']?.toString().toLowerCase() == 'true';

                // Skip unrelated nested objects or empty maps
                if (!hasId && !hasMedia && !isAd) {
                  invalidCount++;
                  continue;
                }

                final reel = ReelModel.fromJson(itemMap);
                if (reel.user?.id != null && _blockedUserIds.contains(reel.user!.id)) {
                  continue;
                }
                fetchedReels.add(reel);
              } catch (e, stack) {
                invalidCount++;
                firstError ??= e.toString();
                debugPrint('Error parsing reel item: $e\n$stack');
              }
            } else {
              invalidCount++;
            }
          }

          if (fetchedReels.isEmpty) {
            // All items were invalid or failed to parse - report meaningful error
            _error = firstError != null
                ? 'Failed to parse reel data: $firstError'
                : 'Invalid reels data format received from server';
            // Do not mark _hasFetchedFeed as true, so it's treated as an error state rather than false empty state
          } else {
            // Sync with local sets
            _applyLocalInteractions(fetchedReels);

            // Also update local sets from fetched data
            for (var reel in fetchedReels) {
              if (reel.id != null) {
                if (reel.userInteraction == 'LIKE') {
                  _likedIds.add(reel.id!);
                  HiveService.toggleLikeLocal(reel.id!, true);
                }
                if (reel.isBookmarked == true) {
                  _bookmarkedIds.add(reel.id!);
                }
              }
            }

            _feedReels = fetchedReels;
            _reels = fetchedReels;
            _hasFetchedFeed = true;
            _error = null;
          }
        }
      } else if (!isSuccess && errorMessage != null) {
        _error = errorMessage;
      } else if (isSuccess && rawList == null) {
        _error = 'No reels data found in server response';
      } else {
        _error = errorMessage ?? 'Failed to fetch reels';
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
      if (response != null && (response['success'] == true || response['reel'] != null || response['data'] != null)) {
        final reelData = response['reel'] ?? response['data'];
        if (reelData is Map) {
          final targetReel = ReelModel.fromJson(Map<String, dynamic>.from(reelData));

          // Sync with local sets
          if (targetReel.id != null) {
            if (_likedIds.contains(targetReel.id)) targetReel.userInteraction = 'LIKE';
            if (_bookmarkedIds.contains(targetReel.id)) targetReel.isBookmarked = true;
          }

          _feedReels.insert(0, targetReel);
          _reels.insert(0, targetReel);
          _reels = List.from(_reels);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error fetching specific reel: $e');
    }
  }

  Future<void> searchReels(String query) async {
    _isSearchLoading = true;
    _searchError = null;
    _isSearching = true;
    notifyListeners();

    try {
      final response = await _reelsRepository.searchReels(query);
      
      dynamic rawList;
      bool isSuccess = false;
      String? errorMessage;

      if (response is List) {
        rawList = response;
        isSuccess = true;
      } else if (response is Map) {
        final bool isExplicitFailure = response['success'] == false ||
            response['success']?.toString().toLowerCase() == 'false' ||
            response['status'] == 'error' ||
            response['status'] == 'fail' ||
            (response['status'] is int && response['status'] >= 400) ||
            (response['statusCode'] is int && response['statusCode'] >= 400);

        errorMessage = response['message']?.toString() ?? response['error']?.toString();

        if (!isExplicitFailure) {
          if (response['reels'] is List) {
            rawList = response['reels'];
            isSuccess = true;
          } else if (response['data'] is List) {
            rawList = response['data'];
            isSuccess = true;
          } else if (response['data'] is Map && (response['data'] as Map)['reels'] is List) {
            rawList = (response['data'] as Map)['reels'];
            isSuccess = true;
          } else if (response['success'] == true ||
              response['success']?.toString().toLowerCase() == 'true' ||
              response['status'] == 'success' ||
              response['status'] == 200 ||
              response['statusCode'] == 200) {
            isSuccess = true;
          }
        }
      }

      if (isSuccess && rawList is List) {
        final List<ReelModel> fetchedReels = [];
        for (var item in rawList) {
          if (item is Map) {
            try {
              final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
              final bool hasId = itemMap['_id'] != null || itemMap['id'] != null;
              final bool hasMedia = (itemMap['videoUrl'] != null && itemMap['videoUrl'].toString().isNotEmpty) ||
                  (itemMap['mediaUrl'] != null && itemMap['mediaUrl'].toString().isNotEmpty) ||
                  (itemMap['video'] != null && itemMap['video'].toString().isNotEmpty) ||
                  (itemMap['url'] != null && itemMap['url'].toString().isNotEmpty);
              final bool isAd = itemMap['isAd'] == true || itemMap['isAd']?.toString().toLowerCase() == 'true';

              if (!hasId && !hasMedia && !isAd) continue;

              final reel = ReelModel.fromJson(itemMap);
              if (reel.user?.id != null && _blockedUserIds.contains(reel.user!.id)) {
                continue;
              }
              fetchedReels.add(reel);
            } catch (e) {
              debugPrint('Error parsing search reel: $e');
            }
          }
        }

        _applyLocalInteractions(fetchedReels);

        _searchResults = fetchedReels;
        _searchError = null;
      } else {
        _searchResults = [];
        _searchError = errorMessage ?? 'No reels found';
      }
    } catch (e) {
      _searchResults = [];
      _searchError = e.toString();
    } finally {
      _isSearchLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(String reelId, {ReelModel? reel}) async {
    // Find all unique instances of this reel in our provider and the one passed from UI
    final Set<ReelModel> targetReels = {};
    if (reel != null) targetReels.add(reel);
    
    final mainIndex = _reels.indexWhere((r) => r.id == reelId);
    if (mainIndex != -1) targetReels.add(_reels[mainIndex]);
    final searchIndex = _searchResults.indexWhere((r) => r.id == reelId);
    if (searchIndex != -1) targetReels.add(_searchResults[searchIndex]);

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
    final searchIndex = _searchResults.indexWhere((r) => r.id == reelId);
    if (searchIndex != -1) targetReels.add(_searchResults[searchIndex]);

    final bool currentlyBookmarked = _bookmarkedIds.contains(reelId);

    // Optimistic UI update
    if (currentlyBookmarked) {
      _bookmarkedIds.remove(reelId);
      for (var r in targetReels) r.isBookmarked = false;
    } else {
      _bookmarkedIds.add(reelId);
      for (var r in targetReels) r.isBookmarked = true;
    }

    _reels = List.from(_reels);
    notifyListeners();

    try {
      dynamic response;
      if (currentlyBookmarked) {
        response = await _reelsRepository.unsaveReel(reelId);
      } else {
        response = await _reelsRepository.saveReel(reelId);
      }
      
      if (response['success'] != true) {
        // Rollback
        if (currentlyBookmarked) {
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
      if (currentlyBookmarked) {
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
        // Collect all instances of this reel to update counts
        final Set<ReelModel> targetReels = {};
        if (reel != null) targetReels.add(reel);
        final index = _reels.indexWhere((r) => r.id == reelId);
        if (index != -1) targetReels.add(_reels[index]);
        final searchIndex = _searchResults.indexWhere((r) => r.id == reelId);
        if (searchIndex != -1) targetReels.add(_searchResults[searchIndex]);

        for (var r in targetReels) {
          r.commentsCount = (r.commentsCount ?? 0) + 1;
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

  Future<void> pinComment(String commentId, bool isPinned, String reelId) async {
    try {
      final response = await _interactionRepository.pinComment(commentId, isPinned);
      if (response['success'] == true) {
        // Update local comment list
        final index = _currentComments.indexWhere((c) => c['_id'] == commentId);
        if (index != -1) {
          // If we are pinning, unpin all others (as only one can be pinned usually)
          if (isPinned) {
            for (var c in _currentComments) {
              c['isPinned'] = false;
            }
          }
          _currentComments[index]['isPinned'] = isPinned;
          
          // Re-sort comments: Pinned first, then by date
          _currentComments.sort((a, b) {
            bool aPinned = a['isPinned'] ?? false;
            bool bPinned = b['isPinned'] ?? false;
            if (aPinned && !bPinned) return -1;
            if (!aPinned && bPinned) return 1;
            
            // Default sort by date (newest first)
            DateTime aTime = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
            DateTime bTime = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
            return bTime.compareTo(aTime);
          });
          
          _currentComments = List.from(_currentComments);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error pinning comment: $e');
    }
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

  Future<void> incrementShares(String reelId, {ReelModel? reel}) async {
    try {
      final response = await _reelsRepository.incrementShares(reelId);
      if (response['success'] == true) {
        final newShares = response['sharesCount'];
        
        final Set<ReelModel> targetReels = {};
        if (reel != null) targetReels.add(reel);
        final index = _reels.indexWhere((r) => r.id == reelId);
        if (index != -1) targetReels.add(_reels[index]);
        final searchIndex = _searchResults.indexWhere((r) => r.id == reelId);
        if (searchIndex != -1) targetReels.add(_searchResults[searchIndex]);

        for (var r in targetReels) {
          r.sharesCount = newShares ?? (r.sharesCount ?? 0) + 1;
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error incrementing shares: $e');
    }
  }

  Future<void> syncCommentCount(String reelId, {ReelModel? reel}) async {
    try {
      final response = await _reelsRepository.getCommentCount(reelId);
      if (response['success'] == true) {
        final count = response['commentCount'];
        
        final Set<ReelModel> targetReels = {};
        if (reel != null) targetReels.add(reel);
        final index = _reels.indexWhere((r) => r.id == reelId);
        if (index != -1) targetReels.add(_reels[index]);
        final searchIndex = _searchResults.indexWhere((r) => r.id == reelId);
        if (searchIndex != -1) targetReels.add(_searchResults[searchIndex]);

        for (var r in targetReels) {
          r.commentsCount = count;
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error syncing comment count: $e');
    }
  }
}
