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
  Future<List<TimetableModel>> getFacultyTimetable(String code, {bool forceRefresh = false, String? targetDate}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'faculty_timetable_$code${targetDate != null ? "_$targetDate" : ""}';
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

    List<TimetableModel> result = snapshot.docs.map((doc) {
      return TimetableModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();

    // Apply Overrides
    if (targetDate != null) {
       QuerySnapshot overridesSnapshot = await db.collection('lecture_overrides').where('date', isEqualTo: targetDate).get();
       
       List<String> addedTimetableIds = [];
       Map<String, Map<String, dynamic>> overrideMap = {};

       for (var doc in overridesSnapshot.docs) {
          var o = doc.data() as Map<String, dynamic>;
          overrideMap[o['timetableId']] = o;
          if (o['newFacultyCode'] == code) {
             addedTimetableIds.add(o['timetableId']);
          }
       }

       if (addedTimetableIds.isNotEmpty) {
          for (String tid in addedTimetableIds) {
             var tDoc = await db.collection("timetable").doc(tid).get();
             if (tDoc.exists) {
                // Ensure we don't duplicate if it was somehow already in baseList
                if (!result.any((e) => e.docId == tid)) {
                   result.add(TimetableModel.fromJson(tDoc.data() as Map<String, dynamic>, tDoc.id));
                }
             }
          }
       }

        for (var i = result.length - 1; i >= 0; i--) {
          var r = result[i];
          if (r.docId != null && overrideMap.containsKey(r.docId)) {
             var o = overrideMap[r.docId]!;
             r.facultyCode = o['newFacultyCode'] ?? r.facultyCode;
             r.facultyName = o['newFacultyName'] ?? r.facultyName;
             r.room = o['newRoom'] ?? r.room;

             if (r.facultyCode != code) {
                result.removeAt(i);
             }
          }
       }

       // FETCH MANUAL BOOKINGS
       QuerySnapshot manualBookingsSnapshot = await db
           .collection('lecture_status')
           .where('facultyId', isEqualTo: code)
           .where('date', isEqualTo: targetDate)
           .where('type', isEqualTo: 'Manual Booking')
           .get();

       for (var doc in manualBookingsSnapshot.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String timeSlot = data['timeSlot'] ?? "00:00 - 00:00";
          var parts = timeSlot.split(" - ");
          
          DateTime dateObj = DateTime.parse(targetDate);
          List<String> weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
          String dayName = weekdays[dateObj.weekday - 1];

          result.add(
            TimetableModel(
              docId: doc.id,
              school: '',
              department: data['department'] ?? '',
              year: data['year'] ?? '',
              division: data['division'] ?? '',
              day: dayName,
              startTime: parts.isNotEmpty ? parts[0] : "",
              endTime: parts.length > 1 ? parts[1] : "",
              subject: data['subject'] ?? 'Manual Booking',
              room: data['room'] ?? '',
              facultyName: data['facultyName'] ?? '',
              facultyCode: data['facultyId'] ?? '',
            )
          );
       }
    }

    // Sort by startTime
    result.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Save to cache
    await prefs.setString(cacheKey, jsonEncode(result.map((e) {
      var map = e.toJson();
      map['docId'] = e.docId;
      return map;
    }).toList()));
    await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);

    return result;
  }

  /// CLASS TIMETABLE
  Future<List<TimetableModel>> getCourseClassTimetable(
      String school, String dept, String year, String div, {bool forceRefresh = false, String? targetDate}) async {

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'class_timetable_${school}_${dept}_${year}_$div${targetDate != null ? "_$targetDate" : ""}';
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

    // Apply Overrides
    if (targetDate != null) {
       QuerySnapshot overridesSnapshot = await db.collection('lecture_overrides').where('date', isEqualTo: targetDate).get();
       Map<String, Map<String, dynamic>> overrideMap = {};
       for (var doc in overridesSnapshot.docs) {
          var o = doc.data() as Map<String, dynamic>;
          overrideMap[o['timetableId']] = o;
       }
       for (var r in result) {
          if (r.docId != null && overrideMap.containsKey(r.docId)) {
             var o = overrideMap[r.docId]!;
             r.facultyCode = o['newFacultyCode'] ?? r.facultyCode;
             r.facultyName = o['newFacultyName'] ?? r.facultyName;
             r.room = o['newRoom'] ?? r.room;
          }
       }
    }

    // FETCH MANUAL BOOKINGS
    if (targetDate != null) {
       QuerySnapshot manualBookingsSnapshot = await db
           .collection('lecture_status')
           .where('department', isEqualTo: dept)
           .where('year', isEqualTo: year)
           .where('division', isEqualTo: div)
           .where('date', isEqualTo: targetDate)
           .where('type', isEqualTo: 'Manual Booking')
           .get();

       for (var doc in manualBookingsSnapshot.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String timeSlot = data['timeSlot'] ?? "00:00 - 00:00";
          var parts = timeSlot.split(" - ");
          
          DateTime dateObj = DateTime.parse(targetDate);
          List<String> weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
          String dayName = weekdays[dateObj.weekday - 1];

          result.add(
            TimetableModel(
              docId: doc.id,
              school: schoolId,
              department: dept,
              year: year,
              division: div,
              day: dayName,
              startTime: parts.isNotEmpty ? parts[0] : "",
              endTime: parts.length > 1 ? parts[1] : "",
              subject: data['subject'] ?? 'Manual Booking',
              room: data['room'] ?? '',
              facultyName: data['facultyName'] ?? '',
              facultyCode: data['facultyId'] ?? '',
            )
          );
       }
    }

    // Sort by startTime
    result.sort((a, b) => a.startTime.compareTo(b.startTime));

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