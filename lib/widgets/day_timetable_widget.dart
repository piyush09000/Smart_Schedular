import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/timetable_model.dart';
import '../services/notification_service.dart';
import '../screens/lecture_status_dialog.dart';
import '../screens/create_swap_screen.dart';
import '../services/lecture_service.dart';
import '../screens/edit_lecture_dialog.dart';

class DayTimetableWidget extends StatelessWidget {
  final String day;
  final String targetDate;
  final String mode;
  final String code;
  final DatabaseService database;

  const DayTimetableWidget({
    super.key,
    required this.day,
    required this.targetDate,
    required this.mode,
    required this.code,
    required this.database,
  });

  /// ✅ Notification logic
  void checkUpcomingLecture(List<TimetableModel> list) {
    DateTime now = DateTime.now();
    
    // Check if widget.day matches today's weekday string
    List<String> weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    if (weekdays[now.weekday - 1] != day) return;

    // Run auto-sync for default statuses (Client-side lazy evaluation)
    if (mode == "FACULTY") {
      LectureService().syncDefaultStatuses(list);
    }

    for (var t in list) {
      try {
        final parts = t.startTime.split(":");

        DateTime lectureTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );

        Duration diff = lectureTime.difference(now);

        if (diff.inMinutes == 15) { // Notify 15 mins before
          NotificationService.showNotification(
            "Lecture in 15 minutes",
            "${t.subject} in Room ${t.room} (${t.department}-${t.year}-${t.division})",
          );
        }
      } catch (e) {
        print("Time parse error: $e");
      }
    }
  }

  void _onLectureTapped(BuildContext context, TimetableModel lecture) async {
    if (mode == "ADMIN") {
      bool? result = await showDialog(
        context: context,
        builder: (_) => EditLectureDialog(lecture: lecture),
      );
      if (result == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lecture updated successfully.")),
        );
        // We'd ideally trigger a refresh here, but StreamBuilder handles real-time updates usually.
        // For FutureBuilder, the user might need to reload the tab.
      }
      return;
    }

    if (mode != "FACULTY") return;

    String todayDate = DateTime.now().toIso8601String().split('T')[0];
    bool isPastDate = targetDate.compareTo(todayDate) < 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                title: const Text("Update Lecture Status"),
                subtitle: const Text("Mark yourself Present, Leave, or On Duty"),
                onTap: () async {
                  Navigator.pop(ctx);
                  bool? result = await showDialog(
                    context: context,
                    builder: (ctx2) => LectureStatusDialog(
                      lecture: lecture,
                      date: todayDate,
                    ),
                  );

                  if (result == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Lecture status updated successfully.")),
                    );
                  }
                },
              ),
              if (!isPastDate)
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: Colors.blue),
                  title: const Text("Request Swap"),
                  subtitle: const Text("Exchange this lecture with another faculty"),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateSwapScreen(
                          myLecture: lecture,
                          targetDate: targetDate,
                          database: database,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Future<List<TimetableModel>> future;

    if (mode == "FACULTY") {
      future = database.getFacultyTimetable(code, targetDate: targetDate);
    } else {
      List parts = code.split("-");
      future = database.getCourseClassTimetable(
        parts[0],
        parts[1],
        parts[2],
        parts[3],
        targetDate: targetDate,
      );
    }

    return FutureBuilder<List<TimetableModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No timetable available"));
        }

        List<TimetableModel> list =
            snapshot.data!.where((t) => t.day == day).toList();

        if (list.isEmpty) {
          return const Center(child: Text("No timetable available"));
        }

        /// ✅ Notification trigger
        checkUpcomingLecture(list);

        return InteractiveViewer(
          panEnabled: true,
          scaleEnabled: true,
          minScale: 0.7,
          maxScale: 3,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
              columnWidths: const {
                0: FixedColumnWidth(130),
                1: FixedColumnWidth(130),
                2: FixedColumnWidth(100),
                3: FixedColumnWidth(130),
                4: FixedColumnWidth(120),
                5: FixedColumnWidth(90),
              },
              children: [

                /// 🔥 HEADER (FIXED - NO CONST)
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                  ),
                  children: [
                    _header("Subject"),
                    _header("Time"),
                    _header("Room"),
                    _header("Faculty"),
                    _header("Class"),
                    _header("Batch"),
                  ],
                ),

                /// 🔥 DATA ROWS
                ...list.asMap().entries.map((entry) {
                  int index = entry.key;
                  var t = entry.value;

                  String className =
                      "${t.department}-${t.year}-${t.division}";

                  return TableRow(
                    decoration: BoxDecoration(
                      color: index % 2 == 0
                          ? Colors.white
                          : Colors.grey.shade50,
                    ),
                    children: [
                      _cell(
                        t.subject, 
                        isLink: mode == "FACULTY" || mode == "ADMIN", 
                        onTap: (mode == "FACULTY" || mode == "ADMIN") ? () => _onLectureTapped(context, t) : null
                      ),
                      _cell("${t.startTime} - ${t.endTime}"),
                      _cell(t.room),
                      _cell(t.facultyName),
                      _cell(className),
                      _cell(t.batch ?? ""),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 🔹 HEADER CELL
  static Widget _header(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// 🔹 DATA CELL
  static Widget _cell(String text, {bool isLink = false, VoidCallback? onTap}) {
    Widget child = Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: isLink ? Colors.blue : null,
        decoration: isLink ? TextDecoration.underline : null,
      ),
    );

    if (onTap != null) {
      child = InkWell(onTap: onTap, child: child);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Center(child: child),
    );
  }
}