import 'package:catch_watch/data/network/api_network_service.dart';
import 'package:catch_watch/data/network/base_api_service.dart';
import 'package:catch_watch/models/block_model.dart';
import 'package:catch_watch/res/appUrl.dart';

class BlockRepository {
  final BaseApiService _apiService = NetworkApiService();

  /// Blocks a user via POST /api/user/block/:userId
  Future<BlockResponse> blockUser(String userId) async {
    final trimmedId = userId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }

    try {
      final dynamic response = await _apiService.postApi(
        AppUrl.blockUser(trimmedId),
        {},
      );

      if (response is Map<String, dynamic>) {
        return BlockResponse.fromJson(response);
      } else if (response is Map) {
        return BlockResponse.fromJson(Map<String, dynamic>.from(response));
      }
      return BlockResponse(
        success: true,
        message: 'User blocked successfully',
        isBlocked: true,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Unblocks a user via POST /api/user/unblock/:userId
  Future<BlockResponse> unblockUser(String userId) async {
    final trimmedId = userId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }

    try {
      final dynamic response = await _apiService.postApi(
        AppUrl.unblockUser(trimmedId),
        {},
      );

      if (response is Map<String, dynamic>) {
        return BlockResponse.fromJson(response);
      } else if (response is Map) {
        return BlockResponse.fromJson(Map<String, dynamic>.from(response));
      }
      return BlockResponse(
        success: true,
        message: 'User unblocked successfully',
        isBlocked: false,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Gets the list of blocked users via GET /api/user/blocked-users
  Future<BlockedUsersResponse> getBlockedUsers() async {
    try {
      final dynamic response = await _apiService.getApi(AppUrl.blockedUsers);
      if (response is Map<String, dynamic>) {
        return BlockedUsersResponse.fromJson(response);
      } else if (response is Map) {
        return BlockedUsersResponse.fromJson(Map<String, dynamic>.from(response));
      } else if (response is List) {
        return BlockedUsersResponse.fromJson({'success': true, 'blockedUsers': response});
      }
      return BlockedUsersResponse(
        success: false,
        count: 0,
        blockedUsers: [],
        message: 'Invalid response from server',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Checks the block status for a specific user via GET /api/user/block-status/:userId
  Future<BlockStatusResponse> getBlockStatus(String userId) async {
    final trimmedId = userId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }

    try {
      final dynamic response = await _apiService.getApi(AppUrl.blockStatus(trimmedId));
      if (response is Map<String, dynamic>) {
        return BlockStatusResponse.fromJson(response);
      } else if (response is Map) {
        return BlockStatusResponse.fromJson(Map<String, dynamic>.from(response));
      }
      return BlockStatusResponse(
        success: false,
        isBlocked: false,
        isBlockedBy: false,
        message: 'Invalid response from server',
      );
    } catch (e) {
      rethrow;
    }
  }
}
