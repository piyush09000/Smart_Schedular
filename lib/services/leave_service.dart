import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/leave_request_model.dart';
import 'notification_service.dart';

class LeaveService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  Future<void> applyForLeave(LeaveRequestModel request) async {
    await db.collection('leave_requests').add(request.toJson());
    // Notify HOS and Admin that a leave request has been submitted
    await NotificationService.sendToRole('hos', 'Leave Request', '${request.facultyName} has applied for leave from ${request.startDate} to ${request.endDate}.');
    await NotificationService.sendToRole('admin', 'Leave Request', '${request.facultyName} has applied for leave from ${request.startDate} to ${request.endDate}.');
  }

  Future<void> rejectLeave(String requestId, String approverId, String approverName) async {
    var doc = await db.collection('leave_requests').doc(requestId).get();
    await db.collection('leave_requests').doc(requestId).update({
      'status': 'Rejected',
      'approverId': approverId,
      'approverName': approverName,
    });
    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      await NotificationService.sendToUser(data['facultyId'], 'Leave Rejected', '$approverName has rejected your leave request.');
    }
  }

  Future<void> approveLeave(String requestId, String approverId, String approverName) async {
    try {
      await db.runTransaction((transaction) async {
        DocumentReference requestRef = db.collection('leave_requests').doc(requestId);
        DocumentSnapshot snapshot = await transaction.get(requestRef);

        if (!snapshot.exists) throw Exception("Leave request not found");
        if (snapshot['status'] != 'Pending') throw Exception("Leave request is not pending");

        var data = snapshot.data() as Map<String, dynamic>;
        String startDateStr = data['startDate'];
        String endDateStr = data['endDate'];
        String facultyId = data['facultyId'];

        DateTime startDate = DateTime.parse(startDateStr);
        DateTime endDate = DateTime.parse(endDateStr);

        // Update Leave Status
        transaction.update(requestRef, {
          'status': 'Approved',
          'approverId': approverId,
          'approverName': approverName,
        });

        // Loop through all dates in the range
        DateTime currentDate = startDate;
        while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
          // Skip Sundays for timetable if desired, though we'll query timetable based on day string
          String dayOfWeek = DateFormat('EEEE').format(currentDate); 
          String currentDateStr = currentDate.toIso8601String().split('T')[0];

          // We need to fetch the timetable for this faculty on this day of week.
          // Since we are inside a transaction, we should technically read all needed docs first, 
          // but Firestore transactions don't support queries easily without complex rules.
          // However, we CAN run a query, then do a batch of sets inside the transaction.
          // Wait, Firestore transactions allow queries BEFORE any writes.
          QuerySnapshot timetableDocs = await db.collection('timetable')
              .where('facultyCode', isEqualTo: facultyId)
              .where('day', isEqualTo: dayOfWeek)
              .get();

          for (var doc in timetableDocs.docs) {
            String timetableId = doc.id;
            String statusId = "${timetableId}_$currentDateStr";
            DocumentReference statusRef = db.collection('lecture_status').doc(statusId);
            
            // Create or overwrite the lecture status to Pending Substitute
            transaction.set(statusRef, {
              'timetableId': timetableId,
              'date': currentDateStr,
              'lectureStatus': 'Pending Substitute',
              'updatedBy': approverId,
              'timestamp': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          currentDate = currentDate.add(const Duration(days: 1));
        }

        // Notify faculty that leave was approved
        await NotificationService.sendToUser(facultyId, 'Leave Approved', '$approverName has approved your leave request from $startDateStr to $endDateStr.');
      });
    } catch (e) {
      rethrow;
    }
  }
}
