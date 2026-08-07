import 'package:catch_watch/models/user_model.dart';
import 'package:catch_watch/repository/user_repository.dart';
import 'package:flutter/material.dart';

class UserSearchProvider extends ChangeNotifier {
  final UserRepository _userRepository = UserRepository();

  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _error;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      _users = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _userRepository.searchUsers(query);
      if (response['success'] == true) {
        final List<dynamic> usersData = response['users'] ?? [];
        _users = usersData.map((e) => UserModel.fromJson(e)).toList();
      } else {
        _error = response['message'] ?? 'Failed to search users';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _users = [];
    _error = null;
    notifyListeners();
  }
}
