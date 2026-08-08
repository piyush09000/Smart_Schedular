import 'package:flutter/material.dart';
import '../models/timetable_model.dart';
import '../models/lecture_status_model.dart';
import '../services/lecture_service.dart';

class LectureStatusDialog extends StatefulWidget {
  final TimetableModel lecture;
  final String date;

  const LectureStatusDialog({
    super.key,
    required this.lecture,
    required this.date,
  });

  @override
  State<LectureStatusDialog> createState() => _LectureStatusDialogState();
}

class _LectureStatusDialogState extends State<LectureStatusDialog> {
  bool _isLoading = false;
  String _selectedStatus = 'Present';

  Future<void> _submitStatus() async {
    setState(() => _isLoading = true);

    try {
      String lectureState = 'Active';
      if (_selectedStatus == 'Leave' || _selectedStatus == 'On Duty') {
        lectureState = 'Pending Substitute';
      }

      LectureStatusModel model = LectureStatusModel(
        timetableId: widget.lecture.docId ?? widget.lecture.id.toString(),
        facultyId: widget.lecture.facultyCode,
        facultyName: widget.lecture.facultyName,
        subject: widget.lecture.subject,
        school: widget.lecture.school,
        department: widget.lecture.department,
        year: widget.lecture.year,
        division: widget.lecture.division,
        room: widget.lecture.room,
        date: widget.date,
        timeSlot: "${widget.lecture.startTime} - ${widget.lecture.endTime}",
        attendanceStatus: _selectedStatus,
        lectureStatus: lectureState,
      );

      await LectureService().markFacultyStatus(lectureStatus: model);

      if (mounted) {
        Navigator.pop(context, true); // Success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving status: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Mark Lecture Status"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Subject: ${widget.lecture.subject}"),
          Text("Time: ${widget.lecture.startTime} - ${widget.lecture.endTime}"),
          const SizedBox(height: 20),
          const Text("Select your status:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          RadioListTile<String>(
            title: const Text("Present"),
            value: "Present",
            groupValue: _selectedStatus,
            onChanged: (v) => setState(() => _selectedStatus = v!),
          ),
          RadioListTile<String>(
            title: const Text("Leave"),
            value: "Leave",
            groupValue: _selectedStatus,
            onChanged: (v) => setState(() => _selectedStatus = v!),
          ),
          RadioListTile<String>(
            title: const Text("On Duty"),
            value: "On Duty",
            groupValue: _selectedStatus,
            onChanged: (v) => setState(() => _selectedStatus = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitStatus,
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
            : const Text("Submit"),
        )
      ],
    );
  }
}
