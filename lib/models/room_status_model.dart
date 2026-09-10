import 'package:cloud_firestore/cloud_firestore.dart';

class RoomStatusModel {
  String? id; // Room name e.g., "101"
  String status; // Available, Occupied, Reserved, Maintenance
  String currentFacultyName;
  String currentFacultyCode;
  String currentSubject;
  String currentDivision;
  String currentTimeSlot;
  Timestamp? lastUpdated;

  RoomStatusModel({
    this.id,
    required this.status,
    this.currentFacultyName = '',
    this.currentFacultyCode = '',
    this.currentSubject = '',
    this.currentDivision = '',
    this.currentTimeSlot = '',

    this.lastUpdated,
  });

  factory RoomStatusModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    return RoomStatusModel(
      id: docId,
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
