import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/timetable_model.dart';

class EditLectureDialog extends StatefulWidget {
  final TimetableModel lecture;

  const EditLectureDialog({super.key, required this.lecture});

  @override
  State<EditLectureDialog> createState() => _EditLectureDialogState();
}

class _EditLectureDialogState extends State<EditLectureDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _subjectCtrl;
  late TextEditingController _roomCtrl;
  late TextEditingController _facultyNameCtrl;
  late TextEditingController _facultyCodeCtrl;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _subjectCtrl = TextEditingController(text: widget.lecture.subject);
    _roomCtrl = TextEditingController(text: widget.lecture.room);
    _facultyNameCtrl = TextEditingController(text: widget.lecture.facultyName);
    _facultyCodeCtrl = TextEditingController(text: widget.lecture.facultyCode);
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _roomCtrl.dispose();
    _facultyNameCtrl.dispose();
    _facultyCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.lecture.docId == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection("timetable")
          .doc(widget.lecture.docId)
          .update({
        "subject": _subjectCtrl.text.trim(),
        "room": _roomCtrl.text.trim(),
        "facultyName": _facultyNameCtrl.text.trim(),
        "facultyCode": _facultyCodeCtrl.text.trim(),
      });

      if (!mounted) return;
      Navigator.pop(context, true); // true indicates success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Lecture Slot"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(labelText: "Subject"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _roomCtrl,
                decoration: const InputDecoration(labelText: "Room"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _facultyNameCtrl,
                decoration: const InputDecoration(labelText: "Faculty Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _facultyCodeCtrl,
                decoration: const InputDecoration(labelText: "Faculty Code"),
                validator: (v) => v!.isEmpty ? "Required" : null,
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
          onPressed: _isSaving ? null : _saveChanges,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF)),
          child: _isSaving 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text("Save", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
