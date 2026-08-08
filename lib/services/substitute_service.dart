import 'package:cloud_firestore/cloud_firestore.dart';
import 'database_service.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

class SubstituteService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final DatabaseService _dbService = DatabaseService();

  /// Convert "09:00 AM" to minutes since midnight for easy comparison
  int _timeToMinutes(String timeStr) {
    try {
      final format = DateFormat("hh:mm a");
      final dt = format.parse(timeStr);
      return dt.hour * 60 + dt.minute;
    } catch (e) {
      // If parsing fails, try another format or return a default
      return 0;
    }
  }

  bool _isOverlapping(String startA, String endA, String startB, String endB) {
    int sA = _timeToMinutes(startA);
    int eA = _timeToMinutes(endA);
    int sB = _timeToMinutes(startB);
    int eB = _timeToMinutes(endB);

    return (sA < eB && sB < eA);
  }

  /// Get available faculty for a specific day and time slot
  Future<List<Map<String, dynamic>>> getAvailableFaculty(String day, String startTime, String endTime, String date) async {
    List<Map<String, dynamic>> allFaculty = await _dbService.getAllFaculty();
    Set<String> busyFacultyIds = {};

    // 1. Find all faculty who have a class at this time on this day
    QuerySnapshot timetableSnapshot = await db
        .collection('timetable')
        .where('day', isEqualTo: day)
        .get();

    for (var doc in timetableSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String fCode = data['facultyCode'] ?? '';
      if (fCode.isNotEmpty) {
        String tStart = data['startTime'];
        String tEnd = data['endTime'];
        if (_isOverlapping(startTime, endTime, tStart, tEnd)) {
          busyFacultyIds.add(fCode);
        }
      }
    }

    // 2. Find faculty who are on leave on this date
    QuerySnapshot leaveSnapshot = await db
        .collection('leave_requests')
        .where('status', isEqualTo: 'Approved')
        .get();
        
    // Need to parse date to check if it falls between startDate and endDate
    DateTime targetDate = DateTime.parse(date);
    for (var doc in leaveSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String fId = data['facultyId'];
      DateTime start = DateTime.parse(data['startDate']);
      DateTime end = DateTime.parse(data['endDate']);
      
      if ((targetDate.isAfter(start) || targetDate.isAtSameMomentAs(start)) && 
          (targetDate.isBefore(end) || targetDate.isAtSameMomentAs(end))) {
        busyFacultyIds.add(fId);
      }
    }

    // 3. Find faculty who are already assigned as substitutes at this time
    QuerySnapshot subSnapshot = await db
        .collection('lecture_status')
        .where('date', isEqualTo: date)
        .where('lectureStatus', isEqualTo: 'Substitute Assigned')
        .get();

    for (var doc in subSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String subId = data['substituteFacultyId'] ?? '';
      if (subId.isNotEmpty) {
        // We need to fetch the timetable for this status to get the time
        String tId = data['timetableId'];
        DocumentSnapshot tDoc = await db.collection('timetable').doc(tId).get();
        if (tDoc.exists) {
          var tData = tDoc.data() as Map<String, dynamic>;
          String tStart = tData['startTime'];
          String tEnd = tData['endTime'];
          if (_isOverlapping(startTime, endTime, tStart, tEnd)) {
            busyFacultyIds.add(subId);
          }
        }
      }
    }

    // Filter available faculty
    return allFaculty.where((f) => !busyFacultyIds.contains(f['id'])).toList();
  }

  /// Assign substitute
  Future<void> assignSubstitute(String statusId, String substituteId, String substituteName) async {
    // Fetch timetable details to inform the substitute about what class they're covering
    var statusDoc = await db.collection('lecture_status').doc(statusId).get();
    String subject = 'a class';
    String date = '';
    if (statusDoc.exists) {
      var sData = statusDoc.data() as Map<String, dynamic>;
      date = sData['date'] ?? '';
      var tDoc = await db.collection('timetable').doc(sData['timetableId']).get();
      if (tDoc.exists) {
        var tData = tDoc.data() as Map<String, dynamic>;
        subject = tData['subject'] ?? 'a class';
      }
    }

    await db.collection('lecture_status').doc(statusId).update({
      'lectureStatus': 'Substitute Assigned',
      'substituteFacultyId': substituteId,
      'substituteFacultyName': substituteName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await NotificationService.sendToUser(
      substituteId, 
      'Substitute Assigned', 
      'You have been assigned to cover $subject on $date.'
    );
  }
}
