import 'package:cloud_firestore/cloud_firestore.dart';

class SwapRequestModel {
  String? id;
  String requestedByFacultyId;
  String requestedByFacultyName;
  String requestedToFacultyId;
  String requestedToFacultyName;
  
  // Teacher A's Lecture
  String currentLectureId;
  String currentLectureSubject;
  String currentLectureTime;
  String currentLectureRoom;
  String currentLectureClass; // Dept-Year-Div

  // Teacher B's Lecture
  String requestedLectureId;
  String requestedLectureSubject;
  String requestedLectureTime;
  String requestedLectureRoom;
  String requestedLectureClass;

  String reason;
  String targetDate; // YYYY-MM-DD
  String status; // Pending, Accepted, Rejected, Cancelled
  Timestamp? timestamp;

  SwapRequestModel({
    this.id,
    required this.requestedByFacultyId,
    required this.requestedByFacultyName,
    required this.requestedToFacultyId,
    required this.requestedToFacultyName,
    required this.currentLectureId,
    required this.currentLectureSubject,
    required this.currentLectureTime,
    required this.currentLectureRoom,
    required this.currentLectureClass,
    required this.requestedLectureId,
    required this.requestedLectureSubject,
    required this.requestedLectureTime,
    required this.requestedLectureRoom,
    required this.requestedLectureClass,
    required this.reason,
    required this.targetDate,
    required this.status,
    this.timestamp,
  });

  factory SwapRequestModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    return SwapRequestModel(
      id: docId,
      requestedByFacultyId: json['requestedByFacultyId'] ?? '',
      requestedByFacultyName: json['requestedByFacultyName'] ?? '',
      requestedToFacultyId: json['requestedToFacultyId'] ?? '',
      requestedToFacultyName: json['requestedToFacultyName'] ?? '',
      currentLectureId: json['currentLectureId'] ?? '',
      currentLectureSubject: json['currentLectureSubject'] ?? '',
      currentLectureTime: json['currentLectureTime'] ?? '',
      currentLectureRoom: json['currentLectureRoom'] ?? '',
      currentLectureClass: json['currentLectureClass'] ?? '',
      requestedLectureId: json['requestedLectureId'] ?? '',
      requestedLectureSubject: json['requestedLectureSubject'] ?? '',
      requestedLectureTime: json['requestedLectureTime'] ?? '',
      requestedLectureRoom: json['requestedLectureRoom'] ?? '',
      requestedLectureClass: json['requestedLectureClass'] ?? '',
      reason: json['reason'] ?? '',
      targetDate: json['targetDate'] ?? '',
      status: json['status'] ?? 'Pending',
      timestamp: json['timestamp'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestedByFacultyId': requestedByFacultyId,
      'requestedByFacultyName': requestedByFacultyName,
      'requestedToFacultyId': requestedToFacultyId,
      'requestedToFacultyName': requestedToFacultyName,
      'currentLectureId': currentLectureId,
      'currentLectureSubject': currentLectureSubject,
      'currentLectureTime': currentLectureTime,
      'currentLectureRoom': currentLectureRoom,
      'currentLectureClass': currentLectureClass,
      'requestedLectureId': requestedLectureId,
      'requestedLectureSubject': requestedLectureSubject,
      'requestedLectureTime': requestedLectureTime,
      'requestedLectureRoom': requestedLectureRoom,
      'requestedLectureClass': requestedLectureClass,
      'reason': reason,
      'targetDate': targetDate,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}