import 'package:catch_watch/res/appUrl.dart';
import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';

class InteractionRepository {
  final BaseApiService _apiServices = NetworkApiService();

  Future<dynamic> toggleFollow(String userId) async {
    try {
      return await _apiServices.postApi(AppUrl.toggleFollow(userId), {});
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> followUser(String userId) async {
    try {
      return await _apiServices.postApi(AppUrl.followUser(userId), {});
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> unfollowUser(String userId) async {
    try {
      return await _apiServices.postApi(AppUrl.unfollowUser(userId), {});
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> getFollowStatus(String userId) async {
    try {
      return await _apiServices.getApi(AppUrl.getFollowStatus(userId));
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> toggleLike(String contentId) async {
    try {
      return await _apiServices.postApi(AppUrl.toggleLike(contentId), {});
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> toggleDislike(String contentId) async {
    try {
      return await _apiServices.postApi(AppUrl.toggleDislike(contentId), {});
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> toggleBookmark(String contentId) async {
    try {
      return await _apiServices.postApi(AppUrl.toggleBookmark(contentId), {});
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> getBookmarks() async {
    try {
      return await _apiServices.getApi(AppUrl.getBookmarks);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> getFollowers(String userId) async {
    try {
      return await _apiServices.getApi(AppUrl.getFollowers(userId));
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> getFollowing(String userId) async {
    try {
      return await _apiServices.getApi(AppUrl.getFollowing(userId));
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> getStats(String contentId) async {
    try {
      return await _apiServices.getApi(AppUrl.interactionStats(contentId));
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> getComments(String reelId, {int page = 1, int limit = 10}) async {
    try {
      return await _apiServices.getApi('${AppUrl.reelComments(reelId)}?page=$page&limit=$limit');
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> postComment(String reelId, String text) async {
    try {
      return await _apiServices.postApi(AppUrl.reelComments(reelId), {'text': text});
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> deleteComment(String commentId) async {
    try {
      return await _apiServices.deleteApi(AppUrl.deleteComment(commentId), null);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> pinComment(String commentId, bool isPinned) async {
    try {
      return await _apiServices.postApi(AppUrl.pinComment(commentId), {'isPinned': isPinned});
    } catch (e) {
      rethrow;
    }
  }
}
