import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/res/appUrl.dart';

class ReelModel {
  String? id;
  ReelUser? user;
  String? videoUrl;
  String? thumbnail;
  String? caption;
  List<String>? hashtags;
  int? viewsCount;
  int? commentsCount;
  int? sharesCount;
  int? likesCount;
  String? userInteraction; // 'LIKE', 'DISLIKE' or null
  bool? isBookmarked;
  String? status;
  String? createdAt;

  // Ad fields
  bool? isAd;
  bool? isSponsored;
  String? adId;
  String? campaignId;
  String? advertiserId;
  String? advertiserName;
  String? advertiserLogo;
  String? adType;
  String? ctaText;
  String? destinationUrl;
  int? durationSeconds;

  bool get isSponsoredAd => isAd == true || isSponsored == true;

  ReelModel({
    this.id,
    this.user,
    this.videoUrl,
    this.thumbnail,
    this.caption,
    this.hashtags,
    this.viewsCount,
    this.commentsCount,
    this.sharesCount,
    this.likesCount,
    this.userInteraction,
    this.isBookmarked,
    this.status,
    this.createdAt,
    this.isAd,
    this.isSponsored,
    this.adId,
    this.campaignId,
    this.advertiserId,
    this.advertiserName,
    this.advertiserLogo,
    this.adType,
    this.ctaText,
    this.destinationUrl,
    this.durationSeconds,
  });

  factory ReelModel.fromContent(Content content) {
    return ReelModel(
      id: content.id,
      videoUrl: content.videoUrl,
      thumbnail: content.poster,
      caption: content.title,
      likesCount: content.likes?.length ?? 0,
      isBookmarked: false, // content doesn't have this field directly
      status: 'published',
    );
  }

  static const List<String> _videoExtensions = <String>[
    '.mp4',
    '.m3u8',
    '.mov',
    '.m4v',
    '.webm',
    '.mkv',
    '.avi',
    '.ts',
    '.mpd',
    '.3gp',
    '.flv',
    '.wmv',
  ];

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  static String? _nonEmptyString(dynamic value) {
    if (value == null || value is Map || value is Iterable) return null;
    final String str = value.toString().trim();
    if (str.isEmpty) return null;
    final String lower = str.toLowerCase();
    if (lower == 'null' || lower == 'undefined' || lower == 'nan') {
      return null;
    }
    return str;
  }

  /// Normalizes a relative or localhost media URL against [AppUrl.serverUrl].
  static String normalizeMediaUrl(String? url) {
    final String? cleaned = _nonEmptyString(url);
    if (cleaned == null) return '';
    if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
      final String normalized = cleaned.replaceAll('http://localhost:5000', AppUrl.serverUrl);
      if (normalized.startsWith('http://api.catchandwatch.com') ||
          normalized.startsWith('http://catchandwatch.com')) {
        return normalized.replaceFirst('http://', 'https://');
      }
      return normalized;
    }
    final String cleanPath = cleaned.replaceFirst(RegExp(r'^/+'), '');
    if (cleanPath.isEmpty) return '';
    final String cleanServer = AppUrl.serverUrl.replaceAll(RegExp(r'/+$'), '');
    return '$cleanServer/$cleanPath';
  }

  /// Returns `true` if [url] has a video/stream file extension (`.mp4`, `.m3u8`, etc.)
  /// or targets a streaming endpoint path.
  static bool isVideoStreamUrl(String? url) {
    final String? cleaned = _nonEmptyString(url);
    if (cleaned == null) return false;
    final Uri? uri = Uri.tryParse(cleaned);
    final String path = (uri != null && uri.path.isNotEmpty)
        ? uri.path.toLowerCase()
        : cleaned.split('?').first.split('#').first.toLowerCase();
    for (final String ext in _videoExtensions) {
      if (path.endsWith(ext)) {
        return true;
      }
    }
    if (path.contains('/reels/stream/') || path.contains('/video/stream/')) {
      return true;
    }
    return false;
  }

  /// Returns `true` only if [url] is a valid HTTP(S) image URL and is NOT
  /// a video stream (`.mp4`, `.m3u8`, etc.), bare server URL, [videoUrl], or [destinationUrl].
  static bool isValidThumbnailUrl(
    String? url, {
    String? videoUrl,
    String? destinationUrl,
  }) {
    final String? cleaned = _nonEmptyString(url);
    if (cleaned == null) return false;

    final Uri? uri = Uri.tryParse(cleaned);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    final String scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    if (uri.host.trim().isEmpty) return false;

    final String normalizedServer = AppUrl.serverUrl.replaceAll(RegExp(r'/+$'), '');
    final String normalizedUrl = cleaned.replaceAll(RegExp(r'/+$'), '');
    if (normalizedUrl.isEmpty || normalizedUrl == normalizedServer) {
      return false;
    }

    final String path = uri.path.trim().toLowerCase();
    if (path.isEmpty ||
        path == '/' ||
        path.endsWith('/null') ||
        path.endsWith('/undefined')) {
      return false;
    }

    if (isVideoStreamUrl(cleaned)) {
      return false;
    }

    final String? cleanVideo =
        _nonEmptyString(videoUrl)?.replaceAll(RegExp(r'/+$'), '');
    if (cleanVideo != null && normalizedUrl == cleanVideo) {
      return false;
    }

    final String? cleanDest =
        _nonEmptyString(destinationUrl)?.replaceAll(RegExp(r'/+$'), '');
    if (cleanDest != null && normalizedUrl == cleanDest) {
      return false;
    }

    return true;
  }

  ReelModel.fromJson(Map<String, dynamic> json) {
    id = _nonEmptyString(json['_id'] ?? json['id']);
    if (json['user'] != null) {
      if (json['user'] is Map) {
        user = ReelUser.fromJson(Map<String, dynamic>.from(json['user']));
      } else if (json['user'] is String) {
        user = ReelUser(id: _nonEmptyString(json['user']));
      }
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? (double.tryParse(value)?.toInt() ?? 0);
      }
      return 0;
    }

    // Ad & Sponsored metadata mapping (parsed early so destinationUrl/thumbnailUrl cannot be confused with videoUrl)
    final bool rawIsAd = _parseBool(json['isAd']);
    final bool rawIsSponsored = _parseBool(json['isSponsored']);
    final bool parsedIsAd = rawIsAd || rawIsSponsored;

    isAd = parsedIsAd;
    isSponsored = rawIsSponsored || rawIsAd;

    final dynamic rawCta = json['cta'];
    final Map<String, dynamic>? ctaMap =
        rawCta is Map ? Map<String, dynamic>.from(rawCta) : null;

    ctaText = _nonEmptyString(
      json['ctaText'] ??
          json['ctaLabel'] ??
          json['ctaButtonText'] ??
          (ctaMap != null ? (ctaMap['text'] ?? ctaMap['label']) : rawCta),
    );
    destinationUrl = _nonEmptyString(
      json['destinationUrl'] ??
          json['targetUrl'] ??
          json['clickUrl'] ??
          json['actionUrl'] ??
          (ctaMap != null
              ? (ctaMap['url'] ?? ctaMap['destinationUrl'])
              : null),
    );

    final dynamic rawVideoField = json['video'];
    final Map<String, dynamic>? videoMap =
        rawVideoField is Map ? Map<String, dynamic>.from(rawVideoField) : null;
    final dynamic rawMediaField = json['media'];
    final Map<String, dynamic>? mediaMap =
        rawMediaField is Map ? Map<String, dynamic>.from(rawMediaField) : null;
    final dynamic rawCreativeField = json['creative'];
    final Map<String, dynamic>? creativeMap = rawCreativeField is Map
        ? Map<String, dynamic>.from(rawCreativeField)
        : null;

    final String? explicitVideoCandidate = _nonEmptyString(
      json['videoUrl'] ??
          json['mediaUrl'] ??
          json['adVideoUrl'] ??
          json['streamUrl'] ??
          (videoMap != null
              ? (videoMap['videoUrl'] ??
                  videoMap['mediaUrl'] ??
                  videoMap['streamUrl'] ??
                  videoMap['url'])
              : rawVideoField) ??
          (mediaMap != null
              ? (mediaMap['videoUrl'] ??
                  mediaMap['mediaUrl'] ??
                  mediaMap['streamUrl'] ??
                  mediaMap['url'])
              : rawMediaField) ??
          (creativeMap != null
              ? (creativeMap['videoUrl'] ??
                  creativeMap['mediaUrl'] ??
                  creativeMap['streamUrl'] ??
                  creativeMap['url'])
              : null),
    );

    final String? fallbackUrlCandidate = _nonEmptyString(json['url']);
    final String? rawThumbnailField = _nonEmptyString(
      json['thumbnail'] ??
          json['thumbnailUrl'] ??
          json['poster'] ??
          json['posterUrl'] ??
          (videoMap != null
              ? (videoMap['thumbnail'] ?? videoMap['thumbnailUrl'] ?? videoMap['poster'])
              : null) ??
          (mediaMap != null
              ? (mediaMap['thumbnail'] ?? mediaMap['thumbnailUrl'] ?? mediaMap['poster'])
              : null) ??
          (creativeMap != null
              ? (creativeMap['thumbnail'] ??
                  creativeMap['thumbnailUrl'] ??
                  creativeMap['poster'])
              : null),
    );

    String? resolvedVideoRaw = explicitVideoCandidate;
    if (resolvedVideoRaw == null && fallbackUrlCandidate != null) {
      // Only use generic `url` if it is not the click destination or static thumbnail URL
      if (fallbackUrlCandidate != destinationUrl &&
          fallbackUrlCandidate != rawThumbnailField) {
        resolvedVideoRaw = fallbackUrlCandidate;
      }
    }

    videoUrl = normalizeMediaUrl(resolvedVideoRaw);

    final String candidateThumbnail = normalizeMediaUrl(rawThumbnailField);
    thumbnail = isValidThumbnailUrl(
      candidateThumbnail,
      videoUrl: videoUrl,
      destinationUrl: destinationUrl,
    )
        ? candidateThumbnail
        : null;

    caption = _nonEmptyString(
      json['caption'] ?? json['title'] ?? json['description'],
    );
    if (json['hashtags'] != null) {
      if (json['hashtags'] is List) {
        hashtags = (json['hashtags'] as List)
            .where((e) => e != null)
            .map((e) => e.toString())
            .toList();
      } else if (json['hashtags'] is String) {
        hashtags = (json['hashtags'] as String)
            .split(RegExp(r'\s+'))
            .where((h) => h.trim().isNotEmpty)
            .toList();
      } else {
        hashtags = [];
      }
    } else {
      hashtags = [];
    }
    viewsCount = parseInt(json['viewsCount']);
    commentsCount = parseInt(json['commentsCount']);
    sharesCount = parseInt(json['sharesCount']);
    likesCount = parseInt(json['likesCount']);
    userInteraction = json['userInteraction']?.toString();
    isBookmarked = _parseBool(json['isBookmarked']);
    status = json['status']?.toString();
    createdAt = json['createdAt']?.toString();

    adId = _nonEmptyString(json['adId'] ?? json['sponsoredAdId']) ??
        (parsedIsAd ? id : null);

    final dynamic rawCampaign = json['campaign'];
    campaignId = _nonEmptyString(
      json['campaignId'] ??
          (rawCampaign is Map
              ? (rawCampaign['_id'] ?? rawCampaign['id'])
              : rawCampaign),
    );

    final dynamic rawAdvertiser = json['advertiser'];
    final Map<String, dynamic>? advertiserMap = rawAdvertiser is Map
        ? Map<String, dynamic>.from(rawAdvertiser)
        : null;

    advertiserId = _nonEmptyString(
      json['advertiserId'] ??
          (advertiserMap != null
              ? (advertiserMap['_id'] ?? advertiserMap['id'])
              : (rawAdvertiser is String ? rawAdvertiser : null)),
    );

    advertiserName = _nonEmptyString(
      json['advertiserName'] ??
          json['sponsorName'] ??
          json['brandName'] ??
          (advertiserMap != null
              ? (advertiserMap['name'] ??
                  advertiserMap['brandName'] ??
                  advertiserMap['advertiserName'] ??
                  advertiserMap['username'])
              : null),
    );

    final String rawAdvertiserLogo = normalizeMediaUrl(
      _nonEmptyString(
        json['advertiserLogo'] ??
            json['sponsorLogo'] ??
            json['brandLogo'] ??
            (advertiserMap != null
                ? (advertiserMap['logo'] ??
                    advertiserMap['profileImage'] ??
                    advertiserMap['image'] ??
                    advertiserMap['avatar'])
                : null),
      ),
    );
    advertiserLogo = isValidThumbnailUrl(
      rawAdvertiserLogo,
      videoUrl: videoUrl,
      destinationUrl: destinationUrl,
    )
        ? rawAdvertiserLogo
        : null;

    if (user == null && advertiserMap != null) {
      user = ReelUser.fromJson(<String, dynamic>{
        ...advertiserMap,
        '_id': advertiserId ?? advertiserMap['_id'] ?? advertiserMap['id'],
        'name': advertiserName ?? advertiserMap['name'],
        'username': _nonEmptyString(advertiserMap['username']) ?? advertiserName,
        if (advertiserLogo != null) 'profileImage': advertiserLogo,
      });
    } else if (user == null &&
        parsedIsAd &&
        (advertiserName != null || advertiserLogo != null)) {
      user = ReelUser(
        id: advertiserId,
        name: advertiserName,
        username: advertiserName,
        profileImage: advertiserLogo,
      );
    }

    advertiserName ??= _nonEmptyString(user?.name ?? user?.username);
    if (advertiserLogo == null &&
        isValidThumbnailUrl(
          user?.profileImage,
          videoUrl: videoUrl,
          destinationUrl: destinationUrl,
        )) {
      advertiserLogo = user?.profileImage;
    }

    adType = _nonEmptyString(json['adType'] ?? json['mediaType']);
    durationSeconds = parseInt(json['durationSeconds']);

    // If it's an ad and we have an adId, ensure id is set to adId for consistency
    if (isAd == true && adId != null) {
      id = adId;
    }
  }
}

class ReelUser {
  String? id;
  String? name;
  String? profileImage;
  String? username;
  bool? isFollowing;
  bool? isVerified;
  bool? blueTick;
  bool? orangeTick;

  ReelUser({this.id, this.name, this.profileImage, this.username, this.isFollowing, this.isVerified, this.blueTick, this.orangeTick});

  ReelUser.fromJson(Map<dynamic, dynamic> json) {
    id = ReelModel._nonEmptyString(json['_id'] ?? json['id']);
    name = ReelModel._nonEmptyString(json['name']);

    final String candidateProfileImage = ReelModel.normalizeMediaUrl(
      ReelModel._nonEmptyString(
        json['profileImage'] ?? json['image'] ?? json['logo'] ?? json['avatar'],
      ),
    );
    profileImage = ReelModel.isValidThumbnailUrl(candidateProfileImage)
        ? candidateProfileImage
        : null;
    username = ReelModel._nonEmptyString(json['username']);
    isFollowing = json['isFollowing'] == true || json['isFollowing']?.toString().toLowerCase() == 'true';
    final dynamic ver = json['verification'];
    final bool verIsVerified = ver is Map
        ? (ver['isVerified'] == true || ver['isVerified']?.toString().toLowerCase() == 'true')
        : false;
    final String? verBadge = ver is Map ? ver['badgeType']?.toString().toUpperCase() : null;

    final bool rawOrange = json['orangeTick'] == true || json['orangeTick']?.toString().toLowerCase() == 'true';
    final bool rawBlue = json['blueTick'] == true || json['blueTick']?.toString().toLowerCase() == 'true';

    orangeTick = rawOrange || (verBadge == 'ORANGE' && verIsVerified);
    blueTick = rawBlue || (verBadge == 'BLUE' && verIsVerified);
    isVerified = verIsVerified || (blueTick == true) || (orangeTick == true);
  }

  /// Returns whether the creator has a verified tick (Orange Tick / Blue Tick)
  bool get hasVerifiedTick => (blueTick == true) || (orangeTick == true);
}
