class TimetableModel {
  int? id;
  String? docId;

  String school;
  String department;
  String year;
  String division;
  String? batch;

  String day;
  String startTime;
  String endTime;

  String subject;
  String room;

  String facultyName;
  String facultyCode;

  TimetableModel({
    this.id,
    required this.school,
    required this.department,
    required this.year,
    required this.division,
    this.batch,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.room,
    required this.facultyName,
    required this.facultyCode,
    this.docId,
  });

  /// convert JSON → object
  factory TimetableModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    return TimetableModel(
      id: json["id"],
      school: json["school"] ?? "",
      department: json["department"] ?? "",
      year: json["year"] ?? "",
      division: json["division"] ?? "",
      batch: json["batch"],
      day: json["day"] ?? "",
      startTime: json["startTime"] ?? "",
      endTime: json["endTime"] ?? "",
      subject: json["subject"] ?? "",
      room: json["room"] ?? "",
      facultyName: json["facultyName"] ?? "",
      facultyCode: json["facultyCode"] ?? "",
      docId: docId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "school": school,
      "department": department,
      "year": year,
      "division": division,
      "batch": batch,
      "day": day,
      "startTime": startTime,
      "endTime": endTime,
      "subject": subject,
      "room": room,
      "facultyName": facultyName,
      "facultyCode": facultyCode,
    };
  }
}