import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/substitute_service.dart';

class SubstituteManagementScreen extends StatefulWidget {
  const SubstituteManagementScreen({super.key});

  @override
  State<SubstituteManagementScreen> createState() => _SubstituteManagementScreenState();
}

class _SubstituteManagementScreenState extends State<SubstituteManagementScreen> {
  final SubstituteService _subService = SubstituteService();
  final FirebaseFirestore db = FirebaseFirestore.instance;

  Future<void> _showSubstituteDialog(String statusId, String timetableId, String date) async {
    // Fetch timetable info for this lecture to get time and day
    DocumentSnapshot tDoc = await db.collection('timetable').doc(timetableId).get();
    if (!tDoc.exists) return;

    var tData = tDoc.data() as Map<String, dynamic>;
    String day = tData['day'];
    String startTime = tData['startTime'];
    String endTime = tData['endTime'];
    String originalFaculty = tData['facultyName'];
    String subject = tData['subject'];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _subService.getAvailableFaculty(day, startTime, endTime, date),
          builder: (context, snapshot) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Assign Substitute", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Subject: $subject"),
                  Text("Original Faculty: $originalFaculty"),
                  Text("Time: $startTime - $endTime"),
                  const Divider(),
                  const Text("Available Faculty:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else if (snapshot.hasError)
                    Center(child: Text("Error: ${snapshot.error}"))
                  else if (!snapshot.hasData || snapshot.data!.isEmpty)
                    const Center(child: Text("No available faculty found for this time."))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          var faculty = snapshot.data![index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF1E40AF),
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              title: Text(faculty['name']),
                              subtitle: Text("ID: ${faculty['id']}"),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                onPressed: () async {
                                  await _subService.assignSubstitute(statusId, faculty['id'], faculty['name']);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Substitute Assigned Successfully")));
                                  }
                                },
                                child: const Text("Assign"),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Substitute Management"),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('lecture_status')
            .where('lectureStatus', isEqualTo: 'Pending Substitute')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No pending substitute requests."));

          var statusDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: statusDocs.length,
            itemBuilder: (context, index) {
              var doc = statusDocs[index];
              var data = doc.data() as Map<String, dynamic>;
              String timetableId = data['timetableId'];
              String date = data['date'];

              return FutureBuilder<DocumentSnapshot>(
                future: db.collection('timetable').doc(timetableId).get(),
                builder: (context, tSnapshot) {
                  if (!tSnapshot.hasData || !tSnapshot.data!.exists) return const SizedBox();
                  
                  var tData = tSnapshot.data!.data() as Map<String, dynamic>;
                  String subject = tData['subject'] ?? 'Unknown';
                  String originalFaculty = tData['facultyName'] ?? 'Unknown';
                  String time = "${tData['startTime']} - ${tData['endTime']}";
                  String room = tData['room'] ?? '';
                  String dept = tData['department'] ?? '';

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("Original Faculty: $originalFaculty"),
                          Text("Date: $date"),
                          Text("Time: $time | Room: $room | Dept: $dept"),
                        ],
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white),
                        onPressed: () => _showSubstituteDialog(doc.id, timetableId, date),
                        child: const Text("Assign"),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
