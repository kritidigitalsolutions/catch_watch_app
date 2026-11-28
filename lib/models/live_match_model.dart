import 'package:flutter/foundation.dart';

/// Normalized match status enum supporting case-insensitive values.
enum LiveMatchStatus {
  live,
  upcoming,
  completed,
  unknown;

  /// Parses status string case-insensitively ('LIVE', 'live', 'Live', etc.).
  static LiveMatchStatus fromString(String? value) {
    if (value == null) return LiveMatchStatus.unknown;
    final normalized = value.trim().toUpperCase();
    if (normalized == 'LIVE' ||
        normalized == 'IN_PROGRESS' ||
        normalized == 'ONGOING') {
      return LiveMatchStatus.live;
    }
    if (normalized == 'UPCOMING' ||
        normalized == 'SCHEDULED' ||
        normalized == 'NOT_STARTED') {
      return LiveMatchStatus.upcoming;
    }
    if (normalized == 'COMPLETED' ||
        normalized == 'FINISHED' ||
        normalized == 'ENDED' ||
        normalized == 'RESULT') {
      return LiveMatchStatus.completed;
    }
    return LiveMatchStatus.unknown;
  }

  String get displayName {
    switch (this) {
      case LiveMatchStatus.live:
        return 'LIVE';
      case LiveMatchStatus.upcoming:
        return 'UPCOMING';
      case LiveMatchStatus.completed:
        return 'COMPLETED';
      case LiveMatchStatus.unknown:
        return 'UNKNOWN';
    }
  }
}

/// Team representation in a live cricket match.
@immutable
class TeamModel {
  final String? id;
  final String name;
  final String? shortName;
  final String? logo;
  final String? score;
  final String? overs;
  final int? wickets;
  final int? runs;

  const TeamModel({
    this.id,
    required this.name,
    this.shortName,
    this.logo,
    this.score,
    this.overs,
    this.wickets,
    this.runs,
  });

  /// Factory supporting both structured Map data and plain string names.
  factory TeamModel.fromDynamic(dynamic data) {
    if (data == null) {
      return const TeamModel(name: 'TBD');
    }
    if (data is String) {
      return TeamModel(name: data.trim());
    }
    if (data is Map<String, dynamic>) {
      return TeamModel.fromJson(data);
    }
    if (data is Map) {
      return TeamModel.fromJson(Map<String, dynamic>.from(data));
    }
    return const TeamModel(name: 'TBD');
  }

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    int? parsedRuns;
    if (json['runs'] != null) {
      parsedRuns = int.tryParse(json['runs'].toString());
    }

    int? parsedWickets;
    if (json['wickets'] != null) {
      parsedWickets = int.tryParse(json['wickets'].toString());
    }

    return TeamModel(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      name: (json['name'] ?? json['teamName'] ?? json['title'] ?? 'TBD')
          .toString()
          .trim(),
      shortName: json['shortName']?.toString() ??
          json['code']?.toString() ??
          json['short_name']?.toString(),
      logo: json['logo']?.toString() ??
          json['flagUrl']?.toString() ??
          json['image']?.toString() ??
          json['flag']?.toString(),
      score: json['score']?.toString(),
      overs: json['overs']?.toString(),
      wickets: parsedWickets,
      runs: parsedRuns,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (shortName != null) 'shortName': shortName,
      if (logo != null) 'logo': logo,
      if (score != null) 'score': score,
      if (overs != null) 'overs': overs,
      if (wickets != null) 'wickets': wickets,
      if (runs != null) 'runs': runs,
    };
  }

  String get displayName => (shortName != null && shortName!.isNotEmpty)
      ? shortName!
      : (name.isNotEmpty ? name : 'TBD');
}

/// Null-safe model representing a live cricket match.
@immutable
class LiveMatchModel {
  final String id;
  final String title;
  final String? series;
  final String? matchType;
  final String? venue;
  final String rawStatus;
  final String? statusNote;
  final TeamModel? team1;
  final TeamModel? team2;
  final String? streamUrl;
  final String? backupStreamUrl;
  final String? youtubeVideoId;
  final bool isPremium;
  final bool isFeatured;
  final int viewerCount;
  final String? banner;
  final String? poster;
  final DateTime? startTime;
  final DateTime? endTime;

  const LiveMatchModel({
    required this.id,
    required this.title,
    this.series,
    this.matchType,
    this.venue,
    required this.rawStatus,
    this.statusNote,
    this.team1,
    this.team2,
    this.streamUrl,
    this.backupStreamUrl,
    this.youtubeVideoId,
    this.isPremium = false,
    this.isFeatured = false,
    this.viewerCount = 0,
    this.banner,
    this.poster,
    this.startTime,
    this.endTime,
  });

  /// Case-insensitive match status resolution.
  LiveMatchStatus get matchStatus => LiveMatchStatus.fromString(rawStatus);

  bool get isLive => matchStatus == LiveMatchStatus.live;
  bool get isUpcoming => matchStatus == LiveMatchStatus.upcoming;
  bool get isCompleted => matchStatus == LiveMatchStatus.completed;

  bool get hasLiveStream => streamUrl != null && streamUrl!.trim().isNotEmpty;
  bool get hasBackupStream =>
      backupStreamUrl != null && backupStreamUrl!.trim().isNotEmpty;

  /// Display title fallback when title is generic or empty.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (team1 != null && team2 != null) {
      return '${team1!.displayName} vs ${team2!.displayName}';
    }
    return series ?? 'Cricket Match';
  }

  /// Score summary string for headers and banners.
  String get scoreSummary {
    if (statusNote != null && statusNote!.trim().isNotEmpty) {
      return statusNote!.trim();
    }
    final t1Score = team1?.score;
    final t2Score = team2?.score;
    if (t1Score != null && t2Score != null) {
      return '${team1?.displayName}: $t1Score | ${team2?.displayName}: $t2Score';
    }
    if (t1Score != null) {
      return '${team1?.displayName}: $t1Score';
    }
    if (t2Score != null) {
      return '${team2?.displayName}: $t2Score';
    }
    return isUpcoming ? 'Match not started' : 'Score unavailable';
  }

  factory LiveMatchModel.fromJson(Map<String, dynamic> json) {
    // Parse ID
    final id = (json['id'] ?? json['_id'] ?? json['matchId'] ?? '').toString();

    // Parse Title
    final title = (json['title'] ??
            json['matchTitle'] ??
            json['name'] ??
            json['seriesName'] ??
            '')
        .toString();

    // Parse Status case-insensitively, default to UPCOMING if omitted
    final rawStatus =
        (json['status'] ?? json['matchStatus'] ?? 'UPCOMING').toString().trim();

    // Parse Teams (supporting team1, teamA, team2, teamB)
    TeamModel? parsedTeam1;
    if (json['team1'] != null) {
      parsedTeam1 = TeamModel.fromDynamic(json['team1']);
    } else if (json['teamA'] != null) {
      parsedTeam1 = TeamModel.fromDynamic(json['teamA']);
    } else if (json['teams'] is List && (json['teams'] as List).isNotEmpty) {
      parsedTeam1 = TeamModel.fromDynamic((json['teams'] as List)[0]);
    }

    TeamModel? parsedTeam2;
    if (json['team2'] != null) {
      parsedTeam2 = TeamModel.fromDynamic(json['team2']);
    } else if (json['teamB'] != null) {
      parsedTeam2 = TeamModel.fromDynamic(json['teamB']);
    } else if (json['teams'] is List && (json['teams'] as List).length > 1) {
      parsedTeam2 = TeamModel.fromDynamic((json['teams'] as List)[1]);
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

    // Parse Viewer count safely (viewersCount, viewerCount, viewers, views)
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

    // Parse DateTimes safely
    DateTime? parsedStartTime;
    if (json['startTime'] != null) {
      parsedStartTime = DateTime.tryParse(json['startTime'].toString());
    } else if (json['scheduledAt'] != null) {
      parsedStartTime = DateTime.tryParse(json['scheduledAt'].toString());
    } else if (json['matchDate'] != null) {
      parsedStartTime = DateTime.tryParse(json['matchDate'].toString());
    }

    DateTime? parsedEndTime;
    if (json['endTime'] != null) {
      parsedEndTime = DateTime.tryParse(json['endTime'].toString());
    }

    final banner = (json['banner'] ??
            json['streamThumbnailUrl'] ??
            json['bannerUrl'] ??
            json['coverImage'])
        ?.toString();

    final series = (json['series'] ?? json['tournament'] ?? json['seriesName'])?.toString();
    final matchType = (json['matchType'] ?? json['format'] ?? json['matchFormat'] ?? json['type'])?.toString();
    final venue = (json['venue'] ?? json['stadium'] ?? json['location'])?.toString();

    return LiveMatchModel(
      id: id,
      title: title,
      series: series,
      matchType: matchType,
      venue: venue,
      rawStatus: rawStatus,
      statusNote: (json['statusNote'] ??
              json['matchStatusText'] ??
              json['statusMessage'] ??
              json['currentStatusText'] ??
              json['note'])
          ?.toString(),
      team1: parsedTeam1,
      team2: parsedTeam2,
      streamUrl: (streamUrl != null && streamUrl.isNotEmpty) ? streamUrl : null,
      backupStreamUrl: (backupStreamUrl != null && backupStreamUrl.isNotEmpty)
          ? backupStreamUrl
          : null,
      youtubeVideoId: (youtubeVideoId != null && youtubeVideoId.isNotEmpty) ? youtubeVideoId : null,
      isPremium: isPremium,
      isFeatured: isFeatured,
      viewerCount: viewers,
      banner: banner,
      poster: json['poster']?.toString() ?? banner,
      startTime: parsedStartTime,
      endTime: parsedEndTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (series != null) 'series': series,
      if (matchType != null) 'matchType': matchType,
      if (venue != null) 'venue': venue,
      'status': rawStatus,
      if (statusNote != null) 'statusNote': statusNote,
      if (team1 != null) 'team1': team1!.toJson(),
      if (team2 != null) 'team2': team2!.toJson(),
      if (streamUrl != null) 'streamUrl': streamUrl,
      if (backupStreamUrl != null) 'backupStreamUrl': backupStreamUrl,
      if (youtubeVideoId != null) 'youtubeVideoId': youtubeVideoId,
      'isPremium': isPremium,
      'isFeatured': isFeatured,
      'viewerCount': viewerCount,
      if (banner != null) 'banner': banner,
      if (poster != null) 'poster': poster,
      if (startTime != null) 'startTime': startTime!.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
    };
  }

  LiveMatchModel copyWith({
    String? id,
    String? title,
    String? series,
    String? matchType,
    String? venue,
    String? rawStatus,
    String? statusNote,
    TeamModel? team1,
    TeamModel? team2,
    String? streamUrl,
    String? backupStreamUrl,
    String? youtubeVideoId,
    bool? isPremium,
    bool? isFeatured,
    int? viewerCount,
    String? banner,
    String? poster,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return LiveMatchModel(
      id: id ?? this.id,
      title: title ?? this.title,
      series: series ?? this.series,
      matchType: matchType ?? this.matchType,
      venue: venue ?? this.venue,
      rawStatus: rawStatus ?? this.rawStatus,
      statusNote: statusNote ?? this.statusNote,
      team1: team1 ?? this.team1,
      team2: team2 ?? this.team2,
      streamUrl: streamUrl ?? this.streamUrl,
      backupStreamUrl: backupStreamUrl ?? this.backupStreamUrl,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      isPremium: isPremium ?? this.isPremium,
      isFeatured: isFeatured ?? this.isFeatured,
      viewerCount: viewerCount ?? this.viewerCount,
      banner: banner ?? this.banner,
      poster: poster ?? this.poster,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
