import 'package:catch_watch/views/after_login_pages/home_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/profile_screen.dart';
import 'package:catch_watch/views/after_login_pages/upload_video/reel_upload_screen.dart';
import 'package:catch_watch/views/after_login_pages/search_screen.dart';
import 'package:flutter/material.dart';

import '../../views/after_login_pages/short_video_screen.dart';

class HomeScreenProvider extends ChangeNotifier {
  int _pageIndex = 0;
  bool _showButtons = false;

  int get pageIndex => _pageIndex;
  bool get showButtons => _showButtons;

  final List<Widget> _screens = [
    HomeScreen(), // Home Tab
    ShortVideoPlayerScreen(), // Short Tab
    UploadScreen(), // Empty (Floating button handled separately)
    SearchScreen(), // Search Tab
    ProfileScreen(), // Profile Tab
  ];

  List<Widget> get screenPage => _screens;

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

  final List<CarouselItem> banners = const [
    CarouselItem(
      image: 'assets/images/2.png',
      title: 'DHURANDHAR',
      subtitle: 'The Revenge',
      meta: '2026  •  Adventure / Spy  •  3h 49m',
      badge: 'NEW RELEASE',
    ),
  ];

  final List<ContentItem> trending = const [
    ContentItem(
      image: 'assets/images/1.png',
      views: '125k',
      title: 'Dark Realm',
    ),
    ContentItem(
      image: 'assets/images/2.png',
      views: '89k',
      title: 'Into the Wild',
    ),
    ContentItem(
      image: 'assets/images/3.png',
      views: '204k',
      title: 'Thunder Strike',
    ),
    ContentItem(image: 'assets/images/1.png', views: '67k', title: 'The Crown'),
  ];

  final List<ContentItem> continueWatching = const [
    ContentItem(
      image: 'assets/images/2.png',
      views: '125k',
      title: 'Dhurandhar',
      progress: '0.65',
      remaining: '1h 14m remaining',
    ),
    ContentItem(
      image: 'assets/images/1.png',
      views: '89k',
      title: 'Into the Wild',
      progress: '0.3',
      remaining: '2h 10m remaining',
    ),
  ];

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
  final String title;

  const ContentItem({
    required this.image,
    required this.views,
    required this.title,
    this.progress,
    this.remaining,
  });
}
