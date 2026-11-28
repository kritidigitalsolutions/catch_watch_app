import 'package:flutter/foundation.dart';

/// Helper to extract YouTube video ID from various URL formats or direct IDs.
String? extractYouTubeId(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final clean = url.trim();
  if (clean.length == 11 && !clean.contains('/') && !clean.contains('.')) {
    return clean;
  }
  try {
    final uri = Uri.parse(clean);
    if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
      if (uri.pathSegments.contains('embed')) {
        final idx = uri.pathSegments.indexOf('embed');
        if (idx + 1 < uri.pathSegments.length) {
          final idCandidate = uri.pathSegments[idx + 1].split('?')[0];
          if (idCandidate.isNotEmpty) return idCandidate;
        }
      }
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments[0].split('?')[0];
      }
    }
  } catch (_) {}

  if (clean.contains('embed/')) {
    final parts = clean.split('embed/');
    if (parts.length > 1) {
      final sub = parts[1].split('?')[0].split('&')[0];
      if (sub.length >= 11) return sub.substring(0, 11);
    }
  }
  return null;
}

/// Normalized live show status enum supporting case-insensitive values.
enum LiveShowStatus {
  live,
  upcoming,
  ended,
  unknown;

  /// Parses status string case-insensitively ('LIVE', 'live', 'Live', etc.).
  static LiveShowStatus fromString(String? value) {
    if (value == null) return LiveShowStatus.unknown;
    final normalized = value.trim().toUpperCase();
    if (normalized == 'LIVE' ||
        normalized == 'IN_PROGRESS' ||
        normalized == 'ONGOING') {
      return LiveShowStatus.live;
    }
    if (normalized == 'UPCOMING' ||
        normalized == 'SCHEDULED' ||
        normalized == 'NOT_STARTED') {
      return LiveShowStatus.upcoming;
    }
    if (normalized == 'ENDED' ||
        normalized == 'COMPLETED' ||
        normalized == 'FINISHED' ||
        normalized == 'CLOSED') {
      return LiveShowStatus.ended;
    }
    return LiveShowStatus.unknown;
  }

  String get displayName {
    switch (this) {
      case LiveShowStatus.live:
        return 'LIVE';
      case LiveShowStatus.upcoming:
        return 'UPCOMING';
      case LiveShowStatus.ended:
        return 'ENDED';
      case LiveShowStatus.unknown:
        return 'UNKNOWN';
    }
  }
}

/// Null-safe model representing a live show.
@immutable
class LiveShowModel {
  final String id;
  final String title;
  final String? description;
  final String? category;
  final String rawStatus;
  final String? hostName;
  final String? hostAvatar;
  final String? streamUrl;
  final String? backupStreamUrl;
  final String? youtubeVideoId;
  final String? poster;
  final String? banner;
  final int viewerCount;
  final bool isPremium;
  final bool isFeatured;
  final DateTime? startTime;
  final DateTime? endTime;

  const LiveShowModel({
    required this.id,
    required this.title,
    this.description,
    this.category,
    required this.rawStatus,
    this.hostName,
    this.hostAvatar,
    this.streamUrl,
    this.backupStreamUrl,
    this.youtubeVideoId,
    this.poster,
    this.banner,
    this.viewerCount = 0,
    this.isPremium = false,
    this.isFeatured = false,
    this.startTime,
    this.endTime,
  });

  /// Case-insensitive show status resolution.
  LiveShowStatus get showStatus => LiveShowStatus.fromString(rawStatus);

  bool get isLive => showStatus == LiveShowStatus.live;
  bool get isUpcoming => showStatus == LiveShowStatus.upcoming;
  bool get isEnded => showStatus == LiveShowStatus.ended;

  bool get hasStream => streamUrl != null && streamUrl!.trim().isNotEmpty;
  bool get hasBackupStream =>
      backupStreamUrl != null && backupStreamUrl!.trim().isNotEmpty;

  factory LiveShowModel.fromJson(Map<String, dynamic> json) {
    // Parse ID
    final id = (json['id'] ?? json['_id'] ?? json['showId'] ?? '').toString();

    // Parse Title
    final title = (json['title'] ??
            json['showTitle'] ??
            json['name'] ??
            json['heading'] ??
            '')
        .toString();

    // Parse Status case-insensitively, default to UPCOMING if omitted
    final rawStatus =
        (json['status'] ?? json['showStatus'] ?? 'LIVE').toString().trim();

    // Parse Host / Creator info
    String? hostName;
    String? hostAvatar;
    if (json['host'] is Map) {
      final hostMap = json['host'] as Map;
      hostName = (hostMap['name'] ?? hostMap['username'] ?? hostMap['fullName'])?.toString();
      hostAvatar = (hostMap['avatar'] ?? hostMap['image'] ?? hostMap['photo'])?.toString();
    } else {
      hostName = (json['hostName'] ?? json['presenter'] ?? json['creator']?.toString())?.toString();
      hostAvatar = (json['hostAvatar'] ?? json['presenterAvatar'])?.toString();
    }

    // Parse Streams
    final streamUrl = (json['streamUrl'] ??
            json['stream_url'] ??
            json['stream'] ??
            json['liveUrl'] ??
            json['videoUrl'] ??
            json['hlsUrl'])
        ?.toString()
        .trim();

    final backupStreamUrl = (json['backupStreamUrl'] ??
            json['backup_stream_url'] ??
            json['backupUrl'] ??
            json['fallbackStreamUrl'])
        ?.toString()
        .trim();

    final youtubeVideoId = (json['youtubeVideoId'] ??
            json['youtube_video_id'] ??
            json['ytVideoId'])
        ?.toString()
        .trim();

    // Parse Boolean flags safely
    final isPremium = json['isPremium'] == true ||
        json['is_premium'] == true ||
        json['premium'] == true;

    final isFeatured = json['isFeatured'] == true ||
        json['is_featured'] == true ||
        json['featured'] == true;

    // Parse Viewer count safely (supports viewersCount, viewerCount, viewers, views)
    int viewers = 0;
    if (json['viewersCount'] != null) {
      viewers = int.tryParse(json['viewersCount'].toString()) ?? 0;
    } else if (json['viewerCount'] != null) {
      viewers = int.tryParse(json['viewerCount'].toString()) ?? 0;
    } else if (json['viewers'] != null) {
      viewers = int.tryParse(json['viewers'].toString()) ?? 0;
    } else if (json['views'] != null) {
      viewers = int.tryParse(json['views'].toString()) ?? 0;
    }

    // Parse DateTimes safely (supports scheduledStartTime, startTime, scheduledAt, showDate)
    DateTime? parsedStartTime;
    if (json['scheduledStartTime'] != null) {
      parsedStartTime = DateTime.tryParse(json['scheduledStartTime'].toString());
    } else if (json['startTime'] != null) {
      parsedStartTime = DateTime.tryParse(json['startTime'].toString());
    } else if (json['scheduledAt'] != null) {
      parsedStartTime = DateTime.tryParse(json['scheduledAt'].toString());
    } else if (json['showDate'] != null) {
      parsedStartTime = DateTime.tryParse(json['showDate'].toString());
    }

    DateTime? parsedEndTime;
    if (json['scheduledEndTime'] != null) {
      parsedEndTime = DateTime.tryParse(json['scheduledEndTime'].toString());
    } else if (json['endTime'] != null) {
      parsedEndTime = DateTime.tryParse(json['endTime'].toString());
    }

    // Parse Images (thumbnail, poster, banner)
    final thumbnail = (json['thumbnail'] ??
            json['poster'] ??
            json['posterUrl'] ??
            json['image'])
        ?.toString();

    final banner = (json['banner'] ??
            json['bannerUrl'] ??
            json['coverImage'])
        ?.toString();

    return LiveShowModel(
      id: id,
      title: title,
      description: (json['description'] ?? json['desc'] ?? json['summary'])?.toString(),
      category: (json['category'] ?? json['genre'])?.toString(),
      rawStatus: rawStatus,
      hostName: hostName,
      hostAvatar: hostAvatar,
      streamUrl: (streamUrl != null && streamUrl.isNotEmpty) ? streamUrl : null,
      backupStreamUrl: (backupStreamUrl != null && backupStreamUrl.isNotEmpty)
          ? backupStreamUrl
          : null,
      youtubeVideoId: (youtubeVideoId != null && youtubeVideoId.isNotEmpty) ? youtubeVideoId : null,
      poster: thumbnail,
      banner: (banner != null && banner.isNotEmpty) ? banner : thumbnail,
      viewerCount: viewers,
      isPremium: isPremium,
      isFeatured: isFeatured,
      startTime: parsedStartTime,
      endTime: parsedEndTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      'status': rawStatus,
      if (hostName != null) 'hostName': hostName,
      if (hostAvatar != null) 'hostAvatar': hostAvatar,
      if (streamUrl != null) 'streamUrl': streamUrl,
      if (backupStreamUrl != null) 'backupStreamUrl': backupStreamUrl,
      if (youtubeVideoId != null) 'youtubeVideoId': youtubeVideoId,
      if (poster != null) 'poster': poster,
      if (banner != null) 'banner': banner,
      'viewerCount': viewerCount,
      'isPremium': isPremium,
      'isFeatured': isFeatured,
      if (startTime != null) 'startTime': startTime!.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
    };
  }

  LiveShowModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? rawStatus,
    String? hostName,
    String? hostAvatar,
    String? streamUrl,
    String? backupStreamUrl,
    String? youtubeVideoId,
    String? poster,
    String? banner,
    int? viewerCount,
    bool? isPremium,
    bool? isFeatured,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return LiveShowModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      rawStatus: rawStatus ?? this.rawStatus,
      hostName: hostName ?? this.hostName,
      hostAvatar: hostAvatar ?? this.hostAvatar,
      streamUrl: streamUrl ?? this.streamUrl,
      backupStreamUrl: backupStreamUrl ?? this.backupStreamUrl,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      poster: poster ?? this.poster,
      banner: banner ?? this.banner,
      viewerCount: viewerCount ?? this.viewerCount,
      isPremium: isPremium ?? this.isPremium,
      isFeatured: isFeatured ?? this.isFeatured,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
