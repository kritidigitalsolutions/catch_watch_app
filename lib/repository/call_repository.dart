import 'package:catch_watch/data/network/api_network_service.dart';
import 'package:catch_watch/models/call_model.dart';
import 'package:catch_watch/res/appUrl.dart';

class CallRepository {
  final NetworkApiService _apiService = NetworkApiService();

  Future<CallModel> startCall(String receiverId, String type) async {
    try {
      dynamic response = await _apiService.postApi(
        AppUrl.startCall,
        {
          'receiverId': receiverId,
          'type': type,
        },
      );
      
      // Handle the structure: { success, message, call: {...}, agora: { token, ... } }
      Map<String, dynamic> callData = Map<String, dynamic>.from(response['call']);
      if (response['agora'] != null && response['agora'] is Map) {
        if (response['agora']['token'] != null) {
          callData['agoraToken'] = response['agora']['token'];
        }
        if (response['agora']['uid'] != null) {
          callData['agoraUid'] = response['agora']['uid'];
        }
      }
      
      return CallModel.fromJson(callData);
    } catch (e) {
      rethrow;
    }
  }

  Future<CallModel> acceptCall(String callId) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.acceptCall(callId), {});
      
      // Usually accept call also returns the call object and token
      Map<String, dynamic> callData;
      if (response['call'] != null) {
        callData = Map<String, dynamic>.from(response['call']);
      } else if (response['data'] != null) {
        callData = Map<String, dynamic>.from(response['data']);
      } else {
        callData = Map<String, dynamic>.from(response);
      }

      if (response['agora'] != null && response['agora'] is Map) {
        if (response['agora']['token'] != null) {
          callData['agoraToken'] = response['agora']['token'];
        }
        if (response['agora']['uid'] != null) {
          callData['agoraUid'] = response['agora']['uid'];
        }
      }
      
      return CallModel.fromJson(callData);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectCall(String callId) async {
    try {
      await _apiService.postApi(AppUrl.rejectCall(callId), {});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> busyCall(String callId) async {
    try {
      await _apiService.postApi(AppUrl.busyCall(callId), {});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelCall(String callId) async {
    try {
      await _apiService.postApi(AppUrl.cancelCall(callId), {});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> missedCall(String callId) async {
    try {
      await _apiService.postApi(AppUrl.missedCall(callId), {});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> endCall(String callId) async {
    try {
      await _apiService.postApi(AppUrl.endCall(callId), {});
    } catch (e) {
      rethrow;
    }
  }

  Future<String> getCallToken(String callId) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.getCallToken(callId), {});
      if (response is Map) {
        if (response['agora'] != null &&
            response['agora'] is Map &&
            response['agora']['token'] != null) {
          final token = response['agora']['token']?.toString().trim();
          if (token != null && token.isNotEmpty) return token;
        }
        if (response['data'] != null &&
            response['data'] is Map &&
            response['data']['token'] != null) {
          final token = response['data']['token']?.toString().trim();
          if (token != null && token.isNotEmpty) return token;
        }
        if (response['token'] != null) {
          final token = response['token']?.toString().trim();
          if (token != null && token.isNotEmpty) return token;
        }
      }
      throw Exception('Invalid or missing Agora token in response');
    } catch (e) {
      rethrow;
    }
  }

  Future<CallModel> getCallDetails(String callId) async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getCallDetails(callId));
      Map<String, dynamic> callData =
          Map<String, dynamic>.from(response['call'] ?? response['data'] ?? response);
      if (response is Map && response['agora'] != null && response['agora'] is Map) {
        if (response['agora']['token'] != null && callData['agoraToken'] == null) {
          callData['agoraToken'] = response['agora']['token'];
        }
        if (response['agora']['uid'] != null && callData['agoraUid'] == null) {
          callData['agoraUid'] = response['agora']['uid'];
        }
      }
      return CallModel.fromJson(callData);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchCallHistory({int page = 1, int limit = 20}) async {
    try {
      dynamic response = await _apiService.getApi("${AppUrl.getCallHistory}?page=$page&limit=$limit");
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
