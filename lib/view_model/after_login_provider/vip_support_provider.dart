import 'package:catch_watch/models/vip_support_model.dart';
import 'package:catch_watch/repository/vip_support_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class VipSupportProvider extends ChangeNotifier {
  final VipSupportRepository _repository = VipSupportRepository();

  bool _hasAccess = false;
  List<VipTicket> _tickets = [];
  VipTicket? _selectedTicket;
  bool _isLoading = false;
  String? _error;

  bool get hasAccess => _hasAccess;
  List<VipTicket> get tickets => _tickets;
  VipTicket? get selectedTicket => _selectedTicket;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> checkAccess() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.checkVipAccess();
      _hasAccess = response.hasAccess ?? false;
    } catch (e) {
      _error = e.toString();
      _hasAccess = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyTickets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.getMyTickets();
      if (response.success == true) {
        _tickets = response.tickets ?? [];
      } else {
        _error = 'Failed to fetch tickets';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTicketDetail(String ticketId) async {
    _isLoading = true;
    _error = null;
    // We don't necessarily want to clear selectedTicket if we're refreshing
    notifyListeners();

    try {
      final response = await _repository.getTicketDetail(ticketId);
      if (response.success == true) {
        _selectedTicket = response.ticket;
        if (_selectedTicket != null && response.messages != null) {
          _selectedTicket!.messages = response.messages;
        }
      } else {
        _error = 'Failed to fetch ticket details';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTicket(FormData data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.createTicket(data);
      if (response['success'] == true) {
        await fetchMyTickets();
        return true;
      } else {
        _error = response['message'] ?? 'Failed to create ticket';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> replyToTicket(String ticketId, FormData data) async {
    // We don't set full page isLoading here to avoid blocking chat UI
    try {
      final response = await _repository.replyToTicket(ticketId, data);
      if (response['success'] == true) {
        await fetchTicketDetail(ticketId);
        return true;
      } else {
        _error = response['message'] ?? 'Failed to send reply';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }
  
  void setSelectedTicket(VipTicket? ticket) {
    _selectedTicket = ticket;
    notifyListeners();
  }
}
