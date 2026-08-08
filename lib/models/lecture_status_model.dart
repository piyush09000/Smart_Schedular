import 'package:cloud_firestore/cloud_firestore.dart';

class LectureStatusModel {
  String? id;
  String timetableId;
  String facultyId;
  String facultyName;
  String subject;
  String school;
  String department;
  String year;
  String division;
  String room;
  String date; // YYYY-MM-DD
  String timeSlot; // e.g., "10:00 - 11:00"
  String attendanceStatus; // Present, Leave, On Duty
  String lectureStatus; // Active, Pending Substitute, Completed, Cancelled
  Timestamp? timestamp;

  LectureStatusModel({
    this.id,
    required this.timetableId,
    required this.facultyId,
    required this.facultyName,
    required this.subject,
    required this.school,
    required this.department,
    required this.year,
    required this.division,
    required this.room,
    required this.date,
    required this.timeSlot,
    required this.attendanceStatus,
    required this.lectureStatus,
    this.timestamp,
  });

  factory LectureStatusModel.fromJson(Map<String, dynamic> json, [String? documentId]) {
    return LectureStatusModel(
      id: documentId,
      timetableId: json['timetableId'] ?? '',
      facultyId: json['facultyId'] ?? '',
      facultyName: json['facultyName'] ?? '',
      subject: json['subject'] ?? '',
      school: json['school'] ?? '',
      department: json['department'] ?? '',
      year: json['year'] ?? '',
      division: json['division'] ?? '',
      room: json['room'] ?? '',
      date: json['date'] ?? '',
      timeSlot: json['timeSlot'] ?? '',
      attendanceStatus: json['attendanceStatus'] ?? 'Present',
      lectureStatus: json['lectureStatus'] ?? 'Active',
      timestamp: json['timestamp'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timetableId': timetableId,
      'facultyId': facultyId,
      'facultyName': facultyName,
      'subject': subject,
      'school': school,
      'department': department,
      'year': year,
      'division': division,
      'room': room,
      'date': date,
      'timeSlot': timeSlot,
      'attendanceStatus': attendanceStatus,
      'lectureStatus': lectureStatus,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
