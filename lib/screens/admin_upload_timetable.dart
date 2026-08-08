import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/clash_detection_service.dart';

class AdminUploadTimetable extends StatefulWidget {
  const AdminUploadTimetable({super.key});

  @override
  State<AdminUploadTimetable> createState() => _AdminUploadTimetableState();
}

class _AdminUploadTimetableState extends State<AdminUploadTimetable> {
  final _formKey = GlobalKey<FormState>();
  final ClashDetectionService _clashService = ClashDetectionService();

  String school = "engineering";
  String department = "CSE";
  String year = "SY";
  String division = "A";
  String day = "Monday";

  final TextEditingController subject = TextEditingController();
  final TextEditingController room = TextEditingController();
  final TextEditingController facultyName = TextEditingController();
  final TextEditingController facultyCode = TextEditingController();
  final TextEditingController startTime = TextEditingController();
  final TextEditingController endTime = TextEditingController();

  Future<void> uploadTimetable() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      String? clashError = await _clashService.validateNewLecture(
        school: school,
        dept: department,
        year: year,
        div: division,
        day: day,
        startTime: startTime.text,
        endTime: endTime.text,
        facultyCode: facultyCode.text,
        room: room.text,
      );

      if (clashError != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(clashError),
            backgroundColor: Colors.red,
          ));
        }
        return; // Stop upload
      }

      await FirebaseFirestore.instance.collection("timetable").add({
        "school": school,
        "department": department,
        "year": year,
        "division": division,
        "batch": "",
        "day": day,
        "startTime": startTime.text,
        "endTime": endTime.text,
        "subject": subject.text,
        "room": room.text,
        "facultyName": facultyName.text,
        "facultyCode": facultyCode.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Timetable Added Successfully"), backgroundColor: Colors.green),
        );
      }

      subject.clear();
      room.clear();
      facultyName.clear();
      facultyCode.clear();
      startTime.clear();
      endTime.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Timetable"),
        backgroundColor: const Color(0xFF1E40AF),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              /// SCHOOL
              DropdownButtonFormField(
                value: school,
                items: const [
                  DropdownMenuItem(value: "engineering", child: Text("Engineering")),
                  DropdownMenuItem(value: "science", child: Text("Science")),
                  DropdownMenuItem(value: "business", child: Text("Business")),
                  DropdownMenuItem(value: "humanities", child: Text("Humanities")),
                  DropdownMenuItem(value: "design", child: Text("Design")),
                ],
                onChanged: (v) => setState(() => school = v!),
                decoration: const InputDecoration(labelText: "School"),
              ),

              const SizedBox(height: 10),

              /// DEPARTMENT
              DropdownButtonFormField(
                value: department,
                items: const [
                  DropdownMenuItem(value: "CSE", child: Text("CSE")),
                  DropdownMenuItem(value: "ECE", child: Text("ECE")),
                ],
                onChanged: (v) => setState(() => department = v!),
                decoration: const InputDecoration(labelText: "Department"),
              ),

              const SizedBox(height: 10),

              /// YEAR
              DropdownButtonFormField(
                value: year,
                items: const [
                  DropdownMenuItem(value: "FY", child: Text("FY")),
                  DropdownMenuItem(value: "SY", child: Text("SY")),
                  DropdownMenuItem(value: "TY", child: Text("TY")),
                ],
                onChanged: (v) => setState(() => year = v!),
                decoration: const InputDecoration(labelText: "Year"),
              ),

              const SizedBox(height: 10),

              /// DIVISION
              DropdownButtonFormField(
                value: division,
                items: const [
                  DropdownMenuItem(value: "A", child: Text("A")),
                  DropdownMenuItem(value: "B", child: Text("B")),
                  DropdownMenuItem(value: "C", child: Text("C")),
                ],
                onChanged: (v) => setState(() => division = v!),
                decoration: const InputDecoration(labelText: "Division"),
              ),

              const SizedBox(height: 10),

              /// DAY
              DropdownButtonFormField(
                value: day,
                items: const [
                  DropdownMenuItem(value: "Monday", child: Text("Monday")),
                  DropdownMenuItem(value: "Tuesday", child: Text("Tuesday")),
                  DropdownMenuItem(value: "Wednesday", child: Text("Wednesday")),
                  DropdownMenuItem(value: "Thursday", child: Text("Thursday")),
                  DropdownMenuItem(value: "Friday", child: Text("Friday")),
                  DropdownMenuItem(value: "Saturday", child: Text("Saturday")),
                ],
                onChanged: (v) => setState(() => day = v!),
                decoration: const InputDecoration(labelText: "Day"),
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: subject,
                decoration: const InputDecoration(labelText: "Subject"),
                validator: (v) => v!.isEmpty ? "Enter subject" : null,
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: facultyName,
                decoration: const InputDecoration(labelText: "Faculty Name"),
                validator: (v) => v!.isEmpty ? "Enter faculty name" : null,
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: facultyCode,
                decoration: const InputDecoration(labelText: "Faculty Code"),
                validator: (v) => v!.isEmpty ? "Enter faculty code" : null,
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: room,
                decoration: const InputDecoration(labelText: "Room"),
                validator: (v) => v!.isEmpty ? "Enter room" : null,
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: startTime,
                decoration: const InputDecoration(labelText: "Start Time"),
                validator: (v) => v!.isEmpty ? "Enter start time" : null,
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: endTime,
                decoration: const InputDecoration(labelText: "End Time"),
                validator: (v) => v!.isEmpty ? "Enter end time" : null,
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: uploadTimetable,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                ),
                child: const Text("UPLOAD TIMETABLE"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}