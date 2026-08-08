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
  Future<bool> bookRoom(RoomStatusModel room, TimetableModel newLecture) async {
    if (room.status != 'Available') {
      throw Exception("Room is no longer available.");
    }

    String todayDate = DateTime.now().toIso8601String().split('T')[0];
    String timeSlotStr = "${newLecture.startTime} - ${newLecture.endTime}";
    String divisionCode = "${newLecture.department}-${newLecture.year}-${newLecture.division}";

    try {
      // Use a transaction to ensure atomicity and avoid race conditions when reserving
      return await db.runTransaction((transaction) async {
        // 1. Verify Room Clash (is it still available?)
        DocumentReference roomRef = db.collection('room_status').doc(room.id);
        DocumentSnapshot roomSnapshot = await transaction.get(roomRef);
        
        if (roomSnapshot.exists) {
           var data = roomSnapshot.data() as Map<String, dynamic>;
           if (data['status'] != 'Available') {
             throw Exception("Room clash: The room was just booked by someone else.");
           }
        }

        // 2. Check Faculty Clash: Are you already active in another lecture right now?
        QuerySnapshot facultyClash = await db
            .collection('lecture_status')
            .where('facultyId', isEqualTo: newLecture.facultyCode)
            .where('date', isEqualTo: todayDate)
            .where('timeSlot', isEqualTo: timeSlotStr)
            .where('lectureStatus', isEqualTo: 'Active')
            .get();
        if (facultyClash.docs.isNotEmpty) {
          throw Exception("Faculty clash: You are already taking another lecture at this time.");
        }

        // 3. Check Division Clash: Is the class taking another lecture?
        QuerySnapshot divClash = await db
            .collection('lecture_status')
            .where('department', isEqualTo: newLecture.department)
            .where('year', isEqualTo: newLecture.year)
            .where('division', isEqualTo: newLecture.division)
            .where('date', isEqualTo: todayDate)
            .where('timeSlot', isEqualTo: timeSlotStr)
            .where('lectureStatus', isEqualTo: 'Active')
            .get();
        if (divClash.docs.isNotEmpty) {
          throw Exception("Division clash: This division already has an active lecture at this time.");
        }

        // 4. Book the room
        transaction.set(roomRef, {
          'status': 'Occupied', // We map it as Occupied immediately for ad-hoc bookings
          'currentFacultyName': newLecture.facultyName,
          'currentFacultyCode': newLecture.facultyCode,
          'currentSubject': newLecture.subject,
          'currentDivision': divisionCode,
          'currentTimeSlot': timeSlotStr,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return true;
      });
    } catch (e) {
      rethrow;
    }
  }
}
