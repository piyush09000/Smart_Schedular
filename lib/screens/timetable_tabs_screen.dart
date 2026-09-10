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
import '../utils/ui_utils.dart';

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
  late List<DateTime> dates;

  @override
  void initState() {
    super.initState();
    // Generate dates from 3 days ago to 10 days in the future
    dates = List.generate(14, (i) => DateTime.now().subtract(const Duration(days: 3)).add(Duration(days: i)));
    controller = TabController(
      length: dates.length,
      vsync: this,
      initialIndex: 3, // Today is at index 3
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
    
    showAttractiveNotification(context, "Thank you for using!");
    
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
            // Leave and Swap buttons moved to BottomNavigationBar
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
          tabs: dates.map((d) {
             String dayStr = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][d.weekday - 1];
             String dateStr = "${d.day}/${d.month}";
             return Tab(text: "$dayStr $dateStr");
          }).toList(),
        ),
      ),

      body: TabBarView(
        controller: controller,
        children: dates.map((date) {
          String fullDayName = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][date.weekday - 1];
          String targetDate = date.toIso8601String().split('T')[0];

          return DayTimetableWidget(
            day: fullDayName,
            targetDate: targetDate,
            mode: widget.mode,
            code: widget.code,
            database: widget.database,
          );
        }).toList(),
      ),
    );
  }
}