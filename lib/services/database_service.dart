import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/timetable_model.dart';
import 'room_service.dart';


class DatabaseService {

  final FirebaseFirestore db = FirebaseFirestore.instance;

  /// Convert school display name -> school id
  Future<String> getSchoolId(String schoolName) async {

    var snapshot = await db.collection("schools").get();

    for (var doc in snapshot.docs) {

      if (doc["name"] == schoolName) {
        return doc.id; // engineering
      }

      if (doc.id == schoolName) {
        return doc.id;
      }
    }

    return schoolName;
  }

  /// FACULTY VIEW
  Future<List<TimetableModel>> getFacultyTimetable(String code, {bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'faculty_timetable_$code';
    final cacheTimeKey = '${cacheKey}_time';

    if (!forceRefresh) {
      final cachedData = prefs.getString(cacheKey);
      final cacheTime = prefs.getInt(cacheTimeKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Cache valid for 1 hour
      if (cachedData != null && (now - cacheTime) < 3600000) {
        List decoded = jsonDecode(cachedData);
        return decoded.map((e) => TimetableModel.fromJson(e, e['docId'])).toList();
      }
    }

    QuerySnapshot snapshot = await db
        .collection("timetable")
        .where("facultyCode", isEqualTo: code)
        .get();

    final result = snapshot.docs.map((doc) {
      return TimetableModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();

    // Save to cache
    await prefs.setString(cacheKey, jsonEncode(result.map((e) {
      var map = e.toJson();
      map['docId'] = e.docId;
      // Convert timestamps to string if any (though TimetableModel might not have raw Timestamp objects in toJson if handled properly)
      return map;
    }).toList()));
    await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);

    return result;
  }

  /// CLASS TIMETABLE
  Future<List<TimetableModel>> getCourseClassTimetable(
      String school, String dept, String year, String div, {bool forceRefresh = false}) async {

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'class_timetable_${school}_${dept}_${year}_$div';
    final cacheTimeKey = '${cacheKey}_time';

    if (!forceRefresh) {
      final cachedData = prefs.getString(cacheKey);
      final cacheTime = prefs.getInt(cacheTimeKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Cache valid for 1 hour
      if (cachedData != null && (now - cacheTime) < 3600000) {
        List decoded = jsonDecode(cachedData);
        return decoded.map((e) => TimetableModel.fromJson(e, e['docId'])).toList();
      }
    }

    /// convert "Engineering and Technology" -> engineering
    String schoolId = await getSchoolId(school);

    QuerySnapshot snapshot = await db
        .collection("timetable")
        .where("school", isEqualTo: schoolId)
        .where("department", isEqualTo: dept)
        .where("year", isEqualTo: year)
        .where("division", isEqualTo: div)
        .get();

    final result = snapshot.docs.map((doc) {
      return TimetableModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();

    // Save to cache
    await prefs.setString(cacheKey, jsonEncode(result.map((e) {
      var map = e.toJson();
      map['docId'] = e.docId;
      return map;
    }).toList()));
    await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);

    return result;
  }

  /// GET ALL
  Future<List<TimetableModel>> getAll() async {

    QuerySnapshot snapshot = await db.collection("timetable").get();

    return snapshot.docs.map((doc) {
      return TimetableModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  /// CHECK FACULTY
  Future<bool> facultyExists(String code) async {

    QuerySnapshot snapshot = await db
        .collection("users")
        .where("role", isEqualTo: "faculty")
        .where("id", isEqualTo: code) // Fix: It should probably be 'id' or 'code', but let's assume 'id'
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// GET ALL FACULTY
  Future<List<Map<String, dynamic>>> getAllFaculty() async {
    QuerySnapshot snapshot = await db
        .collection("users")
        .where("role", isEqualTo: "faculty")
        .get();

    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc['name'],
      };
    }).toList();
  }

  /// RESET TIMETABLE
  Future<void> resetTimetable() async {

    var snapshot = await db.collection("timetable").get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// MARK FACULTY ABSENT
  Future<void> markFacultyAbsent(TimetableModel lecture, String date) async {
    if (lecture.docId == null) {
      throw Exception("Timetable ID is missing.");
    }

    String statusId = "${lecture.docId}_$date";

    // 1. Update Lecture Status Collection
    await db.collection("lecture_status").doc(statusId).set({
      'timetableId': lecture.docId,
      'date': date,
      'status': 'Faculty Absent',
      'updatedBy': lecture.facultyCode,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Update Room Status to Available
    RoomService roomService = RoomService();
    await roomService.updateRoomStatus(lecture.room, 'Available');
  }
}