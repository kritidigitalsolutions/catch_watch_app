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
  bool? isBlockedByMe;
  bool? isBlockedByPartner;
  bool? isBlocked;
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
    isBlockedByMe = json['isBlockedByMe'];
    isBlockedByPartner = json['isBlockedByPartner'];
    isBlocked = json['isBlocked'];
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
  dynamic publicKey;
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
    this.publicKey,
    this.id,
  });

  PartnerModel.fromJson(Map<String, dynamic> json) {
    verification = json['verification'] != null ? Verification.fromJson(json['verification']) : null;
    sId = json['_id'];
    phone = json['phone'];
    name = json['name'];
    
    String? fixUrl(String? url) {
      if (url == null || url.isEmpty || url == 'null') return null;
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
    publicKey = json['publicKey'];
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
  List<ReactionModel>? reactions;
  String? createdAt;
  String? updatedAt;
  int? iV;
  String? readAt;
  bool? isPinned;
  bool? isEncrypted;
  String? iv;
  Map<String, dynamic>? encryption;

  // E2EE fields
  bool isDecrypted = false;
  String? cipherText;

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
    this.isPinned,
    this.isEncrypted,
    this.iv,
    this.encryption,
    this.isDecrypted = false,
    this.cipherText,
  });

  String get displayText {
    if (isEncrypted == true && !isDecrypted) {
      return '🔒 [Encrypted message]';
    }
    return text ?? '';
  }

  MessageModel.fromJson(Map<String, dynamic> json) {
    mediaMeta = json['mediaMeta'] != null ? MediaMeta.fromJson(json['mediaMeta']) : null;
    sId = json['_id'] ?? json['id'] ?? json['messageId'];
    
    if (json['conversationId'] != null) {
      if (json['conversationId'] is Map) {
        conversationId = json['conversationId']['_id'] ?? json['conversationId']['id'];
      } else {
        conversationId = json['conversationId'].toString();
      }
    }
    
    if (json['sender'] != null) {
      if (json['sender'] is Map) {
        sender = Sender.fromJson(json['sender']);
      } else {
        sender = Sender(sId: json['sender'].toString(), id: json['sender'].toString());
      }
    } else if (json['senderId'] != null || json['sender_id'] != null) {
      final sId = (json['senderId'] ?? json['sender_id']).toString();
      sender = Sender(
        sId: sId,
        id: sId,
        name: json['senderName'] ?? json['sender_name'],
        profileImage: json['senderImage'] ?? json['sender_image'],
      );
    }

    if (sender != null && sender!.publicKey == null) {
      sender!.publicKey = json['senderPublicKey'] ?? 
          (json['encryption'] is Map ? json['encryption']['senderPublicKey'] : null);
    }
    
    if (json['recipient'] != null) {
      if (json['recipient'] is Map) {
        recipient = Sender.fromJson(json['recipient']);
      } else {
        recipient = json['recipient'];
      }
    }
    
    messageType = json['messageType'];
    text = json['text'];
    if ((text == null || text!.isEmpty) && json['ciphertext'] != null) {
      text = json['ciphertext'].toString();
    }
    mediaUrl = json['mediaUrl'];
    
    if (json['replyTo'] != null) {
      if (json['replyTo'] is Map) {
        replyTo = json['replyTo']['_id'] ?? json['replyTo']['id'];
      } else {
        replyTo = json['replyTo'].toString();
      }
    }
    
    isForwarded = json['isForwarded'];
    status = json['status'];
    deliveredAt = json['deliveredAt'];
    isEdited = json['isEdited'];
    isUnsent = json['isUnsent'];
    deletedFor = json['deletedFor']?.cast<String>();
    if (json['reactions'] != null && json['reactions'] is List) {
      reactions = <ReactionModel>[];
      json['reactions'].forEach((v) {
        if (v is Map<String, dynamic>) {
          reactions!.add(ReactionModel.fromJson(v));
        }
      });
    }
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    iV = json['__v'];
    readAt = json['readAt'];
    isPinned = json['isPinned'];

    if (json['encryption'] is Map) {
      encryption = Map<String, dynamic>.from(json['encryption']);
    }

    String? extractedIv = json['iv']?.toString() ?? json['nonce']?.toString();
    if (extractedIv == null && encryption != null) {
      extractedIv = encryption!['iv']?.toString();
      if (extractedIv == null && encryption!['envelopes'] is List && (encryption!['envelopes'] as List).isNotEmpty) {
        final firstEnvelope = (encryption!['envelopes'] as List).first;
        if (firstEnvelope is Map) {
          extractedIv = firstEnvelope['iv']?.toString();
        }
      }
    }
    iv = extractedIv;

    final rawEncrypted = json['isEncrypted'];
    final bool explicitEncrypted = rawEncrypted == true ||
        rawEncrypted == 'true' ||
        rawEncrypted == 1;

    final bool hasEnvelopes = encryption != null &&
        encryption!['envelopes'] is List &&
        (encryption!['envelopes'] as List).isNotEmpty;

    final bool hasCiphertext = json['ciphertext'] != null && json['ciphertext'].toString().trim().isNotEmpty;

    // Call events and system messages are never treated as E2EE encrypted text
    final bool isCallOrSpecialMessage = messageType == 'call' ||
        messageType == 'audio_call' ||
        messageType == 'video_call';

    if (isCallOrSpecialMessage) {
      isEncrypted = false;
    } else {
      isEncrypted = explicitEncrypted || hasEnvelopes || (hasCiphertext && iv != null && iv!.isNotEmpty);
    }

    if (json['ciphertext'] != null) {
      cipherText = json['ciphertext']?.toString();
    } else if (isEncrypted == true) {
      cipherText = text;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (mediaMeta != null) data['mediaMeta'] = mediaMeta!.toJson();
    if (sId != null) data['_id'] = sId;
    if (conversationId != null) data['conversationId'] = conversationId;
    if (sender != null) data['sender'] = sender!.toJson();
    if (recipient != null) {
      data['recipient'] = recipient is Sender ? (recipient as Sender).toJson() : recipient;
    }
    if (messageType != null) data['messageType'] = messageType;
    if (text != null) data['text'] = text;
    if (mediaUrl != null) data['mediaUrl'] = mediaUrl;
    if (replyTo != null) data['replyTo'] = replyTo;
    if (isForwarded != null) data['isForwarded'] = isForwarded;
    if (status != null) data['status'] = status;
    if (deliveredAt != null) data['deliveredAt'] = deliveredAt;
    if (isEdited != null) data['isEdited'] = isEdited;
    if (isUnsent != null) data['isUnsent'] = isUnsent;
    if (deletedFor != null) data['deletedFor'] = deletedFor;
    if (reactions != null) {
      data['reactions'] = reactions!.map((v) => v.toJson()).toList();
    }
    if (createdAt != null) data['createdAt'] = createdAt;
    if (updatedAt != null) data['updatedAt'] = updatedAt;
    if (iV != null) data['__v'] = iV;
    if (readAt != null) data['readAt'] = readAt;
    if (isPinned != null) data['isPinned'] = isPinned;
    if (isEncrypted != null) data['isEncrypted'] = isEncrypted;
    if (iv != null) data['iv'] = iv;
    if (encryption != null) data['encryption'] = encryption;
    if (cipherText != null) data['ciphertext'] = cipherText;
    return data;
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

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'fileSize': fileSize,
      'duration': duration,
      'mimeType': mimeType,
    };
  }
}

class Sender {
  String? sId;
  String? name;
  String? profileImage;
  String? username;
  dynamic publicKey;
  String? id;

  Sender({this.sId, this.name, this.profileImage, this.username, this.id});

  Sender.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    name = json['name'];
    
    String? fixUrl(String? url) {
      if (url == null || url.isEmpty || url == 'null') return null;
      if (url.startsWith('http')) {
        return url.replaceAll('http://localhost:5000', AppUrl.serverUrl);
      }
      return '${AppUrl.serverUrl}/$url';
    }

    profileImage = fixUrl(json['profileImage']);
    username = json['username'];
    publicKey = json['publicKey'];
    id = json['id'];
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': sId,
      'name': name,
      'profileImage': profileImage,
      'username': username,
      'publicKey': publicKey,
      'id': id,
    };
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

class ReactionModel {
  String? userId;
  String? emoji;

  ReactionModel({this.userId, this.emoji});

  ReactionModel.fromJson(Map<String, dynamic> json) {
    userId = json['userId'];
    if (userId == null && json['user'] != null) {
      if (json['user'] is Map) {
        userId = json['user']['_id'] ?? json['user']['id'];
      } else {
        userId = json['user'].toString();
      }
    }
    emoji = json['emoji'];
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'emoji': emoji,
    };
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
