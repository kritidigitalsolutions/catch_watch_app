import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/repository/reels_repository.dart';
import 'package:catch_watch/repository/interaction_repository.dart';
import 'package:flutter/material.dart';

class ReelsProvider extends ChangeNotifier {
  final ReelsRepository _reelsRepository = ReelsRepository();
  final InteractionRepository _interactionRepository = InteractionRepository();

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
  bool _hasFetchedInitialInteractions = false;

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
    }
  }

  Future<void> fetchReelsFeed({bool forceRefresh = false}) async {
    if (!forceRefresh && _reels.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch bookmarks once to ensure we have the state
      if (!_hasFetchedInitialInteractions) {
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
          if (reel.userInteraction == 'LIKE') _likedIds.add(reel.id!);
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
      final response = await _interactionRepository.getBookmarks();
      if (response['success'] == true) {
        final bookmarks = response['bookmarks'] as List;
        for (var b in bookmarks) {
          if (b['contentType'] == 'reel' && b['contentId'] != null) {
            _bookmarkedIds.add(b['contentId'].toString());
          }
        }
        _hasFetchedInitialInteractions = true;
      }
    } catch (e) {
      debugPrint('Error fetching initial bookmarks: $e');
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

  Future<void> toggleLike(String reelId) async {
    final index = _reels.indexWhere((r) => r.id == reelId);
    if (index == -1) return;

    final reel = _reels[index];
    final originalInteraction = reel.userInteraction;
    final originalLikes = reel.likesCount ?? 0;

    if (originalInteraction == 'LIKE') {
      _reels[index].userInteraction = null;
      _reels[index].likesCount = originalLikes - 1;
      _likedIds.remove(reelId);
    } else {
      _reels[index].userInteraction = 'LIKE';
      _reels[index].likesCount = originalLikes + 1;
      _likedIds.add(reelId);
    }

    _reels = List.from(_reels); // New list instance
    notifyListeners();

    try {
      final response = await _interactionRepository.toggleLike(reelId);
      if (response['success'] != true) {
        // Rollback on failure
        _reels[index].userInteraction = originalInteraction;
        _reels[index].likesCount = originalLikes;
        if (originalInteraction == 'LIKE') _likedIds.add(reelId); else _likedIds.remove(reelId);
        _reels = List.from(_reels);
        notifyListeners();
      }
    } catch (e) {
      // Rollback on error
      _reels[index].userInteraction = originalInteraction;
      _reels[index].likesCount = originalLikes;
      if (originalInteraction == 'LIKE') _likedIds.add(reelId); else _likedIds.remove(reelId);
      _reels = List.from(_reels);
      notifyListeners();
      debugPrint('Error toggling like: $e');
    }
  }

  Future<void> toggleBookmark(String reelId) async {
    final index = _reels.indexWhere((r) => r.id == reelId);
    if (index == -1) return;

    final originalBookmark = _reels[index].isBookmarked ?? false;

    // Optimistic UI update
    _reels[index].isBookmarked = !originalBookmark;
    if (_reels[index].isBookmarked!) _bookmarkedIds.add(reelId); else _bookmarkedIds.remove(reelId);

    _reels = List.from(_reels);
    notifyListeners();

    try {
      final response = await _interactionRepository.toggleBookmark(reelId);
      if (response['success'] != true) {
        _reels[index].isBookmarked = originalBookmark;
        if (originalBookmark) _bookmarkedIds.add(reelId); else _bookmarkedIds.remove(reelId);
        _reels = List.from(_reels);
        notifyListeners();
      }
    } catch (e) {
      _reels[index].isBookmarked = originalBookmark;
      if (originalBookmark) _bookmarkedIds.add(reelId); else _bookmarkedIds.remove(reelId);
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

  Future<bool> postComment(String reelId, String text) async {
    try {
      final response = await _interactionRepository.postComment(reelId, text);
      if (response['success'] == true) {
        // Update local count
        final index = _reels.indexWhere((r) => r.id == reelId);
        if (index != -1) {
          _reels[index].commentsCount = (_reels[index].commentsCount ?? 0) + 1;
          _reels = List.from(_reels);
        }
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
}
