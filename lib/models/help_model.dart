class HelpItem {
  String? id;
  String? category;
  String? question;
  String? answer;
  String? supportNumber;

  HelpItem({this.id, this.category, this.question, this.answer, this.supportNumber});

  HelpItem.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    category = json['category'];
    question = json['question'];
    answer = json['answer'];
    supportNumber = json['supportNumber'];
  }
}

class HelpResponse {
  bool? success;
  List<HelpItem>? helpData;

  HelpResponse({this.success, this.helpData});

  HelpResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['helpData'] != null) {
      helpData = <HelpItem>[];
      json['helpData'].forEach((v) {
        helpData!.add(HelpItem.fromJson(v));
      });
    }
  }
}
