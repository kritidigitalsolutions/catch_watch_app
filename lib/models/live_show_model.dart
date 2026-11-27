class LiveShowsResponse {
  bool? success;
  int? totalCount;
  int? liveCount;
  int? upcomingCount;
  int? completedCount;
  List<LiveShow>? shows;

  LiveShowsResponse({
    this.success,
    this.totalCount,
    this.liveCount,
    this.upcomingCount,
    this.completedCount,
    this.shows,
  });

  LiveShowsResponse.fromJson(dynamic json) {
    if (json is List) {
      success = true;
      shows = json.map((v) => LiveShow.fromJson(Map<String, dynamic>.from(v))).toList();
      totalCount = shows?.length ?? 0;
      return;
    }
    if (json is Map<String, dynamic>) {
      success = json['success'] ?? true;

      final data = json['data'] ?? json;

      if (data is List) {
        shows = data.map((v) => LiveShow.fromJson(Map<String, dynamic>.from(v))).toList();
        totalCount = shows?.length ?? 0;
        return;
      }

      if (data is Map<String, dynamic>) {
        totalCount = data['totalCount'] ?? data['count'] ?? json['totalCount'];

        final stats = data['stats'] ?? json['stats'];
        if (stats is Map) {
          liveCount = stats['live'];
          upcomingCount = stats['upcoming'];
          completedCount = stats['completed'];
          totalCount = stats['total'] ?? totalCount;
        }
        liveCount ??= data['liveCount'] ?? json['liveCount'];
        upcomingCount ??= data['upcomingCount'] ?? json['upcomingCount'];
        completedCount ??= data['completedCount'] ?? json['completedCount'];

        final listKey = data['shows'] ?? data['liveShows'] ?? data['matches'] ?? data['items'] ?? json['shows'] ?? json['liveShows'];
        if (listKey is List) {
          shows = listKey.map((v) => LiveShow.fromJson(Map<String, dynamic>.from(v))).toList();
        } else if (data['_id'] != null || data['title'] != null) {
          shows = [LiveShow.fromJson(Map<String, dynamic>.from(data))];
        } else if (json['show'] != null) {
          shows = [LiveShow.fromJson(Map<String, dynamic>.from(json['show']))];
        } else {
          shows = [];
        }
      } else {
        shows = [];
      }
    } else {
      shows = [];
    }
  }
}

class LiveShow {
  String? id;
  String? title;
  String? description;
  String? category;
  String? status; // 'LIVE', 'UPCOMING', 'ENDED'
  bool? isLive;
  String? banner;
  String? thumbnail;
  String? streamUrl;
  String? streamType; // 'youtube', 'hls', 'mp4'
  String? resolvedStreamType;
  String? youtubeVideoId;
  int? viewerCount;
  String? scheduledStartTime;
  String? scheduledEndTime;
  bool? isFeatured;
  bool? isPremium;
  HostInfo? host;
  List<LiveShowComment>? chatMessages;

  LiveShow({
    this.id,
    this.title,
    this.description,
    this.category,
    this.status,
    this.isLive,
    this.banner,
    this.thumbnail,
    this.streamUrl,
    this.streamType,
    this.resolvedStreamType,
    this.youtubeVideoId,
    this.viewerCount,
    this.scheduledStartTime,
    this.scheduledEndTime,
    this.isFeatured,
    this.isPremium,
    this.host,
    this.chatMessages,
  });

  LiveShow.fromJson(Map<String, dynamic> json) {
    id = json['_id'] ?? json['showId'] ?? json['id'];
    title = json['title'] ?? json['name'];
    description = json['description'] ?? json['subtitle'];
    category = json['category'] ?? 'Live Show';
    status = json['status'] ?? 'LIVE';
    isLive = json['isLive'] ?? (status == 'LIVE' || status == 'live');
    thumbnail = json['thumbnail'] ?? json['banner'] ?? json['streamThumbnailUrl'] ?? json['streamThumbnail'] ?? json['bannerUrl'];
    banner = json['banner'] ?? json['thumbnail'] ?? json['streamThumbnailUrl'] ?? json['streamThumbnail'] ?? json['bannerUrl'];
    streamUrl = json['streamUrl'] ?? json['url'] ?? json['playbackUrl'];
    streamType = json['streamType'] ?? 'youtube';
    resolvedStreamType = json['resolvedStreamType'] ?? streamType;
    youtubeVideoId = json['youtubeVideoId'];
    if ((youtubeVideoId == null || youtubeVideoId!.isEmpty) && streamUrl != null) {
      if (streamUrl!.contains('youtube.com/embed/') || streamUrl!.contains('youtu.be/') || streamUrl!.contains('youtube.com/watch')) {
        final uri = Uri.tryParse(streamUrl!);
        if (uri != null) {
          if (uri.pathSegments.contains('embed')) {
            final idx = uri.pathSegments.indexOf('embed');
            if (idx + 1 < uri.pathSegments.length) {
              youtubeVideoId = uri.pathSegments[idx + 1].split('?').first;
            }
          } else if (uri.host.contains('youtu.be')) {
            if (uri.pathSegments.isNotEmpty) {
              youtubeVideoId = uri.pathSegments.first.split('?').first;
            }
          } else if (uri.queryParameters.containsKey('v')) {
            youtubeVideoId = uri.queryParameters['v'];
          }
        }
      }
    }
    viewerCount = json['viewersCount'] ?? json['viewerCount'] ?? json['viewers'] ?? 5;
    scheduledStartTime = json['scheduledStartTime'] ?? json['startTime'];
    scheduledEndTime = json['scheduledEndTime'] ?? json['endTime'];
    isFeatured = json['isFeatured'] ?? false;
    isPremium = json['isPremium'] ?? false;

    final h = json['host'] ?? json['creator'] ?? json['user'];
    host = h != null ? HostInfo.fromJson(Map<String, dynamic>.from(h)) : null;

    final msgList = json['chat'] ?? json['messages'] ?? json['chatMessages'] ?? json['commentary'];
    if (msgList != null && msgList is List) {
      chatMessages = <LiveShowComment>[];
      for (var v in msgList) {
        chatMessages!.add(LiveShowComment.fromJson(Map<String, dynamic>.from(v)));
      }
    }
  }
}

class HostInfo {
  String? id;
  String? name;
  String? username;
  String? avatar;
  bool? isVerified;

  HostInfo({this.id, this.name, this.username, this.avatar, this.isVerified});

  HostInfo.fromJson(Map<String, dynamic> json) {
    id = json['_id'] ?? json['id'];
    name = json['name'] ?? json['username'] ?? 'CatchWatch Host';
    username = json['username'] ?? json['name'] ?? 'catchwatch';
    avatar = json['avatar'] ?? json['profilePic'] ?? json['image'];
    isVerified = json['isVerified'] ?? json['verified'] ?? true;
  }
}

class LiveShowComment {
  String? id;
  String? username;
  String? userAvatar;
  String? message;
  String? timestamp;

  LiveShowComment({this.id, this.username, this.userAvatar, this.message, this.timestamp});

  LiveShowComment.fromJson(Map<String, dynamic> json) {
    id = json['_id'] ?? json['id'];
    username = json['username'] ?? json['senderName'] ?? 'Viewer';
    userAvatar = json['userAvatar'] ?? json['avatar'];
    message = json['message'] ?? json['text'] ?? json['comment'];
    timestamp = json['timestamp'] ?? json['time'];
  }
}
