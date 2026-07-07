import 'package:catch_watch/models/content_model.dart';

class WatchlistResponse {
  bool? success;
  int? count;
  List<WatchlistItem>? data;

  WatchlistResponse({this.success, this.count, this.data});

  WatchlistResponse.fromJson(Map<dynamic, dynamic> json) {
    success = json['success'];
    count = json['count'];
    if (json['data'] != null) {
      data = <WatchlistItem>[];
      json['data'].forEach((v) {
        if (v is Map) {
          data!.add(WatchlistItem.fromJson(v));
        }
      });
    }
  }
}

class WatchlistItem {
  String? id;
  String? user;
  Content? item;
  String? itemModel;

  WatchlistItem({this.id, this.user, this.item, this.itemModel});

  WatchlistItem.fromJson(Map<dynamic, dynamic> json) {
    id = json['_id'];
    user = json['user'];
    if (json['item'] != null && json['item'] is Map) {
      item = Content.fromJson(json['item']);
    }
    itemModel = json['itemModel'];
  }
}
