import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import 'admin_dashboard.dart';
import 'faculty_dashboard.dart';
import 'hos_dashboard.dart';
import 'vc_dashboard.dart';
import '../services/database_service.dart';

class SplashScreen extends StatefulWidget {
  final DatabaseService database;
  const SplashScreen({super.key, required this.database});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();

    bool isLoggedIn = prefs.getBool("isLoggedIn") ?? false;
    String role = prefs.getString("role") ?? "";
    String userCode = prefs.getString("userCode") ?? "";
    String school = prefs.getString("school") ?? "";

    if (!mounted) return;
    /// ❌ INVALID SESSION → GO LOGIN
    if (!isLoggedIn || role.isEmpty) {
      goLogin();
      return;
    }

    /// 🔥 ADMIN (no userCode needed)
    if (role == "admin") {
      goAdmin();
      return;
    }

    /// ❌ INVALID USER DATA
    if (userCode.isEmpty && role != "admin") {
      goLogin();
      return;
    }

    /// ✅ VALID NAVIGATION
    if (role == "faculty") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FacultyDashboard(
            code: userCode,
            database: widget.database,
          ),
        ),
      );
    } else if (role == "hos") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HOSDashboard(
            school: school,
            database: widget.database,
          ),
        ),
      );
    } else if (role == "vc") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VCDashboard(
            database: widget.database,
          ),
        ),
      );
    } else {
      goLogin();
    }
  }

  void goLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(database: widget.database),
      ),
    );
  }

  void goAdmin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDashboard(database: widget.database),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          "assets/img.png",
          width: 200,
        ),
      ),
    );
  }
}