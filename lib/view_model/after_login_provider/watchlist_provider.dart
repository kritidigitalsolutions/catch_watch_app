import 'package:catch_watch/models/watchlist_model.dart';
import 'package:catch_watch/repository/watchlist_repository.dart';
import 'package:flutter/material.dart';

class WatchlistProvider extends ChangeNotifier {
  final WatchlistRepository _watchlistRepository = WatchlistRepository();

  List<WatchlistItem> _items = [];
  bool _isLoading = false;
  String? _error;

  List<WatchlistItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchWatchlist() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _watchlistRepository.getWatchlist();
      if (response.success == true) {
        _items = response.data ?? [];
      } else {
        _error = 'Failed to fetch watchlist';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addItem(String itemId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _watchlistRepository.addToWatchlist(itemId);
      // Wait for fetchWatchlist to complete so _items is updated
      await fetchWatchlist();
      return true;
    } catch (e) {
      debugPrint('Error adding to watchlist: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> removeItem(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _watchlistRepository.removeFromWatchlist(id);
      _items.removeWhere((element) => element.id == id);
      return true;
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
