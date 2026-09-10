import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/swap_request_model.dart';

class AdminSwapRequestsScreen extends StatelessWidget {
  final String scope; // e.g. "HOS", "VC"
  
  const AdminSwapRequestsScreen({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$scope - Swap History"),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('swap_requests').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No swaps found."));
          }

          var requests = snapshot.data!.docs.map((d) => SwapRequestModel.fromJson(d.data() as Map<String, dynamic>, d.id)).toList();
          
          // Sort by timestamp descending
          requests.sort((a, b) {
            var aTime = a.timestamp ?? Timestamp.now();
            var bTime = b.timestamp ?? Timestamp.now();
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              var req = requests[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "${req.requestedByFacultyName} ➡️ ${req.requestedToFacultyName}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: req.status == 'Pending' ? Colors.orange : (req.status == 'Accepted' ? Colors.green : Colors.red),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(req.status, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text("Target Date: ${req.targetDate}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("Takes: ${req.currentLectureSubject} (${req.currentLectureTime})"),
                      Text("Gives: ${req.requestedLectureSubject} (${req.requestedLectureTime})"),
                      const SizedBox(height: 8),
                      Text("Reason: ${req.reason}", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
