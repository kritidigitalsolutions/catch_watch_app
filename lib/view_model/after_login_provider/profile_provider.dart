import 'package:catch_watch/models/user_model.dart';
import 'package:catch_watch/repository/auth_repository.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/utils/hive_service/userdetail.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

enum ProfileTab { videos, cuts, saved, liked }

class VideoItem {
  final String image;
  final String views;
  const VideoItem({required this.image, required this.views});
}

class ProfileProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  ProfileTab _activeTab = ProfileTab.videos;

  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  String? _selectedImagePath;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedImagePath => _selectedImagePath;

  ProfileProvider() {
    _loadUserFromHive();
  }

  void _loadUserFromHive() {
    final hiveUser = HiveService.getUser();
    if (hiveUser != null) {
      _user = UserModel(
        id: hiveUser.sId,
        name: hiveUser.name,
        phone: hiveUser.phone,
        profileImage: hiveUser.image,
      );
    }
  }

  Future<void> fetchProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authRepository.getProfile();
      if (response['success'] == true) {
        _user = UserModel.fromJson(response['user']);
        
        // Update Hive with latest data
        final currentHiveUser = HiveService.getUser();
        if (currentHiveUser != null) {
          currentHiveUser.name = _user?.name;
          currentHiveUser.phone = _user?.phone;
          currentHiveUser.image = _user?.profileImage;
          await HiveService.saveUser(currentHiveUser);
        }
      } else {
        _error = response['message'] ?? 'Failed to fetch profile';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout(BuildContext context) async {
    await HiveService.logout();
    // Navigate to onboarding
    Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
  }

  Future<void> pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 50);
    if (image != null) {
      _selectedImagePath = image.path;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String username,
    required String bio,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      dio.FormData formData = dio.FormData.fromMap({
        'name': name,
        'username': username,
        'bio': bio,
        'genres': _user?.genres ?? [],
      });

      if (_selectedImagePath != null) {
        formData.files.add(MapEntry(
          'profileImage',
          await dio.MultipartFile.fromFile(_selectedImagePath!, filename: 'profile.jpg'),
        ));
      }

      final response = await _authRepository.updateProfile(formData);

      if (response['success'] == true) {
        _user = UserModel.fromJson(response['user']);
        _selectedImagePath = null; // Reset after success

        // Update Hive
        final currentHiveUser = HiveService.getUser();
        if (currentHiveUser != null) {
          currentHiveUser.name = _user?.name;
          currentHiveUser.image = _user?.profileImage;
          await HiveService.saveUser(currentHiveUser);
        }
        return true;
      } else {
        _error = response['message'] ?? 'Failed to update profile';
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

  String get name => _user?.name ?? 'Guest User';
  String get handle => _user?.username ?? '@guest';
  String get avatarAsset => _user?.profileImage ?? 'assets/images/logo.jpg';
  String get videosCount => '0';
  String get followers => '0';
  String get following => '0';

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