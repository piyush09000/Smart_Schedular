import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'timetable_tabs_screen.dart';
import '../services/database_service.dart';

class VCDashboard extends StatefulWidget {
  final DatabaseService database;

  const VCDashboard({super.key, required this.database});

  @override
  State<VCDashboard> createState() => _VCDashboardState();
}

class _VCDashboardState extends State<VCDashboard> {

  String school = "";
  String department = "";
  String year = "SY";
  String division = "A";

  Map<String,String> schools = {};
  List<String> departments = [];
  Map<String, dynamic> currentDeptStructure = {};

  List<String> years = [];
  List<String> divisions = [];

  @override
  void initState() {
    super.initState();
    loadSchools();
  }

  Future<void> loadSchools() async {

    var snapshot =
        await FirebaseFirestore.instance.collection("schools").get();

    setState(() {

      schools = {
        for (var doc in snapshot.docs)
          doc.id : doc["name"]
      };

      if (schools.isNotEmpty) {
        school = schools.keys.first;
      }

    });

    await loadDepartments();
  }

  Future<void> loadDepartments() async {

    var snapshot = await FirebaseFirestore.instance
        .collection("departments")
        .where("school", isEqualTo: school)
        .get();

    setState(() {
      departments = snapshot.docs.map((doc) => doc.id).toList();

      if (departments.isNotEmpty) {
        department = departments.first;
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
        title: const Text("VC Dashboard"),
        backgroundColor: const Color(0xFF1E40AF),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),

          child: Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                sectionTitle("View School Timetable"),

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
                        value: d,
                        child: Text(d),
                      );
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

                    String code;

                    if (departments.isNotEmpty) {
                      code = "$school-$department-$year-$division";
                    } else {
                      code = "$school-$year-$division";
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TimetableTabsScreen(
                          mode: "VC",
                          code: code,
                          database: widget.database,
                        ),
                      ),
                    );

                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white, // ✅ FIX HERE
                  ),
                  child: const Text("View Timetable"),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}