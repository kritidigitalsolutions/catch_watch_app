import 'package:flutter/material.dart';

enum ProfileTab { videos, cuts, saved, liked }

class VideoItem {
  final String image;
  final String views;
  const VideoItem({required this.image, required this.views});
}

class ProfileProvider extends ChangeNotifier {
  ProfileTab _activeTab = ProfileTab.videos;

  final String name = 'Raghav Chadda';
  final String handle = '@chaddaraghav5';
  final String avatarAsset = 'assets/images/logo.jpg';
  final String videosCount = '248';
  final String followers = '14.2k';
  final String following = '891';

  final List<VideoItem> videos = const [
    VideoItem(image: 'assets/images/1.png', views: '125k'),
    VideoItem(image: 'assets/images/2.png', views: '89k'),
    VideoItem(image: 'assets/images/3.png', views: '204k'),
    VideoItem(image: 'assets/images/1.png', views: '67k'),
    VideoItem(image: 'assets/images/2.png', views: '312k'),
    VideoItem(image: 'assets/images/3.png', views: '45k'),
    VideoItem(image: 'assets/images/1.png', views: '178k'),
    VideoItem(image: 'assets/images/2.png', views: '92k'),
    VideoItem(image: 'assets/images/3.png', views: '561k'),
  ];

  ProfileTab get activeTab => _activeTab;

  List<VideoItem> get currentTabItems => videos; // extend for cuts/saved/liked tabs

  void setTab(ProfileTab tab) {
    _activeTab = tab;
    notifyListeners();
  }
}