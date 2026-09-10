import 'package:flutter/material.dart';
import '../models/room_status_model.dart';
import '../models/timetable_model.dart';
import '../services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/ui_utils.dart';

class BookRoomDialog extends StatefulWidget {
  final RoomStatusModel room;
  final String targetDate;
  final String targetDayName;

  const BookRoomDialog({
    super.key, 
    required this.room,
    required this.targetDate,
    required this.targetDayName,
  });

  @override
  State<BookRoomDialog> createState() => _BookRoomDialogState();
}

class _BookRoomDialogState extends State<BookRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _divisionController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();

  bool _isLoading = false;

  Future<void> _bookRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      String facultyCode = prefs.getString('userCode') ?? 'Unknown';
      String facultyName = prefs.getString('userName') ?? 'You';
      
      // We create a dummy TimetableModel for the clash engine
      TimetableModel newLecture = TimetableModel(
        school: '', 
        department: _divisionController.text.split('-').isNotEmpty ? _divisionController.text.split('-')[0] : '',
        year: _divisionController.text.split('-').length > 1 ? _divisionController.text.split('-')[1] : '',
        division: _divisionController.text.split('-').length > 2 ? _divisionController.text.split('-')[2] : '',
        day: widget.targetDayName, 
        startTime: _startTimeController.text.trim(),
        endTime: _endTimeController.text.trim(),
        subject: _subjectController.text.trim(),
        room: widget.room.id ?? '',
        facultyName: facultyName, 
        facultyCode: facultyCode,
      );

      RoomService roomService = RoomService();
      bool success = await roomService.bookRoom(widget.room, newLecture, widget.targetDate);

      if (success) {
        if (mounted) {
          showAttractiveNotification(context, "Successfully booked for ${_subjectController.text.trim()}");
          Navigator.pop(context, true);
        }
      } else {
        throw Exception("Room is no longer available.");
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString().replaceAll("Exception: ", "");
        showAttractiveNotification(context, errorMessage, isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Book Room ${widget.room.id}\n(${widget.targetDate})", textAlign: TextAlign.center,),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: "Subject"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _divisionController,
                decoration: const InputDecoration(
                  labelText: "Division (e.g. CS-SY-A)",
                  hintText: "Dept-Year-Div",
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startTimeController,
                      decoration: const InputDecoration(labelText: "Start (HH:MM)"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _endTimeController,
                      decoration: const InputDecoration(labelText: "End (HH:MM)"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _bookRoom,
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text("Book Now"),
        )
      ],
    );
  }
}
