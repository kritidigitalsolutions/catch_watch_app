import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';

class ShareHelper {
  static const String appStoreLink = 'https://apps.apple.com/app/catch-watch/id123456789'; // TODO: Update with real ID
  static const String playStoreLink = 'https://play.google.com/store/apps/details?id=com.catchandwatch1.app';
  static const String websiteUrl = 'https://catchandwatch.com';

  static Future<void> shareContent({
    required String title,
    required String text,
    String? imageUrl,
    String? contentId,
    String contentType = 'video',
  }) async {
    try {
      String shareMessage = '$text\n\n';
      
      // Add specific content link (using website as base for now)
      if (contentId != null) {
        shareMessage += 'Watch here: $websiteUrl/$contentType/$contentId\n\n';
      }

      shareMessage += 'Download Catch Watch App:\n';
      shareMessage += 'Android: $playStoreLink\n';
      shareMessage += 'iOS: $appStoreLink';

      if (imageUrl != null && imageUrl.isNotEmpty) {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final temp = await getTemporaryDirectory();
          final path = '${temp.path}/shared_image.jpg';
          File(path).writeAsBytesSync(response.bodyBytes);

          await Share.shareXFiles(
            [XFile(path)],
            text: shareMessage,
            subject: title,
          );
          return;
        }
      }

      // Fallback to text only if image fails or not provided
      await Share.share(shareMessage, subject: title);
    } catch (e) {
      debugPrint('Error sharing content: $e');
      // Final fallback
      await Share.share(text, subject: title);
    }
  }
}
