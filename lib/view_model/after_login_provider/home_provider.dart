import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/repository/content_repository.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/views/after_login_pages/home_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/profile_screen.dart';
import 'package:catch_watch/views/after_login_pages/upload_video/reel_upload_screen.dart';
import 'package:catch_watch/views/after_login_pages/search_screen.dart';
import 'package:flutter/material.dart';

import '../../views/after_login_pages/short_video_screen.dart';

class HomeScreenProvider extends ChangeNotifier {
  final ContentRepository _contentRepository = ContentRepository();

  int _pageIndex = 0;
  bool _showButtons = false;
  bool _isLoading = false;
  String? _error;

  List<Content> _allContent = [];
  List<Content> _trending = [];
  List<Content> _movies = [];
  List<Content> _tvShows = [];
  List<Content> _shortFilms = [];
  List<Content> _banners = [];

  int get pageIndex => _pageIndex;
  bool get showButtons => _showButtons;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Content> get allContent => _allContent;
  List<Content> get trending => _trending;
  List<Content> get movies => _movies;
  List<Content> get tvShows => _tvShows;
  List<Content> get shortFilms => _shortFilms;
  List<Content> get bannersList => _banners;

  HomeScreenProvider() {
    fetchAllContent();
    _loadWatchHistory();
  }

  void _loadWatchHistory() {
    final history = HiveService.getWatchHistory();
    if (history.isNotEmpty) {
      _continueWatching = history.values.map((data) {
        final Map<String, dynamic> itemData = Map<String, dynamic>.from(data);
        return ContentItem(
          image: itemData['image'],
          views: itemData['views'] ?? '100k',
          title: itemData['title'],
          progress: itemData['progress'],
          remaining: itemData['remaining'],
          content: itemData['content'] != null ? Content.fromJson(Map<String, dynamic>.from(itemData['content'])) : null,
        );
      }).toList();
      notifyListeners();
    }
  }

  List<Widget> get screenPage => [
    HomeScreen(), // Home Tab
    ShortVideoPlayerScreen(isVisible: _pageIndex == 1), // Short Tab
    UploadScreen(), // Empty (Floating button handled separately)
    SearchScreen(), // Search Tab
    ProfileScreen(), // Profile Tab
  ];

  void changePage(int index) {
    _pageIndex = index;
    notifyListeners();
  }

  void toggle() {
    _showButtons = !_showButtons;
    notifyListeners();
  }

  int _selectedTabIndex = 0;
  int _currentBannerIndex = 0;

  final List<String> tabs = [
    'All Shows',
    'Movies',
    'Short Films',
    'TV Shows',
  ];

  List<ContentItem> _continueWatching = [];
  List<ContentItem> get continueWatching => _continueWatching;

  void addToContinueWatching(Content content, Duration position, Duration total) {
    if (total.inMilliseconds == 0) return;
    final progress = position.inMilliseconds / total.inMilliseconds;
    final remaining = total - position;
    
    final newItem = ContentItem(
      image: content.poster ?? '',
      views: '100k',
      title: content.title ?? '',
      progress: progress.toStringAsFixed(2),
      remaining: '${remaining.inMinutes}m remaining',
      content: content,
    );

    // Save to Hive
    HiveService.saveWatchHistory(content.id!, {
      'image': newItem.image,
      'title': newItem.title,
      'progress': newItem.progress,
      'remaining': newItem.remaining,
      'content': content.toJson(),
    });

    // Remove if already exists to move it to the front
    _continueWatching.removeWhere((item) => item.content?.id == content.id);
    _continueWatching.insert(0, newItem);
    
    // Keep only last 10
    if (_continueWatching.length > 10) {
      _continueWatching.removeLast();
    }
    
    notifyListeners();
  }

  Future<void> fetchAllContent() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _contentRepository.getMovies(),
        _contentRepository.getTvShows(),
        _contentRepository.getShortFilms(),
      ]);

      _movies = results[0];
      _tvShows = results[1];
      _shortFilms = results[2];

      _allContent = [..._movies, ..._tvShows, ..._shortFilms];
      _allContent.shuffle(); // Mix them for "All Shows"

      _trending = _allContent.where((c) => c.category?.contains('trending') ?? false).toList();
      _banners = _allContent.where((c) => c.category?.contains('trending') ?? false).toList();

      if (_banners.isEmpty && _allContent.isNotEmpty) {
        _banners = _allContent.take(5).toList();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchContent() async {
    await fetchAllContent();
  }

  // ... (remove the old const continueWatching)

  int get selectedTabIndex => _selectedTabIndex;
  int get currentBannerIndex => _currentBannerIndex;

  void selectTab(int index) {
    _selectedTabIndex = index;
    _currentBannerIndex = 0; // Reset index when switching tabs
    notifyListeners();
  }

  void updateBannerIndex(int index) {
    _currentBannerIndex = index;
    notifyListeners();
  }
}

class CarouselItem {
  final String image;
  final String title;
  final String subtitle;
  final String meta;
  final String badge;

  const CarouselItem({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.meta,
    this.badge = 'NEW RELEASE',
  });
}

class ContentItem {
  final String image;
  final String views;
  final String? progress; // 0.0 - 1.0 as string, null if not started
  final String? remaining;
  final String? meta;
  final String? episode;
  final String? badge;
  final String title;
  final Content? content;

  const ContentItem({
    required this.image,
    required this.views,
    required this.title,
    this.progress,
    this.remaining,
    this.meta,
    this.episode,
    this.badge,
    this.content,
  });
}
