import 'dart:async';
import 'package:catch_watch/data/network/socket_service.dart';
import 'package:catch_watch/models/block_model.dart';
import 'package:catch_watch/repository/block_repository.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:flutter/material.dart';

class BlockProvider extends ChangeNotifier {
  final BlockRepository _repository = BlockRepository();

  List<BlockedUser> _blockedUsers = [];
  bool _isLoadingBlockedUsers = false;
  String? _blockedUsersError;
  bool _hasFetchedBlockedUsers = false;

  final Map<String, bool> _blockingInProgress = {};
  final Map<String, bool> _blockedStatusCache = {};
  final Map<String, bool> _blockedByStatusCache = {};

  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  BlockProvider() {
    _initSocketListener();
  }

  List<BlockedUser> get blockedUsers => _blockedUsers;
  bool get isLoadingBlockedUsers => _isLoadingBlockedUsers;
  String? get blockedUsersError => _blockedUsersError;
  bool get hasFetchedBlockedUsers => _hasFetchedBlockedUsers;

  bool isOperationInProgress(String userId) => _blockingInProgress[userId] == true;

  bool isUserBlocked(String userId) {
    if (_blockedStatusCache.containsKey(userId)) {
      return _blockedStatusCache[userId] == true;
    }
    return _blockedUsers.any((u) => u.id == userId);
  }

  bool isUserBlockedBy(String userId) => _blockedByStatusCache[userId] == true;

  void setBlockStatus(String userId, {required bool isBlocked, bool? isBlockedBy}) {
    _blockedStatusCache[userId] = isBlocked;
    if (isBlockedBy != null) {
      _blockedByStatusCache[userId] = isBlockedBy;
    }
    notifyListeners();
  }

  /// Sets up real-time socket event listener for 'user_blocked'
  void _initSocketListener() {
    try {
      _socketSubscription = SocketService().messageStream.listen((eventData) {
        final event = eventData['event'];
        final data = eventData['data'];

        if (event == 'user_blocked' && data != null) {
          debugPrint('[BLOCK_PROVIDER] Real-time user_blocked event received: $data');
          String? targetUserId;
          if (data is Map) {
            targetUserId = data['userId']?.toString() ??
                data['blockedUserId']?.toString() ??
                data['targetId']?.toString() ??
                data['_id']?.toString() ??
                data['id']?.toString();
          } else if (data is String) {
            targetUserId = data;
          }

          if (targetUserId != null && targetUserId.isNotEmpty) {
            _blockedStatusCache[targetUserId] = true;
            notifyListeners();
          }
        }
      }, onError: (e) {
        debugPrint('[BLOCK_PROVIDER] Socket stream error: $e');
      });
    } catch (e) {
      debugPrint('[BLOCK_PROVIDER] Failed to bind socket listener: $e');
    }
  }

  /// Fetches the list of blocked users from GET /api/user/blocked-users
  Future<void> fetchBlockedUsers({bool forceRefresh = false}) async {
    if (_isLoadingBlockedUsers) return;
    if (!forceRefresh && _hasFetchedBlockedUsers && _blockedUsers.isNotEmpty) return;

    if (!HiveService.isLogin()) {
      _blockedUsersError = 'You must be logged in to view blocked users.';
      notifyListeners();
      return;
    }

    _isLoadingBlockedUsers = true;
    _blockedUsersError = null;
    notifyListeners();

    try {
      final response = await _repository.getBlockedUsers();
      if (response.success) {
        _blockedUsers = response.blockedUsers;
        for (var u in _blockedUsers) {
          _blockedStatusCache[u.id] = true;
        }
        _hasFetchedBlockedUsers = true;
        _blockedUsersError = null;
      } else {
        _blockedUsersError = response.message ?? 'Failed to load blocked users';
      }
    } catch (e) {
      _blockedUsersError = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoadingBlockedUsers = false;
      notifyListeners();
    }
  }

  /// Checks block status via GET /api/user/block-status/:userId
  Future<BlockStatusResponse?> checkBlockStatus(String userId) async {
    final trimmedId = userId.trim();
    if (trimmedId.isEmpty) return null;

    try {
      final response = await _repository.getBlockStatus(trimmedId);
      if (response.success) {
        _blockedStatusCache[trimmedId] = response.isBlocked;
        _blockedByStatusCache[trimmedId] = response.isBlockedBy;
        notifyListeners();
        return response;
      }
    } catch (e) {
      debugPrint('[BLOCK_PROVIDER] Error checking block status for $trimmedId: $e');
    }
    return null;
  }

  /// Blocks a user via POST /api/user/block/:userId
  Future<BlockResponse?> blockUser(
    String userId, {
    String? username,
    String? name,
    String? profileImage,
  }) async {
    final trimmedId = userId.trim();

    // 1. Authentication check
    if (!HiveService.isLogin()) {
      throw Exception('You must be logged in to block a user.');
    }

    // 2. Target validation
    if (trimmedId.isEmpty) {
      throw Exception('Target user identifier is missing.');
    }

    // 3. Self-block check
    final currentUserId = HiveService.userId;
    if (currentUserId != null && currentUserId == trimmedId) {
      throw Exception('You cannot block your own account.');
    }

    // 4. Duplicate request prevention
    if (isOperationInProgress(trimmedId)) {
      return null;
    }

    _blockingInProgress[trimmedId] = true;
    notifyListeners();

    try {
      final response = await _repository.blockUser(trimmedId);

      if (response.success) {
        _blockedStatusCache[trimmedId] = true;

        // Add to blocked users list if not already present
        final exists = _blockedUsers.any((u) => u.id == trimmedId);
        if (!exists) {
          _blockedUsers.insert(
            0,
            BlockedUser(
              id: trimmedId,
              name: name,
              username: username,
              profileImage: profileImage,
            ),
          );
        }

        notifyListeners();
        return response;
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      rethrow;
    } finally {
      _blockingInProgress[trimmedId] = false;
      notifyListeners();
    }
  }

  /// Unblocks a user via POST /api/user/unblock/:userId
  Future<BlockResponse?> unblockUser(String userId) async {
    final trimmedId = userId.trim();

    // 1. Authentication check
    if (!HiveService.isLogin()) {
      throw Exception('You must be logged in to unblock a user.');
    }

    // 2. Target validation
    if (trimmedId.isEmpty) {
      throw Exception('Target user identifier is missing.');
    }

    // 3. Self-unblock check
    final currentUserId = HiveService.userId;
    if (currentUserId != null && currentUserId == trimmedId) {
      throw Exception('You cannot unblock your own account.');
    }

    // 4. Duplicate request prevention
    if (isOperationInProgress(trimmedId)) {
      return null;
    }

    _blockingInProgress[trimmedId] = true;
    notifyListeners();

    try {
      final response = await _repository.unblockUser(trimmedId);

      if (response.success) {
        _blockedStatusCache[trimmedId] = false;

        // Remove from blocked users list only after successful response
        _blockedUsers.removeWhere((u) => u.id == trimmedId);

        notifyListeners();
        return response;
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      rethrow;
    } finally {
      _blockingInProgress[trimmedId] = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }
}
