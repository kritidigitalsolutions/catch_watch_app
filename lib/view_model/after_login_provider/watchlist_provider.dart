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

  Future<void> addItem(String itemId) async {
    try {
      await _watchlistRepository.addToWatchlist(itemId);
      await fetchWatchlist();
    } catch (e) {
      debugPrint('Error adding to watchlist: $e');
    }
  }

  Future<void> removeItem(String id) async {
    try {
      await _watchlistRepository.removeFromWatchlist(id);
      _items.removeWhere((element) => element.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
    }
  }
}
