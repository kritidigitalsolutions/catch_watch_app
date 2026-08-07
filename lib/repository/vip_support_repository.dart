import 'package:dio/dio.dart';
import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/vip_support_model.dart';
import '../res/appUrl.dart';

class VipSupportRepository {
  final BaseApiService _apiService = NetworkApiService();

  Future<VipSupportAccessResponse> checkVipAccess() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.vipAccessCheck);
      return VipSupportAccessResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<VipTicketResponse> getMyTickets() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.vipTickets);
      return VipTicketResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<VipTicketDetailResponse> getTicketDetail(String ticketId) async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.vipTicketDetail(ticketId));
      return VipTicketDetailResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> createTicket(FormData data) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.vipTickets, data);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> replyToTicket(String ticketId, FormData data) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.vipReplyTicket(ticketId), data);
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
