class LegalDocument {
  String? id;
  String? type;
  String? title;
  String? content;
  String? updatedAt;
  List<LegalSection>? sections;

  LegalDocument({
    this.id,
    this.type,
    this.title,
    this.content,
    this.updatedAt,
    this.sections,
  });

  LegalDocument.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    type = json['type'];
    title = json['title'];
    content = json['content'];
    updatedAt = json['updatedAt'];
    if (json['sections'] != null) {
      sections = <LegalSection>[];
      json['sections'].forEach((v) {
        sections!.add(LegalSection.fromJson(v));
      });
    }
  }
}

class LegalSection {
  String? id;
  String? heading;
  List<String>? paragraphs;

  LegalSection({this.id, this.heading, this.paragraphs});

  LegalSection.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    heading = json['heading'];
    paragraphs = json['paragraphs']?.cast<String>();
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
