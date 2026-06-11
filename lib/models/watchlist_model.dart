class WatchlistResponse {
  bool? success;
  int? count;
  List<WatchlistItem>? data;

  WatchlistResponse({this.success, this.count, this.data});

  WatchlistResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    count = json['count'];
    if (json['data'] != null) {
      data = <WatchlistItem>[];
      json['data'].forEach((v) {
        data!.add(WatchlistItem.fromJson(v));
      });
    }
  }
}

class WatchlistItem {
  String? id;
  String? user;
  Item? item;
  String? itemModel;

  WatchlistItem({this.id, this.user, this.item, this.itemModel});

  WatchlistItem.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    user = json['user'];
    item = json['item'] != null ? Item.fromJson(json['item']) : null;
    itemModel = json['itemModel'];
  }
}

class Item {
  String? id;
  String? title;
  String? description;
  List<String>? genre;
  int? releaseYear;
  String? duration;
  String? language;
  String? poster;
  String? banner;
  String? videoUrl;
  double? rating;

  Item({
    this.id,
    this.title,
    this.description,
    this.genre,
    this.releaseYear,
    this.duration,
    this.language,
    this.poster,
    this.banner,
    this.videoUrl,
    this.rating,
  });

  Item.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    title = json['title'];
    description = json['description'];
    genre = json['genre'] != null ? List<String>.from(json['genre']) : null;
    releaseYear = json['releaseYear'];
    duration = json['duration'];
    language = json['language'];
    poster = json['poster'];
    banner = json['banner'];
    videoUrl = json['videoUrl'];
    rating = (json['rating'] as num?)?.toDouble();
  }
}
