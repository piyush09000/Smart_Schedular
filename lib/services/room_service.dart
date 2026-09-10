import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_status_model.dart';
import '../models/timetable_model.dart';

class RoomService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  /// Get real-time stream of all rooms using room_status
  Stream<List<RoomStatusModel>> getRoomsStream() {
    return db.collection('room_status').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return RoomStatusModel.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Update room status manually (typically used inside transactions or batch writes)
  Future<void> updateRoomStatus(String roomId, String status, {
    String currentFacultyName = '',
    String currentFacultyCode = '',
    String currentSubject = '',
    String currentDivision = '',
    String currentTimeSlot = '',
  }) async {
    final docRef = db.collection('room_status').doc(roomId);

    await docRef.set({
      'status': status,
      'currentFacultyName': currentFacultyName,
      'currentFacultyCode': currentFacultyCode,
      'currentSubject': currentSubject,
      'currentDivision': currentDivision,
      'currentTimeSlot': currentTimeSlot,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Book an available room with complex validation
  Future<bool> bookRoom(RoomStatusModel room, TimetableModel newLecture, String targetDate) async {
    // If it's today's date, we also check if the room's real-time status is available.
    String todayDate = DateTime.now().toIso8601String().split('T')[0];
    bool isToday = targetDate == todayDate;

    if (isToday && room.status != 'Available') {
      throw Exception("Room is currently not available.");
    }

    String timeSlotStr = "${newLecture.startTime} - ${newLecture.endTime}";
    String divisionCode = "${newLecture.department}-${newLecture.year}-${newLecture.division}";

    try {
      return await db.runTransaction((transaction) async {
        
        // 1. Verify Real-time Room Clash ONLY if booking for today
        DocumentReference roomRef = db.collection('room_status').doc(room.id);
        if (isToday) {
          DocumentSnapshot roomSnapshot = await transaction.get(roomRef);
          if (roomSnapshot.exists) {
             var data = roomSnapshot.data() as Map<String, dynamic>;
             if (data['status'] != 'Available') {
               throw Exception("Room clash: The room was just booked by someone else today.");
             }
          }
        }

        // 2. Check Timetable Clash: Is there a base scheduled lecture here?
        QuerySnapshot baseTimetable = await db
            .collection('timetable')
            .where('room', isEqualTo: room.id)
            .where('day', isEqualTo: newLecture.day)
            .get();
            
        for (var doc in baseTimetable.docs) {
          var t = TimetableModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
          // Check overlap (simplified by checking start time, can be improved)
          if (t.startTime == newLecture.startTime || t.endTime == newLecture.endTime) {
            
            // 2.a Verify if this specific lecture has an override (e.g., swapped)
            QuerySnapshot overrideQuery = await db.collection('lecture_overrides')
               .where('date', isEqualTo: targetDate)
               .where('timetableId', isEqualTo: doc.id)
               .get();

            if (overrideQuery.docs.isNotEmpty) {
               // A swap exists! The room is occupied by the new faculty.
               throw Exception("Time clash: A swapped lecture is already scheduled in this room at this time.");
            }

            // 2.b If no swap, verify if original faculty is on Leave/Absent
            String lectureStatusId = '${doc.id}_$targetDate';
            DocumentSnapshot statusDoc = await transaction.get(db.collection('lecture_status').doc(lectureStatusId));
            
            bool isLeave = false;
            if (statusDoc.exists) {
              var sData = statusDoc.data() as Map<String, dynamic>;
              if (sData['attendanceStatus'] == 'Leave' || 
                  sData['attendanceStatus'] == 'Absent' || 
                  sData['attendanceStatus'] == 'On Duty') {
                 isLeave = true;
              }
            }
            
            if (!isLeave) {
               throw Exception("Time clash: A regular lecture (${t.subject}) is already scheduled in this room at this time.");
            }
          }
        }

        // 3. Check Faculty Clash
        QuerySnapshot facultyClash = await db
            .collection('lecture_status')
            .where('facultyId', isEqualTo: newLecture.facultyCode)
            .where('date', isEqualTo: targetDate)
            .where('timeSlot', isEqualTo: timeSlotStr)
            .where('lectureStatus', isEqualTo: 'Active')
            .get();
        if (facultyClash.docs.isNotEmpty) {
          throw Exception("Faculty clash: You are already taking another lecture at this time.");
        }

        // 4. Check Division Clash
        QuerySnapshot divClash = await db
            .collection('lecture_status')
            .where('department', isEqualTo: newLecture.department)
            .where('year', isEqualTo: newLecture.year)
            .where('division', isEqualTo: newLecture.division)
            .where('date', isEqualTo: targetDate)
            .where('timeSlot', isEqualTo: timeSlotStr)
            .where('lectureStatus', isEqualTo: 'Active')
            .get();
        if (divClash.docs.isNotEmpty) {
          throw Exception("Division clash: This division already has an active lecture at this time.");
        }

        // 5. Book the room
        // Only update the real-time room_status immediately if the booked timeslot has already started or is currently active.
        bool shouldUpdateRealTimeStatus = false;
        if (isToday) {
           var startParts = newLecture.startTime.split(':');
           var endParts = newLecture.endTime.split(':');
           if (startParts.length == 2 && endParts.length == 2) {
              DateTime now = DateTime.now();
              DateTime startTime = DateTime(now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
              DateTime endTime = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));
              
              if (now.isAfter(startTime) && now.isBefore(endTime)) {
                 shouldUpdateRealTimeStatus = true;
              }
           }
        }

        if (shouldUpdateRealTimeStatus) {
          transaction.set(roomRef, {
            'status': 'Occupied',
            'currentFacultyName': newLecture.facultyName,
            'currentFacultyCode': newLecture.facultyCode,
            'currentSubject': newLecture.subject,
            'currentDivision': divisionCode,
            'currentTimeSlot': timeSlotStr,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        // Log the booking in lecture_status so it acts as an active lecture
        DocumentReference lectureStatusRef = db.collection('lecture_status').doc();
        transaction.set(lectureStatusRef, {
          'date': targetDate,
          'timeSlot': timeSlotStr,
          'facultyId': newLecture.facultyCode,
          'facultyName': newLecture.facultyName,
          'department': newLecture.department,
          'year': newLecture.year,
          'division': newLecture.division,
          'lectureStatus': 'Active',
          'room': room.id,
          'subject': newLecture.subject,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'Manual Booking'
        });

        return true;
      });
    } catch (e) {
      rethrow;
    }
  }
}
