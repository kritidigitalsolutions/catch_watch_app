import 'package:catch_watch/models/chat_model.dart';

class CallModel {
  String? sId;
  Sender? caller;
  Sender? receiver;
  String? type; // 'audio' or 'video'
  String? status; // 'ringing', 'accepted', 'rejected', 'busy', 'missed', 'ended', 'cancelled'
  String? agoraToken;
  String? channelName;
  int? agoraUid;
  int? duration;
  String? startedAt;
  String? endedAt;
  String? createdAt;
  String? updatedAt;

  CallModel({
    this.sId,
    this.caller,
    this.receiver,
    this.type,
    this.status,
    this.agoraToken,
    this.channelName,
    this.duration,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.updatedAt,
  });

  CallModel.fromJson(Map<String, dynamic> json) {
    sId = json['_id'] ?? json['id'] ?? json['callId'];
    
    if (json['caller'] != null) {
      if (json['caller'] is Map) {
        caller = Sender.fromJson(json['caller']);
      } else {
        caller = Sender(sId: json['caller'].toString(), id: json['caller'].toString());
      }
    }

    if (json['receiver'] != null) {
      if (json['receiver'] is Map) {
        receiver = Sender.fromJson(json['receiver']);
      } else {
        receiver = Sender(sId: json['receiver'].toString(), id: json['receiver'].toString());
      }
    }

    type = json['type'];
    status = json['status'];
    agoraToken = json['agoraToken'];
    channelName = json['channelName'];
    agoraUid = json['agoraUid'];
    duration = json['duration'];
    startedAt = json['startedAt'];
    endedAt = json['endedAt'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = sId;
    if (caller != null) data['caller'] = caller!.id;
    if (receiver != null) data['receiver'] = receiver!.id;
    data['type'] = type;
    data['status'] = status;
    data['agoraToken'] = agoraToken;
    data['channelName'] = channelName;
    data['duration'] = duration;
    data['startedAt'] = startedAt;
    data['endedAt'] = endedAt;
    return data;
  }
}
