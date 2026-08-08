import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRequestModel {
  String? id;
  String facultyId;
  String facultyName;
  String startDate;
  String endDate;
  String reason;
  String status; // Pending, Approved, Rejected
  String? approverId;
  String? approverName;
  Timestamp? timestamp;

  LeaveRequestModel({
    this.id,
    required this.facultyId,
    required this.facultyName,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.approverId,
    this.approverName,
    this.timestamp,
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    return LeaveRequestModel(
      id: docId,
      facultyId: json['facultyId'] ?? '',
      facultyName: json['facultyName'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'Pending',
      approverId: json['approverId'],
      approverName: json['approverName'],
      timestamp: json['timestamp'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'facultyId': facultyId,
      'facultyName': facultyName,
      'startDate': startDate,
      'endDate': endDate,
      'reason': reason,
      'status': status,
      'approverId': approverId,
      'approverName': approverName,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
    };
  }
}
