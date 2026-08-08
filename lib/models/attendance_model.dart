import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  String? id;
  String facultyId;
  String facultyName;
  String date; // YYYY-MM-DD
  String status; // Present, Leave, On Duty
  Timestamp? timestamp;

  AttendanceModel({
    this.id,
    required this.facultyId,
    required this.facultyName,
    required this.date,
    required this.status,
    this.timestamp,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    return AttendanceModel(
      id: docId,
      facultyId: json['facultyId'] ?? '',
      facultyName: json['facultyName'] ?? '',
      date: json['date'] ?? '',
      status: json['status'] ?? 'Present',
      timestamp: json['timestamp'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'facultyId': facultyId,
      'facultyName': facultyName,
      'date': date,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
