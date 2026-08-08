import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'timetable_tabs_screen.dart';
import '../services/database_service.dart';
import 'leave_approvals_screen.dart';
import 'substitute_management_screen.dart';
import 'notifications_screen.dart';

class HOSDashboard extends StatefulWidget {
  final String school;
  final DatabaseService database;

  const HOSDashboard({
    super.key,
    required this.school,
    required this.database,
  });

  @override
  State<HOSDashboard> createState() => _HOSDashboardState();
}

class _HOSDashboardState extends State<HOSDashboard> {

  String department = "";
  String year = "SY";
  String division = "A";

  /// departmentId -> departmentName
  Map<String,String> departments = {};
  Map<String, dynamic> currentDeptStructure = {};

  List<String> years = [];
  List<String> divisions = [];

  @override
  void initState() {
    super.initState();
    loadDepartments();
  }

  /// LOAD DEPARTMENTS
  Future<void> loadDepartments() async {

    var snapshot = await FirebaseFirestore.instance
        .collection("departments")
        .where("school", isEqualTo: widget.school)
        .get();

    setState(() {
      departments = {
        for (var doc in snapshot.docs)
          doc.id : doc["name"]
      };

      if (departments.isNotEmpty) {
        department = departments.keys.first;
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

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        title: const Text("HOS Dashboard"),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: "Notifications",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const NotificationsScreen(userId: 'hos', role: 'hos'),
              ));
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),

                child: Padding(
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      Text(
                        "School: ${widget.school}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (departments.isNotEmpty)
                        DropdownButtonFormField(
                          value: departments.containsKey(department) ? department : null,
                          items: departments.entries.map((entry) {
                            return DropdownMenuItem(
                                value: entry.key, child: Text(entry.value));
                          }).toList(),
                          onChanged: (value) async {
                            department = value as String;
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

                      const SizedBox(height: 20),

                      /// VIEW TIMETABLE
                      ElevatedButton(
                        onPressed: () {

                          String code =
                              "${widget.school}-$department-$year-$division";

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TimetableTabsScreen(
                                mode: "HOS",
                                code: code,
                                database: widget.database,
                              ),
                            ),
                          );

                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("View Timetable"),
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
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Leave Management",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
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
            ],
          ),
        ),
      ),
    );
  }
}