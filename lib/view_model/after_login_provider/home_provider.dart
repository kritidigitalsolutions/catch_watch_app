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

  final List<CarouselItem> banners = const [
    CarouselItem(
      image: 'assets/banner/1.jpg',
      title: 'DHURANDHAR',
      subtitle: 'The Revenge',
      meta: '2026  •  Adventure / Spy  •  3h 49m',
      badge: 'NEW RELEASE',
    ),
    CarouselItem(
      image: 'assets/banner/3.avif',
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
      meta: 'Movie • Spy Thriller',
      episode: 'Resume from 1:42:18',
      badge: '4K',
    ),
    ContentItem(
      image: 'assets/images/1.png',
      views: '89k',
      title: 'Into the Wild',
      progress: '0.3',
      remaining: '2h 10m remaining',
      meta: 'Series • S1 E4',
      episode: 'Episode 4: The River Run',
      badge: 'HD',
    ),
    ContentItem(
      image: 'assets/images/3.png',
      views: '204k',
      title: 'Thunder Strike',
      progress: '0.48',
      remaining: '42m remaining',
      meta: 'Movie • Action',
      episode: 'Resume from 48:02',
      badge: 'NEW',
    ),
    ContentItem(
      image: 'assets/images/1.png',
      views: '67k',
      title: 'The Crown',
      progress: '0.82',
      remaining: '12m remaining',
      meta: 'Series • S2 E7',
      episode: 'Episode 7: Royal Turn',
      badge: 'HD',
    ),
    ContentItem(
      image: 'assets/images/2.png',
      views: '312k',
      title: 'Midnight Case',
      progress: '0.18',
      remaining: '1h 51m remaining',
      meta: 'Movie • Crime Drama',
      episode: 'Resume from 22:34',
      badge: 'TOP 10',
    ),
    ContentItem(
      image: 'assets/images/3.png',
      views: '45k',
      title: 'Campus Diaries',
      progress: '0.57',
      remaining: '23m remaining',
      meta: 'Series • S1 E2',
      episode: 'Episode 2: Fresh Start',
      badge: 'HD',
    ),
  ];

  final List<ContentItem> actionMovies = const [
    ContentItem(
      image: 'assets/images/3.png',
      views: '204k',
      title: 'Thunder Strike',
      meta: 'Action • 2h 18m',
      badge: '4K',
    ),
    ContentItem(
      image: 'assets/images/2.png',
      views: '312k',
      title: 'Dhurandhar',
      meta: 'Spy Action • 3h 49m',
      badge: 'TOP 10',
    ),
    ContentItem(
      image: 'assets/images/1.png',
      views: '178k',
      title: 'Steel Chase',
      meta: 'Action Thriller • 2h 05m',
      badge: 'HD',
    ),
    ContentItem(
      image: 'assets/images/3.png',
      views: '98k',
      title: 'Red Target',
      meta: 'Crime Action • 1h 56m',
      badge: 'NEW',
    ),
    ContentItem(
      image: 'assets/images/2.png',
      views: '221k',
      title: 'Final Mission',
      meta: 'Adventure • 2h 22m',
      badge: '4K',
    ),
  ];

  final List<ContentItem> horrorMovies = const [
    ContentItem(
      image: 'assets/images/1.png',
      views: '154k',
      title: 'Dark Realm',
      meta: 'Horror • 1h 48m',
      badge: 'HD',
    ),
    ContentItem(
      image: 'assets/images/3.png',
      views: '86k',
      title: 'Night House',
      meta: 'Supernatural • 1h 52m',
      badge: 'NEW',
    ),
    ContentItem(
      image: 'assets/images/2.png',
      views: '119k',
      title: 'Midnight Case',
      meta: 'Mystery Horror • 2h 01m',
      badge: 'TOP 10',
    ),
    ContentItem(
      image: 'assets/images/1.png',
      views: '73k',
      title: 'The Last Door',
      meta: 'Psychological • 1h 44m',
      badge: 'HD',
    ),
    ContentItem(
      image: 'assets/images/3.png',
      views: '132k',
      title: 'Haunted Signal',
      meta: 'Found Footage • 1h 37m',
      badge: '4K',
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
  final String? meta;
  final String? episode;
  final String? badge;
  final String title;

  const ContentItem({
    required this.image,
    required this.views,
    required this.title,
    this.progress,
    this.remaining,
    this.meta,
    this.episode,
    this.badge,
  });
}
