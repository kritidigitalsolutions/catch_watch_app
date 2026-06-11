class NotificationResponse {
  bool? success;
  List<NotificationItem>? notifications;
  Pagination? pagination;

  NotificationResponse({this.success, this.notifications, this.pagination});

  NotificationResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['notifications'] != null) {
      notifications = <NotificationItem>[];
      json['notifications'].forEach((v) {
        notifications!.add(NotificationItem.fromJson(v));
      });
    }
    pagination = json['pagination'] != null
        ? Pagination.fromJson(json['pagination'])
        : null;
  }
}

class NotificationItem {
  String? id;
  String? title;
  String? message;
  String? type;
  bool? isRead;
  String? sentAt;
  String? createdAt;

  NotificationItem({
    this.id,
    this.title,
    this.message,
    this.type,
    this.isRead,
    this.sentAt,
    this.createdAt,
  });

  NotificationItem.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    title = json['title'];
    message = json['message'];
    type = json['type'];
    isRead = json['isRead'];
    sentAt = json['sentAt'];
    createdAt = json['createdAt'];
  }
}

class Pagination {
  int? currentPage;
  int? totalPages;
  int? totalNotifications;
  bool? hasMore;

  Pagination({
    this.currentPage,
    this.totalPages,
    this.totalNotifications,
    this.hasMore,
  });

  Pagination.fromJson(Map<String, dynamic> json) {
    currentPage = json['currentPage'];
    totalPages = json['totalPages'];
    totalNotifications = json['totalNotifications'];
    hasMore = json['hasMore'];
  }
}
