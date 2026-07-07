import 'package:catch_watch/res/appUrl.dart';

class ContentModel {
  bool? success;
  int? moviesCount;
  int? seriesCount;
  int? episodesCount;
  List<Content>? content;

  ContentModel({
    this.success,
    this.moviesCount,
    this.seriesCount,
    this.episodesCount,
    this.content,
  });

  ContentModel.fromJson(Map<dynamic, dynamic> json) {
    success = json['success'];
    moviesCount = json['moviesCount'];
    seriesCount = json['seriesCount'];
    episodesCount = json['episodesCount'];
    if (json['content'] != null) {
      content = <Content>[];
      json['content'].forEach((v) {
        if (v is Map) {
          content!.add(Content.fromJson(Map<String, dynamic>.from(v)));
        }
      });
    }
  }
}

class Content {
  String? id;
  String? title;
  String? description;
  List<String>? genre;
  int? releaseYear;
  String? duration;
  String? language;
  String? poster;
  String? banner;
  bool? isComingSoon;
  String? releaseDate;
  int? priority;
  String? videoUrl;
  String? trailerUrl;
  bool? isPremium;
  double? rating;
  List<String>? cast;
  List<String>? category;
  List<String>? likes;
  List<String>? dislikes;
  String? createdAt;
  String? updatedAt;
  String? slug;
  String? type;
  bool? isTrending;
  int? totalEpisodes;
  int? totalViews;
  String? status;
  int? episodeNumber;
  String? tvShowId;
  String? thumbnail;
  bool? isLocked;
  bool? isVertical;
  int? views;
  List<AudioTrack>? audioTracks;

  Content({
    this.id,
    this.title,
    this.description,
    this.genre,
    this.releaseYear,
    this.duration,
    this.language,
    this.poster,
    this.banner,
    this.isComingSoon,
    this.releaseDate,
    this.priority,
    this.videoUrl,
    this.trailerUrl,
    this.isPremium,
    this.rating,
    this.cast,
    this.category,
    this.likes,
    this.dislikes,
    this.createdAt,
    this.updatedAt,
    this.slug,
    this.type,
    this.isTrending,
    this.totalEpisodes,
    this.totalViews,
    this.status,
    this.episodeNumber,
    this.tvShowId,
    this.thumbnail,
    this.isLocked,
    this.isVertical,
    this.views,
    this.audioTracks,
  });

  Content.fromJson(Map<dynamic, dynamic> json) {
    id = json['_id'];
    title = json['title'];
    description = json['description'];
    genre = json['genre'] != null ? List<String>.from(json['genre']) : null;
    releaseYear = json['releaseYear'];
    duration = json['duration'];
    language = json['language'];
    
    // Fix localhost in URLs if necessary
    String fixUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('http')) {
        return url.replaceAll('http://localhost:5000', AppUrl.serverUrl);
      }
      return '${AppUrl.serverUrl}/$url';
    }
    
    poster = fixUrl(json['poster']);
    banner = fixUrl(json['banner']);
    videoUrl = fixUrl(json['videoUrl']);
    trailerUrl = fixUrl(json['trailerUrl']);
    thumbnail = fixUrl(json['thumbnail']);

    isComingSoon = json['isComingSoon'];
    releaseDate = json['releaseDate'];
    priority = json['priority'];
    isPremium = json['isPremium'];
    rating = (json['rating'] as num?)?.toDouble();
    cast = json['cast'] != null 
        ? (json['cast'] is List && json['cast'].isNotEmpty && json['cast'][0] is Map)
            ? List<String>.from(json['cast'].map((e) => e['name']?.toString() ?? ''))
            : List<String>.from(json['cast'])
        : null;
    category = json['category'] != null ? List<String>.from(json['category']) : null;
    likes = json['likes'] != null ? List<String>.from(json['likes']) : null;
    dislikes = json['dislikes'] != null ? List<String>.from(json['dislikes']) : null;
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    slug = json['slug'];
    type = json['type'];
    isTrending = json['isTrending'];
    totalEpisodes = json['totalEpisodes'];
    totalViews = json['totalViews'];
    status = json['status'];
    episodeNumber = json['episodeNumber'];
    tvShowId = json['tvShowId'];
    isLocked = json['isLocked'];
    isVertical = json['isVertical'];
    views = json['views'];

    if (json['audioTracks'] != null) {
      audioTracks = <AudioTrack>[];
      json['audioTracks'].forEach((v) {
        if (v is Map) {
          audioTracks!.add(AudioTrack.fromJson(Map<String, dynamic>.from(v), fixUrl));
        }
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = id;
    data['title'] = title;
    data['description'] = description;
    data['genre'] = genre;
    data['releaseYear'] = releaseYear;
    data['duration'] = duration;
    data['language'] = language;
    data['poster'] = poster;
    data['banner'] = banner;
    data['isComingSoon'] = isComingSoon;
    data['releaseDate'] = releaseDate;
    data['priority'] = priority;
    data['videoUrl'] = videoUrl;
    data['trailerUrl'] = trailerUrl;
    data['isPremium'] = isPremium;
    data['rating'] = rating;
    data['cast'] = cast;
    data['category'] = category;
    data['likes'] = likes;
    data['dislikes'] = dislikes;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['slug'] = slug;
    data['type'] = type;
    data['isTrending'] = isTrending;
    data['totalEpisodes'] = totalEpisodes;
    data['totalViews'] = totalViews;
    data['status'] = status;
    data['episodeNumber'] = episodeNumber;
    data['tvShowId'] = tvShowId;
    data['thumbnail'] = thumbnail;
    data['isLocked'] = isLocked;
    data['isVertical'] = isVertical;
    data['views'] = views;
    if (audioTracks != null) {
      data['audioTracks'] = audioTracks!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class AudioTrack {
  String? language;
  String? fileUrl;
  bool? isDefault;
  String? id;

  AudioTrack({this.language, this.fileUrl, this.isDefault, this.id});

  AudioTrack.fromJson(Map<dynamic, dynamic> json, String Function(String?) fixUrl) {
    language = json['language'];
    fileUrl = fixUrl(json['fileUrl']);
    isDefault = json['isDefault'];
    id = json['_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['language'] = language;
    data['fileUrl'] = fileUrl;
    data['isDefault'] = isDefault;
    data['_id'] = id;
    return data;
  }
}

