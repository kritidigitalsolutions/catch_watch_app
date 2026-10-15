import 'package:catch_watch/data/network/api_network_service.dart';
import 'package:catch_watch/data/network/base_api_service.dart';
import 'package:catch_watch/models/report_model.dart';
import 'package:catch_watch/res/appUrl.dart';

class ReportRepository {
  final BaseApiService _apiService = NetworkApiService();

  /// Submits a UGC report for a reel, comment, or user profile.
  ///
  /// Required fields:
  /// - [targetType]: 'reel', 'comment', or 'user'
  /// - [targetId]: non-empty document/user ID
  /// - [reason]: exact backend enum value (e.g., 'SPAM', 'INAPPROPRIATE_CONTENT', etc.)
  ///
  /// Optional fields:
  /// - [description]: multiline additional details (omitted when null or empty)
  Future<ReportResponse> submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
  }) async {
    final trimmedId = targetId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError('Target ID cannot be empty');
    }

    final Map<String, dynamic> data = {
      'targetType': targetType.trim(),
      'targetId': trimmedId,
      'reason': reason.trim(),
    };

    if (description != null) {
      final trimmedDesc = description.trim();
      if (trimmedDesc.isNotEmpty) {
        data['description'] = trimmedDesc;
      }
    }

    final dynamic response = await _apiService.postApi(AppUrl.reports, data);

    if (response is Map<String, dynamic>) {
      return ReportResponse.fromJson(response);
    } else {
      return ReportResponse(
        success: true,
        message: 'Report submitted successfully.',
      );
    }
  }
}
