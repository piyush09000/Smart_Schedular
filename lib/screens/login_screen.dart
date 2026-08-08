import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'admin_dashboard.dart';
import 'faculty_dashboard.dart';
import 'vc_dashboard.dart';
import 'hos_dashboard.dart';
import '../services/database_service.dart';

class LoginScreen extends StatefulWidget {
  final DatabaseService database;
  const LoginScreen({super.key, required this.database});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();

  void login() async {
    String user = userController.text.trim();
    String pass = passController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter username & password")),
      );
      return;
    }

    try {
      var doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user)
          .get();

      if (!mounted) return;
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not found")),
        );
        return;
      }

      /// ✅ SAFE DATA FETCH
      Map<String, dynamic> data =
          doc.data() as Map<String, dynamic>;

      String role = data["role"] ?? "";
      String dbPassword = data["password"] ?? "";

      if (pass != dbPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Incorrect password")),
        );
        return;
      }

      /// ✅ SAVE SESSION (SAFE)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("isLoggedIn", true);
      await prefs.setString("userCode", user);
      await prefs.setString("role", role);
      await prefs.setString("school", data["school"] ?? ""); // ✅ FIXED

      /// ✅ FCM TOKEN SAVE
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user)
            .update({"fcmToken": token});
      }

      /// ✅ NAVIGATION
      if (role == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboard(database: widget.database),
          ),
        );
      } else if (role == "faculty") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FacultyDashboard(
              code: user,
              database: widget.database,
            ),
          ),
        );
      } else if (role == "hos") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HOSDashboard(
              school: data["school"] ?? "",
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
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login error: $e")),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    /// ✅ REQUEST NOTIFICATION PERMISSION
    FirebaseMessaging.instance.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              const SizedBox(height: 40),

              /// ✅ LOGO
              Image.asset("assets/img.png", width: 180),

              const SizedBox(height: 24),

              TextField(
                controller: userController,
                decoration: const InputDecoration(
                  labelText: "Username",
                  prefixIcon: Icon(Icons.person, color: Color(0xFF1E40AF)),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock, color: Color(0xFF1E40AF)),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: 220,
                height: 45,
                child: ElevatedButton(
                  onPressed: login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    "LOGIN",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}