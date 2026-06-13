import 'package:catch_watch/models/content_model.dart';

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
  Content? item;
  String? itemModel;

  WatchlistItem({this.id, this.user, this.item, this.itemModel});

  WatchlistItem.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    user = json['user'];
    item = json['item'] != null ? Content.fromJson(json['item']) : null;
    itemModel = json['itemModel'];
  }
}
