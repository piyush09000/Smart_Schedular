import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

import 'timetable_tabs_screen.dart';
import '../services/database_service.dart';
import 'admin_upload_timetable.dart';
import 'admin_add_user.dart';
import '../utils/upload_excel.dart';
import '../utils/upload_users_excel.dart';
import 'leave_approvals_screen.dart';
import 'substitute_management_screen.dart';
import 'notifications_screen.dart';

class AdminDashboard extends StatefulWidget {
  final DatabaseService database;

  const AdminDashboard({super.key, required this.database});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {

  String school = "";
  String department = "";
  String year = "SY";
  String division = "A";

  Map<String, String> schools = {};
  List<String> departments = [];
  Map<String, dynamic> currentDeptStructure = {};

  List<String> years = [];
  List<String> divisions = [];

  bool isUploadingTimetable = false;
  bool isUploadingUsers = false;
  bool isResetting = false;

  @override
  void initState() {
    super.initState();
    loadSchools();
  }

  /// LOAD SCHOOLS
  Future<void> loadSchools() async {
    var snapshot =
        await FirebaseFirestore.instance.collection("schools").get();

    setState(() {
      schools = {
        for (var doc in snapshot.docs)
          doc.id: doc["name"]
      };

      if (schools.isNotEmpty) {
        school = schools.keys.first;
      }
    });

    await loadDepartments();
  }

  /// LOAD DEPARTMENTS
  Future<void> loadDepartments() async {
    var snapshot = await FirebaseFirestore.instance
        .collection("departments")
        .where("school", isEqualTo: school)
        .get();

    setState(() {
      departments = snapshot.docs.map((doc) => doc.id).toList();

      if (departments.isNotEmpty) {
        department = departments.first;
        // Extract structure for the first department
        var docData = snapshot.docs.first.data();
        currentDeptStructure = docData.containsKey('structure') ? docData['structure'] : {};
      } else {
        department = "";
        currentDeptStructure = {};
      }
      
      updateYearsFromStructure();
    });
  }

  /// UPDATE YEARS BASED ON SELECTED DEPARTMENT
  void updateYearsFromStructure() {
    setState(() {
      years = currentDeptStructure.keys.toList();
      if (years.isNotEmpty) {
        if (!years.contains(year)) year = years.first;
      } else {
        year = "";
        years = [];
      }
      updateDivisionsFromStructure();
    });
  }

  /// UPDATE DIVISIONS BASED ON SELECTED YEAR
  void updateDivisionsFromStructure() {
    setState(() {
      if (year.isNotEmpty && currentDeptStructure.containsKey(year)) {
        divisions = List<String>.from(currentDeptStructure[year]);
      } else {
        divisions = [];
      }
      
      if (divisions.isNotEmpty) {
        if (!divisions.contains(division)) division = divisions.first;
      } else {
        division = "";
      }
    });
  }

  Future<void> confirmReset() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Reset Timetable"),
          content: const Text(
              "Are you sure? This will delete the entire timetable."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Reset"),
            )
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => isResetting = true);
      try {
        await widget.database.resetTimetable();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Timetable Reset Successfully")),
          );
        }
      } finally {
        if (mounted) setState(() => isResetting = false);
      }
    }
  }

  Future<void> handleUploadTimetable() async {
    setState(() => isUploadingTimetable = true);
    try {
      await uploadExcelTimetable();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Timetable Excel Uploaded Successfully")),
        );
      }
    } finally {
      if (mounted) setState(() => isUploadingTimetable = false);
    }
  }

  Future<void> handleUploadUsers() async {
    setState(() => isUploadingUsers = true);
    try {
      await uploadUsersExcel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Users Excel Uploaded Successfully")),
        );
      }
    } finally {
      if (mounted) setState(() => isUploadingUsers = false);
    }
  }

  Widget sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E40AF),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: const Color(0xFF1E40AF),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            tooltip: "Notifications",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const NotificationsScreen(userId: 'admin', role: 'admin'),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen(database: widget.database)),
                );
              }
            },
          )
        ],
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            children: [

              /// CLASS SELECT CARD
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    children: [

                      sectionTitle("Select Class"),

                      const SizedBox(height: 20),

                      /// SCHOOL
                      DropdownButtonFormField(
                        value: school,
                        items: schools.entries.map((entry) {
                          return DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          school = value!;
                          await loadDepartments();
                        },
                        decoration: const InputDecoration(
                          labelText: "School",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      /// DEPARTMENT
                      if (departments.isNotEmpty)
                        DropdownButtonFormField(
                          value: departments.contains(department) ? department : null,
                          items: departments.map((d) {
                            return DropdownMenuItem(
                                value: d, child: Text(d));
                          }).toList(),
                          onChanged: (value) async {
                            department = value as String;
                            // Fetch department doc to get structure
                            var doc = await FirebaseFirestore.instance.collection("departments").doc(department).get();
                            setState(() {
                              var docData = doc.data() ?? {};
                              currentDeptStructure = docData.containsKey('structure') ? docData['structure'] : {};
                              updateYearsFromStructure();
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: "Department",
                            border: OutlineInputBorder(),
                          ),
                        ),

                      if (departments.isNotEmpty)
                        const SizedBox(height: 12),

                      /// YEAR
                      if (years.isNotEmpty)
                        DropdownButtonFormField(
                          value: years.contains(year) ? year : null,
                          items: years.map((y) {
                            return DropdownMenuItem(value: y, child: Text(y));
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              year = value as String;
                              updateDivisionsFromStructure();
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: "Year",
                            border: OutlineInputBorder(),
                          ),
                        ),

                      const SizedBox(height: 12),

                      /// DIVISION
                      if (divisions.isNotEmpty)
                        DropdownButtonFormField(
                          value: divisions.contains(division) ? division : null,
                          items: divisions.map((d) {
                            return DropdownMenuItem(value: d, child: Text(d));
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              division = value as String;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: "Division",
                            border: OutlineInputBorder(),
                          ),
                        ),

                      const SizedBox(height: 20),

                      /// VIEW TIMETABLE
                      ElevatedButton(
                        onPressed: () {
                          String code =
                              "$school-$department-$year-$division";

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TimetableTabsScreen(
                                mode: "ADMIN",
                                code: code,
                                database: widget.database,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white, // ✅ FIX
                        ),
                        child: const Text("View Timetable"),
                      ),

                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// TIMETABLE MANAGEMENT
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    children: [

                      sectionTitle("Timetable Management"),

                      const SizedBox(height: 15),

                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AdminUploadTimetable(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white, // ✅ FIX
                          minimumSize: const Size(double.infinity, 45),
                        ),
                        child: const Text("Add Timetable (Manual)"),
                      ),

                      const SizedBox(height: 10),

                      ElevatedButton(
                        onPressed: isUploadingTimetable ? null : handleUploadTimetable,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white, // ✅ FIX
                          minimumSize: const Size(double.infinity, 45),
                        ),
                        child: isUploadingTimetable 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text("Upload Timetable Excel"),
                      ),

                      const SizedBox(height: 10),

                      ElevatedButton(
                        onPressed: isResetting ? null : confirmReset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white, // ✅ FIX
                          minimumSize: const Size(double.infinity, 45),
                        ),
                        child: isResetting 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text("Reset Timetable"),
                      ),

                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// LEAVE MANAGEMENT
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      sectionTitle("Leave Management"),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LeaveApprovalsScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                        ),
                        child: const Text("Manage Leave Approvals"),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SubstituteManagementScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                        ),
                        child: const Text("Substitute Management"),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// USER MANAGEMENT
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    children: [

                      sectionTitle("User Management"),

                      const SizedBox(height: 15),

                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminAddUser(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white, // ✅ FIX
                          minimumSize: const Size(double.infinity, 45),
                        ),
                        child: const Text("Add Single User"),
                      ),

                      const SizedBox(height: 10),

                      ElevatedButton(
                        onPressed: isUploadingUsers ? null : handleUploadUsers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white, // ✅ FIX
                          minimumSize: const Size(double.infinity, 45),
                        ),
                        child: isUploadingUsers 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text("Upload Users Excel"),
                      ),

                    ],
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