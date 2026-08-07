class VipSupportAccessResponse {
  bool? success;
  bool? hasAccess;
  String? message;

  VipSupportAccessResponse({this.success, this.hasAccess, this.message});

  VipSupportAccessResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    hasAccess = json['hasAccess'];
    message = json['message'];
  }
}

class VipTicketResponse {
  bool? success;
  List<VipTicket>? tickets;

  VipTicketResponse({this.success, this.tickets});

  VipTicketResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['tickets'] != null) {
      tickets = <VipTicket>[];
      json['tickets'].forEach((v) {
        tickets!.add(VipTicket.fromJson(v));
      });
    }
  }
}

class VipTicketDetailResponse {
  bool? success;
  VipTicket? ticket;
  List<VipMessage>? messages;

  VipTicketDetailResponse({this.success, this.ticket, this.messages});

  VipTicketDetailResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    ticket = json['ticket'] != null ? VipTicket.fromJson(json['ticket']) : null;
    if (json['messages'] != null) {
      messages = <VipMessage>[];
      json['messages'].forEach((v) {
        messages!.add(VipMessage.fromJson(v));
      });
    }
  }
}

class VipTicket {
  String? id;
  String? subject;
  String? category;
  String? priority;
  String? status;
  int? unreadByUser;
  int? unreadByAdmin;
  String? createdAt;
  String? updatedAt;
  List<VipMessage>? messages;

  VipTicket({
    this.id,
    this.subject,
    this.category,
    this.priority,
    this.status,
    this.unreadByUser,
    this.unreadByAdmin,
    this.createdAt,
    this.updatedAt,
    this.messages,
  });

  VipTicket.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    subject = json['subject'];
    category = json['category'];
    priority = json['priority'];
    status = json['status'];
    unreadByUser = json['unreadByUser'] ?? 0;
    unreadByAdmin = json['unreadByAdmin'] ?? 0;
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    if (json['messages'] != null) {
      messages = <VipMessage>[];
      json['messages'].forEach((v) {
        messages!.add(VipMessage.fromJson(v));
      });
    }
  }
}

class VipMessage {
  String? id;
  String? senderType; // 'USER' or 'ADMIN'
  String? message;
  List<String>? attachments;
  String? createdAt;

  VipMessage({
    this.id,
    this.senderType,
    this.message,
    this.attachments,
    this.createdAt,
  });

  VipMessage.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    senderType = json['senderType'];
    message = json['message'];
    attachments = json['attachments']?.cast<String>();
    createdAt = json['createdAt'];
  }

  bool get isMe => senderType?.toUpperCase() == 'USER';
}
