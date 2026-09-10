import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'timetable_tabs_screen.dart';
import 'swap_requests_screen.dart';
import 'leave_application_screen.dart';
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
  int _currentIndex = 0;
  String _facultyName = "";

  @override
  void initState() {
    super.initState();
    _loadFacultyName();
  }

  Future<void> _loadFacultyName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _facultyName = prefs.getString('userName') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      TimetableTabsScreen(
        mode: "FACULTY",
        code: widget.code,
        database: widget.database,
      ),
      SwapRequestsScreen(facultyCode: widget.code),
      LeaveApplicationScreen(
        facultyCode: widget.code,
        facultyName: _facultyName,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF1E40AF),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: "Timetable",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: "Swap",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.beach_access),
            label: "Leave",
          ),
        ],
      ),
    );
  }
}