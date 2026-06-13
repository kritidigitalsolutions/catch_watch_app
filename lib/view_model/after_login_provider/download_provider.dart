import 'dart:io';
import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class DownloadProvider extends ChangeNotifier {
  final Dio _dio = Dio();
  final Map<String, double> _downloadProgress = {};
  
  Map<String, double> get downloadProgress => _downloadProgress;

  List<Map<dynamic, dynamic>> getAllDownloads() {
    return HiveService.getDownloads().values.cast<Map<dynamic, dynamic>>().toList();
  }

  bool isDownloaded(String contentId) {
    return HiveService.getDownloads().containsKey(contentId);
  }

  Future<void> removeDownload(String contentId) async {
    final downloads = HiveService.getDownloads();
    final data = downloads[contentId];
    if (data != null) {
      try {
        if (data['videoPath'] != null) {
          final file = File(data['videoPath']);
          if (await file.exists()) await file.delete();
        }
        if (data['posterPath'] != null) {
          final file = File(data['posterPath']);
          if (await file.exists()) await file.delete();
        }
        if (data['bannerPath'] != null) {
          final file = File(data['bannerPath']);
          if (await file.exists()) await file.delete();
        }
      } catch (e) {
        debugPrint('Delete error: $e');
      }
      await Hive.box(HiveService.downloadsBoxName).delete(contentId);
      notifyListeners();
    }
  }

  Future<void> downloadVideo(Content content) async {
    if (content.videoUrl == null || content.videoUrl!.isEmpty) return;
    if (isDownloaded(content.id!)) return;

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final savePath = '${appDocDir.path}/downloads/${content.id}.mp4';
      final posterPath = '${appDocDir.path}/downloads/${content.id}_poster.jpg';
      final bannerPath = '${appDocDir.path}/downloads/${content.id}_banner.jpg';

      // Create directory
      await Directory('${appDocDir.path}/downloads').create(recursive: true);

      _downloadProgress[content.id!] = 0.0;
      notifyListeners();

      // Download Video
      await _dio.download(
        content.videoUrl!,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _downloadProgress[content.id!] = received / total;
            notifyListeners();
          }
        },
      );

      // Download Poster
      if (content.poster != null && content.poster!.isNotEmpty) {
        await _dio.download(content.poster!, posterPath);
      }

      // Download Banner
      if (content.banner != null && content.banner!.isNotEmpty) {
        await _dio.download(content.banner!, bannerPath);
      }

      // Save to Hive
      await HiveService.saveDownload(content.id!, {
        'id': content.id,
        'videoPath': savePath,
        'posterPath': posterPath,
        'bannerPath': bannerPath,
        'title': content.title,
        'content': content.toJson(),
      });

      _downloadProgress.remove(content.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Download error: $e');
      _downloadProgress.remove(content.id);
      notifyListeners();
    }
  }

  String? getLocalVideoPath(String contentId) {
    final downloadData = HiveService.getDownloads()[contentId];
    if (downloadData != null) {
      return downloadData['videoPath'];
    }
    return null;
  }
}
