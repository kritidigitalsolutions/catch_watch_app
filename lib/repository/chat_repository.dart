import 'package:catch_watch/data/network/api_network_service.dart';
import 'package:catch_watch/data/network/base_api_service.dart';
import 'package:catch_watch/models/chat_model.dart';
import 'package:catch_watch/res/appUrl.dart';
import 'package:dio/dio.dart' as dio;

class ChatRepository {
  final NetworkApiService _apiService = NetworkApiService();

  Future<List<ConversationModel>> fetchConversations() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getConversations);
      return (response['data'] as List)
          .map((e) => ConversationModel.fromJson(e))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> createConversation(String recipientId) async {
    try {
      dynamic response = await _apiService.postApi(
        AppUrl.createConversation,
        {'recipientId': recipientId},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> markAsRead(String conversationId) async {
    try {
      dynamic response = await _apiService.postApi(
        AppUrl.markMessageRead(conversationId),
        {},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> togglePin(String conversationId) async {
    try {
      dynamic response = await _apiService.postApi(
        AppUrl.pinConversation(conversationId),
        {},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> clearChat(String conversationId) async {
    try {
      dynamic response = await _apiService.deleteApi(
        AppUrl.clearChat(conversationId),
        {},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<MessageResponse> fetchMessages(String conversationId, {int page = 1, int limit = 50}) async {
    try {
      dynamic response = await _apiService.getApi("${AppUrl.getMessages(conversationId)}?page=$page&limit=$limit");
      return MessageResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> sendMessage(Map<String, dynamic> data) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.sendMessage, data);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> uploadAttachment(dio.FormData data) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.uploadChatAttachment, data);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> editMessage(String messageId, String text) async {
    try {
      dynamic response = await _apiService.putApi(
        AppUrl.editMessage(messageId),
        {'text': text},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> unsendMessage(String messageId) async {
    try {
      dynamic response = await _apiService.postApi(
        AppUrl.unsendMessage(messageId),
        {},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> deleteMessage(String messageId) async {
    try {
      dynamic response = await _apiService.deleteApi(
        AppUrl.deleteMessage(messageId),
        {},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> reactToMessage(String messageId, String emoji) async {
    try {
      dynamic response = await _apiService.postApi(
        AppUrl.reactToMessage(messageId),
        {'emoji': emoji},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> pinMessage(String messageId) async {
    try {
      dynamic response = await _apiService.postApi(
        AppUrl.pinMessage(messageId),
        {},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserStatus> getUserStatus(String userId) async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getChatUserStatus(userId));
      return UserStatus.fromJson(response['data']);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PartnerModel>> searchUsers(String query) async {
    try {
      dynamic response = await _apiService.getApi("${AppUrl.searchChatUsers}?q=$query");
      return (response['data'] as List)
          .map((e) => PartnerModel.fromJson(e))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> blockUser(String userId) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.blockChatUser(userId), {});
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> unblockUser(String userId) async {
    try {
      dynamic response = await _apiService.deleteApi(AppUrl.unblockChatUser(userId), {});
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> getBlockedUsers() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getBlockedUsers);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MessageModel>> fetchPinnedMessages(String conversationId) async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getPinnedMessages(conversationId));
      return (response['data'] as List)
          .map((e) => MessageModel.fromJson(e))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MessageModel>> searchInMessages(String query, {String? conversationId}) async {
    try {
      String url = "${AppUrl.searchMessages}?q=$query";
      if (conversationId != null) {
        url += "&conversationId=$conversationId";
      }
      dynamic response = await _apiService.getApi(url);
      return (response['data'] as List)
          .map((e) => MessageModel.fromJson(e))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
