import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/repository/content_repository.dart';
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
  List<Content> _banners = [];

  int get pageIndex => _pageIndex;
  bool get showButtons => _showButtons;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Content> get allContent => _allContent;
  List<Content> get trending => _trending;
  List<Content> get movies => _movies;
  List<Content> get bannersList => _banners;

  HomeScreenProvider() {
    fetchContent();
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
    'Reality',
  ];

  List<ContentItem> _continueWatching = [];
  List<ContentItem> get continueWatching => _continueWatching;

  Future<void> fetchContent() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _contentRepository.getContent();
      if (response.success == true) {
        _allContent = response.content ?? [];
        _trending = _allContent.where((c) => c.isTrending == true).toList();
        _movies = _allContent.where((c) => c.type == 'movie').toList();
        _banners = _allContent.where((c) => c.category?.contains('trending') ?? false).toList();
        
        // If banners are empty, use the first few items
        if (_banners.isEmpty && _allContent.isNotEmpty) {
          _banners = _allContent.take(3).toList();
        }

        // Mock "Continue Watching" from real content if available
        if (_allContent.isNotEmpty) {
          _continueWatching = _allContent.take(2).map((c) => ContentItem(
            image: c.poster ?? '',
            views: '100k',
            title: c.title ?? '',
            progress: '0.4',
            remaining: '45m remaining',
            content: c,
          )).toList();
        }
      } else {
        _error = 'Failed to load content';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ... (remove the old const continueWatching)

  int get selectedTabIndex => _selectedTabIndex;
  int get currentBannerIndex => _currentBannerIndex;

  void selectTab(int index) {
    _selectedTabIndex = index;
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
