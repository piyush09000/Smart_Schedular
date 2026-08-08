import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ClashDetectionService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  /// Convert "09:00 AM" to minutes since midnight
  int _timeToMinutes(String timeStr) {
    try {
      final format = DateFormat("hh:mm a");
      final dt = format.parse(timeStr.trim());
      return dt.hour * 60 + dt.minute;
    } catch (e) {
      return 0; // Fallback, though ideally parsing shouldn't fail
    }
  }

  /// Check if two time periods overlap
  bool _isOverlapping(String startA, String endA, String startB, String endB) {
    int sA = _timeToMinutes(startA);
    int eA = _timeToMinutes(endA);
    int sB = _timeToMinutes(startB);
    int eB = _timeToMinutes(endB);
    
    // An overlap occurs if A starts before B ends AND B starts before A ends.
    // (e.g. A=10-11, B=10:30-11:30 -> 10 < 11:30 AND 10:30 < 11 -> True)
    // (e.g. A=10-11, B=11-12 -> 10 < 12 AND 11 < 11 -> False, exact adjacent is fine)
    return (sA < eB && sB < eA);
  }

  /// 1. FACULTY CLASH: Is the faculty already teaching in another division?
  Future<bool> hasFacultyClash(String facultyCode, String day, String startTime, String endTime, {String? excludeTimetableId}) async {
    if (facultyCode.isEmpty) return false;

    QuerySnapshot snapshot = await db
        .collection('timetable')
        .where('facultyCode', isEqualTo: facultyCode)
        .where('day', isEqualTo: day)
        .get();

    for (var doc in snapshot.docs) {
      if (excludeTimetableId != null && doc.id == excludeTimetableId) continue;
      
      var data = doc.data() as Map<String, dynamic>;
      if (_isOverlapping(startTime, endTime, data['startTime'], data['endTime'])) {
        return true;
      }
    }
    return false;
  }

  /// 2. DIVISION CLASH: Does the division already have a lecture?
  Future<bool> hasDivisionClash(String school, String dept, String year, String div, String day, String startTime, String endTime, {String? excludeTimetableId}) async {
    QuerySnapshot snapshot = await db
        .collection('timetable')
        .where('school', isEqualTo: school)
        .where('department', isEqualTo: dept)
        .where('year', isEqualTo: year)
        .where('division', isEqualTo: div)
        .where('day', isEqualTo: day)
        .get();

    for (var doc in snapshot.docs) {
      if (excludeTimetableId != null && doc.id == excludeTimetableId) continue;
      
      var data = doc.data() as Map<String, dynamic>;
      if (_isOverlapping(startTime, endTime, data['startTime'], data['endTime'])) {
        return true;
      }
    }
    return false;
  }

  /// 3. ROOM CLASH: Is the room already booked?
  Future<bool> hasRoomClash(String room, String day, String startTime, String endTime, {String? excludeTimetableId}) async {
    if (room.isEmpty) return false;

    QuerySnapshot snapshot = await db
        .collection('timetable')
        .where('room', isEqualTo: room)
        .where('day', isEqualTo: day)
        .get();

    for (var doc in snapshot.docs) {
      if (excludeTimetableId != null && doc.id == excludeTimetableId) continue;
      
      var data = doc.data() as Map<String, dynamic>;
      if (_isOverlapping(startTime, endTime, data['startTime'], data['endTime'])) {
        return true;
      }
    }
    return false;
  }

  /// Master Validation Function for new lectures
  /// Returns null if valid, or an error string if a clash is found.
  Future<String?> validateNewLecture({
    required String school,
    required String dept,
    required String year,
    required String div,
    required String day,
    required String startTime,
    required String endTime,
    required String facultyCode,
    required String room,
    String? excludeTimetableId,
  }) async {
    
    // 1. Check Faculty
    if (await hasFacultyClash(facultyCode, day, startTime, endTime, excludeTimetableId: excludeTimetableId)) {
      return "Faculty Clash: $facultyCode is already teaching at this time.";
    }

    // 2. Check Division
    if (await hasDivisionClash(school, dept, year, div, day, startTime, endTime, excludeTimetableId: excludeTimetableId)) {
      return "Division Clash: This division already has a lecture scheduled at this time.";
    }

    // 3. Check Room
    if (await hasRoomClash(room, day, startTime, endTime, excludeTimetableId: excludeTimetableId)) {
      return "Room Clash: Room $room is already booked at this time.";
    }

    return null; // No clashes!
  }
}
