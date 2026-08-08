import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/leave_request_model.dart';
import '../services/leave_service.dart';

class LeaveApprovalsScreen extends StatefulWidget {
  const LeaveApprovalsScreen({super.key});

  @override
  State<LeaveApprovalsScreen> createState() => _LeaveApprovalsScreenState();
}

class _LeaveApprovalsScreenState extends State<LeaveApprovalsScreen> {
  final LeaveService _leaveService = LeaveService();
  String _approverId = "Unknown";
  String _approverName = "Approver";

  @override
  void initState() {
    super.initState();
    _loadApprover();
  }

  Future<void> _loadApprover() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _approverId = prefs.getString('userCode') ?? "Admin";
      _approverName = prefs.getString('userName') ?? "Admin";
    });
  }

  Future<void> _handleLeave(LeaveRequestModel request, bool approve) async {
    try {
      if (approve) {
        await _leaveService.approveLeave(request.id!, _approverId, _approverName);
      } else {
        await _leaveService.rejectLeave(request.id!, _approverId, _approverName);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? "Leave Approved" : "Leave Rejected")),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Leave Approvals"),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leave_requests')
            .where('status', isEqualTo: 'Pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No pending leave requests."));

          var requests = snapshot.data!.docs.map((d) => LeaveRequestModel.fromJson(d.data() as Map<String, dynamic>, d.id)).toList();
          
          requests.sort((a, b) {
            var aTime = a.timestamp ?? Timestamp.now();
            var bTime = b.timestamp ?? Timestamp.now();
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              var req = requests[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.facultyName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text("Dates: ${req.startDate} to ${req.endDate}"),
                      const SizedBox(height: 4),
                      Text("Reason: ${req.reason}", style: const TextStyle(fontStyle: FontStyle.italic)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _handleLeave(req, false),
                            child: const Text("Reject", style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _handleLeave(req, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("Approve", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      )
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
