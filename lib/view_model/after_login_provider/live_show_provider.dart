import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/live_show_model.dart';
import '../../repository/live_show_repository.dart';

class LiveShowProvider extends ChangeNotifier {
  final LiveShowRepository _repository = LiveShowRepository();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isDetailLoading = false;
  bool get isDetailLoading => _isDetailLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  List<LiveShow> _shows = [];
  List<LiveShow> get shows => _shows;

  LiveShow? _featuredShow;
  LiveShow? get featuredShow => _featuredShow;

  LiveShow? _currentShowDetail;
  LiveShow? get currentShowDetail => _currentShowDetail;

  String _selectedStatus = 'ALL';
  String get selectedStatus => _selectedStatus;

  String _selectedCategory = 'ALL';
  String get selectedCategory => _selectedCategory;

  Timer? _pollingTimer;
  Timer? _heartbeatTimer;

  LiveShowProvider() {
    fetchLiveShowsData();
  }

  Future<void> fetchLiveShowsData({String status = 'ALL', String category = 'ALL', String search = ''}) async {
    _selectedStatus = status;
    _selectedCategory = category;
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getShows(status: status, category: category, search: search),
        _repository.getFeaturedShow(),
      ]);

      final res = results[0] as LiveShowsResponse;
      _shows = res.shows ?? [];
      _featuredShow = results[1] as LiveShow?;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      // Fallback sample live show so UI always displays right after matches even if backend is offline/empty
      if (_shows.isEmpty) {
        _shows = [
          LiveShow(
            id: 'sample_show_1',
            title: 'CatchWatch Live Creator Broadcast & Q&A',
            description: 'Join top creators streaming live right now, discussing upcoming movies, web series & interactive fan chats.',
            category: 'ENTERTAINMENT',
            status: 'LIVE',
            isLive: true,
            banner: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800',
            streamUrl: '',
            viewerCount: 1420,
            host: HostInfo(
              id: 'host_1',
              name: 'CatchWatch Official',
              username: 'catchwatch',
              isVerified: true,
            ),
            chatMessages: [
              LiveShowComment(username: 'Rahul', message: 'Hello CatchWatch live! Great show!'),
              LiveShowComment(username: 'Priya', message: 'When is the next movie trailer coming out?'),
            ],
          ),
        ];
      }

      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadShowDetails(String showId) async {
    _isDetailLoading = true;
    notifyListeners();

    try {
      _currentShowDetail = await _repository.getShowDetails(showId);
      if (_currentShowDetail == null && showId == 'sample_show_1') {
        _currentShowDetail = _shows.firstWhere((s) => s.id == 'sample_show_1', orElse: () => _shows.first);
      }
      _startHeartbeat(showId);
      _startPolling(showId);
    } catch (e) {
      if (showId == 'sample_show_1' && _shows.isNotEmpty) {
        _currentShowDetail = _shows.first;
      } else {
        _errorMessage = e.toString();
      }
    } finally {
      _isDetailLoading = false;
      notifyListeners();
    }
  }

  void _startHeartbeat(String showId) {
    _heartbeatTimer?.cancel();
    if (!showId.startsWith('sample')) {
      _repository.pingViewCount(showId);
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        _repository.pingViewCount(showId);
      });
    }
  }

  void _startPolling(String showId) {
    _pollingTimer?.cancel();
    if (!showId.startsWith('sample')) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        try {
          final updated = await _repository.getShowDetails(showId);
          if (updated != null) {
            _currentShowDetail = updated;
            notifyListeners();
          }
        } catch (_) {}
      });
    }
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _heartbeatTimer?.cancel();
    _pollingTimer = null;
    _heartbeatTimer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
