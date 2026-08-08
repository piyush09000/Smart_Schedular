import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/day_timetable_widget.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'room_availability_screen.dart';
import 'swap_requests_screen.dart';
import 'leave_application_screen.dart';

class TimetableTabsScreen extends StatefulWidget {
  final String mode;
  final String code;
  final DatabaseService database;

  const TimetableTabsScreen({
    super.key,
    required this.mode,
    required this.code,
    required this.database,
  });

  @override
  State<TimetableTabsScreen> createState() => _TimetableTabsScreenState();
}

class _TimetableTabsScreenState extends State<TimetableTabsScreen>
    with SingleTickerProviderStateMixin {

  late TabController controller;
  String _facultyName = "";

  final List<String> days = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];

  int getTodayIndex() {
    int weekday = DateTime.now().weekday;
    switch (weekday) {
      case 1:
        return 0;
      case 2:
        return 1;
      case 3:
        return 2;
      case 4:
        return 3;
      case 5:
        return 4;
      case 6:
        return 5;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    controller = TabController(
      length: days.length,
      vsync: this,
      initialIndex: getTodayIndex(),
    );
    _loadFacultyName();
  }

  Future<void> _loadFacultyName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('userName') ?? '';
    final code = prefs.getString('userCode') ?? widget.code;
    final role = prefs.getString('userRole') ?? 'faculty';
    setState(() {
      _facultyName = name;
    });
    // Start listening for notifications
    NotificationService.startListening(code, role);
  }

  /// ✅ FIXED LOGOUT (SharedPreferences)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          database: widget.database,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),

      appBar: AppBar(
        title: const Text("Timetable"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E40AF),
        elevation: 1,

        actions: [
          if (widget.mode == "FACULTY") ...[
            IconButton(
              icon: const Icon(Icons.beach_access),
              tooltip: "Leave Application",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LeaveApplicationScreen(
                      facultyCode: widget.code,
                      facultyName: _facultyName,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.inbox),
              tooltip: "Swap Requests",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SwapRequestsScreen(facultyCode: widget.code),
                  ),
                );
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.meeting_room),
            tooltip: "Room Availability",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoomAvailabilityScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: "Notifications",
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final code = prefs.getString('userCode') ?? widget.code;
              final role = prefs.getString('userRole') ?? 'faculty';
              if (context.mounted) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => NotificationsScreen(userId: code, role: role),
                ));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: logout,
          ),
        ],

        bottom: TabBar(
          controller: controller,
          isScrollable: true,
          indicatorColor: const Color(0xFF1E40AF),
          labelColor: const Color(0xFF1E40AF),
          unselectedLabelColor: const Color(0xFF6B7280),
          tabs: days.map((d) => Tab(text: d)).toList(),
        ),
      ),

      body: TabBarView(
        controller: controller,
        children: days.map((day) {
          return DayTimetableWidget(
            day: day,
            mode: widget.mode,
            code: widget.code,
            database: widget.database,
          );
        }).toList(),
      ),
    );
  }
}