import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/swap_request_model.dart';
import '../services/swap_service.dart';

class SwapRequestsScreen extends StatefulWidget {
  final String facultyCode;

  const SwapRequestsScreen({super.key, required this.facultyCode});

  @override
  State<SwapRequestsScreen> createState() => _SwapRequestsScreenState();
}

class _SwapRequestsScreenState extends State<SwapRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SwapService _swapService = SwapService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Widget _buildList(bool isReceived) {
    Query query = FirebaseFirestore.instance.collection('swap_requests');
    if (isReceived) {
      query = query.where('requestedToFacultyId', isEqualTo: widget.facultyCode);
    } else {
      query = query.where('requestedByFacultyId', isEqualTo: widget.facultyCode);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No swap requests found."));
        }

        var requests = snapshot.data!.docs.map((d) => SwapRequestModel.fromJson(d.data() as Map<String, dynamic>, d.id)).toList();
        
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
                        Text(
                          isReceived ? "From: ${req.requestedByFacultyName}" : "To: ${req.requestedToFacultyName}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    const Text("Exchange:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 4),
                    Text("Takes: ${req.currentLectureSubject} (${req.currentLectureTime})"),
                    Text("Gives: ${req.requestedLectureSubject} (${req.requestedLectureTime})"),
                    const SizedBox(height: 8),
                    Text("Reason: ${req.reason}", style: const TextStyle(fontStyle: FontStyle.italic)),
                    
                    if (isReceived && req.status == 'Pending') ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _handleAction(req, 'Rejected'),
                            child: const Text("Reject", style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _handleAction(req, 'Accepted'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("Accept", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      )
                    ]
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleAction(SwapRequestModel request, String action) async {
    try {
      if (action == 'Accepted') {
        await _swapService.acceptSwapRequest(request);
      } else {
        await _swapService.updateSwapStatus(request.id!, action);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request $action")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Swap Requests Inbox"),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Received"),
            Tab(text: "Sent"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(true),
          _buildList(false),
        ],
      ),
    );
  }
}
