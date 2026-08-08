import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lecture_status_model.dart';
import '../models/attendance_model.dart';
import '../models/room_status_model.dart';
import '../models/timetable_model.dart';

class LectureService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> markFacultyStatus({
    required LectureStatusModel lectureStatus,
  }) async {
    WriteBatch batch = _db.batch();

    // We use a composite ID for lecture_status so a specific lecture on a specific date is uniquely tracked.
    String lectureStatusId = '${lectureStatus.timetableId}_${lectureStatus.date}';
    DocumentReference lectureRef = _db.collection('lecture_status').doc(lectureStatusId);
    
    batch.set(lectureRef, lectureStatus.toJson());

    // Attendance Logging
    // Composite ID for daily attendance
    String attendanceId = '${lectureStatus.facultyId}_${lectureStatus.date}';
    DocumentReference attendanceRef = _db.collection('attendance').doc(attendanceId);
    
    AttendanceModel attendance = AttendanceModel(
      facultyId: lectureStatus.facultyId,
      facultyName: lectureStatus.facultyName,
      date: lectureStatus.date,
      status: lectureStatus.attendanceStatus,
    );
    
    batch.set(attendanceRef, attendance.toJson(), SetOptions(merge: true));

    // Room Status Updates
    if (lectureStatus.room.isNotEmpty) {
      DocumentReference roomRef = _db.collection('room_status').doc(lectureStatus.room);
      
      String roomState = 'Available';
      if (lectureStatus.attendanceStatus == 'Present') {
        roomState = 'Occupied';
      }

      RoomStatusModel roomStatus = RoomStatusModel(
        status: roomState,
        currentFacultyName: roomState == 'Occupied' ? lectureStatus.facultyName : '',
        currentSubject: roomState == 'Occupied' ? lectureStatus.subject : '',
        currentDivision: roomState == 'Occupied' ? lectureStatus.division : '',
        currentTimeSlot: roomState == 'Occupied' ? lectureStatus.timeSlot : '',
      );
      
      batch.set(roomRef, roomStatus.toJson(), SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> syncDefaultStatuses(List<TimetableModel> todayLectures) async {
    String todayDate = DateTime.now().toIso8601String().split('T')[0];
    DateTime now = DateTime.now();

    for (var lecture in todayLectures) {
      try {
        final parts = lecture.startTime.split(":");
        DateTime lectureTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );

        // If the lecture has already started or passed
        if (now.isAfter(lectureTime) || now.isAtSameMomentAs(lectureTime)) {
          String lectureStatusId = '${lecture.docId ?? lecture.id}_$todayDate';
          var doc = await _db.collection('lecture_status').doc(lectureStatusId).get();
          
          if (!doc.exists) {
            // It hasn't been marked. Auto-mark as Present.
            LectureStatusModel model = LectureStatusModel(
              timetableId: lecture.docId ?? lecture.id.toString(),
              facultyId: lecture.facultyCode,
              facultyName: lecture.facultyName,
              subject: lecture.subject,
              school: lecture.school,
              department: lecture.department,
              year: lecture.year,
              division: lecture.division,
              room: lecture.room,
              date: todayDate,
              timeSlot: "${lecture.startTime} - ${lecture.endTime}",
              attendanceStatus: 'Present',
              lectureStatus: 'Active',
            );
            await markFacultyStatus(lectureStatus: model);
          }
        }
      } catch (e) {
        // Ignore parse errors
      }
    }
  }
}
