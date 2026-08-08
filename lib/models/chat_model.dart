import 'package:catch_watch/res/appUrl.dart';

class ConversationResponse {
  bool? success;
  List<ConversationModel>? data;

  ConversationResponse({this.success, this.data});

  ConversationResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['data'] != null) {
      data = <ConversationModel>[];
      json['data'].forEach((v) {
        data!.add(ConversationModel.fromJson(v));
      });
    }
  }
}

class ConversationModel {
  String? sId;
  PartnerModel? partner;
  MessageModel? lastMessage;
  String? lastMessageAt;
  int? unreadCount;
  bool? isPinned;
  String? createdAt;
  String? updatedAt;

  ConversationModel({
    this.sId,
    this.partner,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount,
    this.isPinned,
    this.createdAt,
    this.updatedAt,
  });

  ConversationModel.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    partner = json['partner'] != null ? PartnerModel.fromJson(json['partner']) : null;
    lastMessage = json['lastMessage'] != null ? MessageModel.fromJson(json['lastMessage']) : null;
    lastMessageAt = json['lastMessageAt'];
    unreadCount = json['unreadCount'];
    isPinned = json['isPinned'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
  }
}

class PartnerModel {
  Verification? verification;
  String? sId;
  String? phone;
  String? name;
  String? profileImage;
  String? bio;
  String? role;
  String? username;
  bool? isOnline;
  String? lastSeen;
  String? id;

  PartnerModel({
    this.verification,
    this.sId,
    this.phone,
    this.name,
    this.profileImage,
    this.bio,
    this.role,
    this.username,
    this.isOnline,
    this.lastSeen,
    this.id,
  });

  PartnerModel.fromJson(Map<String, dynamic> json) {
    verification = json['verification'] != null ? Verification.fromJson(json['verification']) : null;
    sId = json['_id'];
    phone = json['phone'];
    name = json['name'];
    
    String fixUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('http')) {
        return url.replaceAll('http://localhost:5000', AppUrl.serverUrl);
      }
      return '${AppUrl.serverUrl}/$url';
    }

    profileImage = fixUrl(json['profileImage']);
    bio = json['bio'];
    role = json['role'];
    username = json['username'];
    isOnline = json['isOnline'];
    lastSeen = json['lastSeen'];
    id = json['id'];
  }
}

class Verification {
  String? status;
  String? verifiedAt;
  bool? isVerified;
  String? badgeType;

  Verification({this.status, this.verifiedAt, this.isVerified, this.badgeType});

  Verification.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    verifiedAt = json['verifiedAt'];
    isVerified = json['isVerified'];
    badgeType = json['badgeType'];
  }
}

class MessageModel {
  MediaMeta? mediaMeta;
  String? sId;
  String? conversationId;
  Sender? sender;
  dynamic recipient; // Can be Sender object or String ID
  String? messageType;
  String? text;
  String? mediaUrl;
  String? replyTo;
  bool? isForwarded;
  String? status;
  String? deliveredAt;
  bool? isEdited;
  bool? isUnsent;
  List<String>? deletedFor;
  List<dynamic>? reactions;
  String? createdAt;
  String? updatedAt;
  int? iV;
  String? readAt;

  MessageModel({
    this.mediaMeta,
    this.sId,
    this.conversationId,
    this.sender,
    this.recipient,
    this.messageType,
    this.text,
    this.mediaUrl,
    this.replyTo,
    this.isForwarded,
    this.status,
    this.deliveredAt,
    this.isEdited,
    this.isUnsent,
    this.deletedFor,
    this.reactions,
    this.createdAt,
    this.updatedAt,
    this.iV,
    this.readAt,
  });

  MessageModel.fromJson(Map<String, dynamic> json) {
    mediaMeta = json['mediaMeta'] != null ? MediaMeta.fromJson(json['mediaMeta']) : null;
    sId = json['_id'];
    
    if (json['conversationId'] != null) {
      if (json['conversationId'] is Map) {
        conversationId = json['conversationId']['_id'] ?? json['conversationId']['id'];
      } else {
        conversationId = json['conversationId'].toString();
      }
    }
    
    sender = json['sender'] != null ? Sender.fromJson(json['sender']) : null;
    
    if (json['recipient'] != null) {
      if (json['recipient'] is Map) {
        recipient = Sender.fromJson(json['recipient']);
      } else {
        recipient = json['recipient'];
      }
    }
    
    messageType = json['messageType'];
    text = json['text'];
    mediaUrl = json['mediaUrl'];
    replyTo = json['replyTo'];
    isForwarded = json['isForwarded'];
    status = json['status'];
    deliveredAt = json['deliveredAt'];
    isEdited = json['isEdited'];
    isUnsent = json['isUnsent'];
    deletedFor = json['deletedFor']?.cast<String>();
    reactions = json['reactions'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    iV = json['__v'];
    readAt = json['readAt'];
  }
}

class MediaMeta {
  String? fileName;
  int? fileSize;
  int? duration;
  String? mimeType;

  MediaMeta({this.fileName, this.fileSize, this.duration, this.mimeType});

  MediaMeta.fromJson(Map<String, dynamic> json) {
    fileName = json['fileName'];
    fileSize = json['fileSize'];
    duration = json['duration'];
    mimeType = json['mimeType'];
  }
}

class Sender {
  String? sId;
  String? name;
  String? profileImage;
  String? username;
  String? id;

  Sender({this.sId, this.name, this.profileImage, this.username, this.id});

  Sender.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    name = json['name'];
    
    String fixUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('http')) {
        return url.replaceAll('http://localhost:5000', AppUrl.serverUrl);
      }
      return '${AppUrl.serverUrl}/$url';
    }

    profileImage = fixUrl(json['profileImage']);
    username = json['username'];
    id = json['id'];
  }
}

class MessageResponse {
  bool? success;
  List<MessageModel>? data;
  PaginationModel? pagination;

  MessageResponse({this.success, this.data, this.pagination});

  MessageResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['data'] != null) {
      data = <MessageModel>[];
      json['data'].forEach((v) {
        data!.add(MessageModel.fromJson(v));
      });
    }
    pagination = json['pagination'] != null ? PaginationModel.fromJson(json['pagination']) : null;
  }
}

class PaginationModel {
  int? page;
  int? limit;
  int? total;
  int? pages;

  PaginationModel({this.page, this.limit, this.total, this.pages});

  PaginationModel.fromJson(Map<String, dynamic> json) {
    page = json['page'];
    limit = json['limit'];
    total = json['total'];
    pages = json['pages'];
  }
}

class UserStatus {
  String? userId;
  bool? isOnline;
  String? lastSeen;

  UserStatus({this.userId, this.isOnline, this.lastSeen});

  UserStatus.fromJson(Map<String, dynamic> json) {
    userId = json['userId'];
    isOnline = json['isOnline'];
    lastSeen = json['lastSeen'];
  }
}
