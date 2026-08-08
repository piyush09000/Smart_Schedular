import 'package:flutter/material.dart';
import 'timetable_tabs_screen.dart';
import '../services/database_service.dart';

class FacultyDashboard extends StatefulWidget {
  final String code;
  final DatabaseService database;

  const FacultyDashboard({
    super.key,
    required this.code,
    required this.database,
  });

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {

  @override
  void initState() {
    super.initState();

    /// redirect after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TimetableTabsScreen(
            mode: "FACULTY",
            code: widget.code,
            database: widget.database,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    /// temporary loading screen
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}