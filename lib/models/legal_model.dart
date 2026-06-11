class LegalDocument {
  String? id;
  String? type;
  String? title;
  String? content;
  String? updatedAt;

  LegalDocument({this.id, this.type, this.title, this.content, this.updatedAt});

  LegalDocument.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    type = json['type'];
    title = json['title'];
    content = json['content'];
    updatedAt = json['updatedAt'];
  }
}

class LegalResponse {
  bool? success;
  List<LegalDocument>? documents;

  LegalResponse({this.success, this.documents});

  LegalResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['documents'] != null) {
      documents = <LegalDocument>[];
      json['documents'].forEach((v) {
        documents!.add(LegalDocument.fromJson(v));
      });
    }
  }
}
