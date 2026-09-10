import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/swap_request_model.dart';
import 'clash_detection_service.dart';
import 'notification_service.dart';

class SwapService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final ClashDetectionService _clashService = ClashDetectionService();

  Future<void> createSwapRequest(SwapRequestModel request) async {
    await db.collection('swap_requests').add(request.toJson());
    
    // Notify target faculty
    await NotificationService.sendToUser(
      request.requestedToFacultyId, 
      "New Swap Request", 
      "${request.requestedByFacultyName} wants to swap a lecture with you."
    );
  }

  Future<void> updateSwapStatus(String requestId, String status) async {
    await db.collection('swap_requests').doc(requestId).update({
      'status': status,
    });
    
    // We need the request details to know who to notify
    var doc = await db.collection('swap_requests').doc(requestId).get();
    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      if (status == 'Rejected') {
        await NotificationService.sendToUser(
          data['requestedByFacultyId'],
          "Swap Request Rejected",
          "${data['requestedToFacultyName']} rejected your swap request."
        );
      }
    }
  }

  Future<bool> acceptSwapRequest(SwapRequestModel request) async {
    try {
      // 0. Pre-fetch lectures to check for clashes before locking the transaction
      DocumentSnapshot docAPre = await db.collection('timetable').doc(request.currentLectureId).get();
      DocumentSnapshot docBPre = await db.collection('timetable').doc(request.requestedLectureId).get();

      if (!docAPre.exists || !docBPre.exists) {
        throw Exception("One of the lectures no longer exists in the timetable.");
      }

      var dataAPre = docAPre.data() as Map<String, dynamic>;
      var dataBPre = docBPre.data() as Map<String, dynamic>;

      // Check if Faculty A (who owns A) is free at B's time
      bool aBusy = await _clashService.hasFacultyClash(
        request.requestedByFacultyId, 
        dataBPre['day'], 
        dataBPre['startTime'], 
        dataBPre['endTime'],
        excludeTimetableId: request.currentLectureId, // Just in case they overlap
      );

      // Check if Faculty B (who owns B) is free at A's time
      bool bBusy = await _clashService.hasFacultyClash(
        request.requestedToFacultyId, 
        dataAPre['day'], 
        dataAPre['startTime'], 
        dataAPre['endTime'],
        excludeTimetableId: request.requestedLectureId,
      );

      if (aBusy) throw Exception("Faculty ${request.requestedByFacultyName} has a clashing lecture at the requested swap time.");
      if (bBusy) throw Exception("Faculty ${request.requestedToFacultyName} has a clashing lecture at your current time.");


      await db.runTransaction((transaction) async {
        DocumentReference requestRef = db.collection('swap_requests').doc(request.id);
        
        DocumentSnapshot reqSnapshot = await transaction.get(requestRef);
        if (!reqSnapshot.exists) throw Exception("Request not found");
        if (reqSnapshot['status'] != 'Pending') throw Exception("Request is no longer pending");

        // 1. Fetch both original timetable documents
        DocumentReference lectureARef = db.collection('timetable').doc(request.currentLectureId);
        DocumentReference lectureBRef = db.collection('timetable').doc(request.requestedLectureId);

        DocumentSnapshot docA = await transaction.get(lectureARef);
        DocumentSnapshot docB = await transaction.get(lectureBRef);

        if (!docA.exists || !docB.exists) {
          throw Exception("One of the lectures no longer exists in the timetable.");
        }

        var dataA = docA.data() as Map<String, dynamic>;
        var dataB = docB.data() as Map<String, dynamic>;

        // Ensure times haven't shifted since our pre-check
        if (dataA['startTime'] != dataAPre['startTime'] || dataB['startTime'] != dataBPre['startTime']) {
           throw Exception("Lecture times have shifted. Please try again.");
        }

        // 2. Validate they still belong to the expected faculty
        if (dataA['facultyCode'] != request.requestedByFacultyId || 
            dataB['facultyCode'] != request.requestedToFacultyId) {
          throw Exception("The faculty for these lectures has changed since the request was made.");
        }

        // 3. Create Overrides for the target date
        transaction.set(db.collection('lecture_overrides').doc(), {
          'date': request.targetDate,
          'timetableId': request.currentLectureId,
          'newFacultyCode': request.requestedToFacultyId,
          'newFacultyName': request.requestedToFacultyName,
          'type': 'Swap',
        });

        transaction.set(db.collection('lecture_overrides').doc(), {
          'date': request.targetDate,
          'timetableId': request.requestedLectureId,
          'newFacultyCode': request.requestedByFacultyId,
          'newFacultyName': request.requestedByFacultyName,
          'type': 'Swap',
        });

        // 4. Update the Swap Request Status
        transaction.update(requestRef, {
          'status': 'Accepted'
        });

        // 5. Log it to history
        transaction.set(db.collection('swap_history').doc(), {
          'swapRequestId': request.id,
          'resolvedAt': FieldValue.serverTimestamp(),
          'outcome': 'Accepted',
          'swappedA': request.currentLectureId,
          'swappedB': request.requestedLectureId,
        });

      });
      
      // Notify the requesting faculty that their swap was accepted
      await NotificationService.sendToUser(
        request.requestedByFacultyId,
        'Swap Request Accepted',
        '${request.requestedToFacultyName} has accepted your swap request.'
      );
      
      return true;
    } catch (e) {
      rethrow;
    }
  }
}
