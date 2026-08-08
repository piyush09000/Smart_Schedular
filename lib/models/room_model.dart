import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  String id;
  String status;
  String currentFacultyName;
  String currentFacultyCode;
  String currentSubject;
  String currentDivision;
  String currentTimeSlot;
  Timestamp? lastUpdated;

  RoomModel({
    required this.id,
    required this.status,
    this.currentFacultyName = '',
    this.currentFacultyCode = '',
    this.currentSubject = '',
    this.currentDivision = '',
    this.currentTimeSlot = '',
    this.lastUpdated,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json, String documentId) {
    return RoomModel(
      id: documentId,
      status: json['status'] ?? 'Available',
      currentFacultyName: json['currentFacultyName'] ?? '',
      currentFacultyCode: json['currentFacultyCode'] ?? '',
      currentSubject: json['currentSubject'] ?? '',
      currentDivision: json['currentDivision'] ?? '',
      currentTimeSlot: json['currentTimeSlot'] ?? '',
      lastUpdated: json['lastUpdated'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'currentFacultyName': currentFacultyName,
      'currentFacultyCode': currentFacultyCode,
      'currentSubject': currentSubject,
      'currentDivision': currentDivision,
      'currentTimeSlot': currentTimeSlot,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}
