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

  ContentModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    moviesCount = json['moviesCount'];
    seriesCount = json['seriesCount'];
    episodesCount = json['episodesCount'];
    if (json['content'] != null) {
      content = <Content>[];
      json['content'].forEach((v) {
        content!.add(Content.fromJson(v));
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
  });

  Content.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    title = json['title'];
    description = json['description'];
    genre = json['genre'] != null ? List<String>.from(json['genre']) : null;
    releaseYear = json['releaseYear'];
    duration = json['duration'];
    language = json['language'];
    
    // Fix localhost in URLs if necessary
    String fixUrl(String? url) {
      if (url == null) return '';
      return url.replaceAll('http://localhost:5000', 'http://192.168.1.16:5000');
    }
    
    poster = fixUrl(json['poster']);
    banner = fixUrl(json['banner']);
    videoUrl = fixUrl(json['videoUrl']);
    trailerUrl = fixUrl(json['trailerUrl']);

    isComingSoon = json['isComingSoon'];
    releaseDate = json['releaseDate'];
    priority = json['priority'];
    videoUrl = json['videoUrl'];
    trailerUrl = json['trailerUrl'];
    isPremium = json['isPremium'];
    rating = (json['rating'] as num?)?.toDouble();
    cast = json['cast'] != null ? List<String>.from(json['cast']) : null;
    category = json['category'] != null ? List<String>.from(json['category']) : null;
    likes = json['likes'] != null ? List<String>.from(json['likes']) : null;
    dislikes = json['dislikes'] != null ? List<String>.from(json['dislikes']) : null;
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    slug = json['slug'];
    type = json['type'];
    isTrending = json['isTrending'];
  }
}
