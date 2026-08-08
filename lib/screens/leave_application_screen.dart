import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leave_request_model.dart';
import '../services/leave_service.dart';

class LeaveApplicationScreen extends StatefulWidget {
  final String facultyCode;
  final String facultyName;

  const LeaveApplicationScreen({
    super.key,
    required this.facultyCode,
    required this.facultyName,
  });

  @override
  State<LeaveApplicationScreen> createState() => _LeaveApplicationScreenState();
}

class _LeaveApplicationScreenState extends State<LeaveApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final LeaveService _leaveService = LeaveService();
  final TextEditingController _reasonController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E40AF),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a date range")));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      LeaveRequestModel request = LeaveRequestModel(
        facultyId: widget.facultyCode,
        facultyName: widget.facultyName,
        startDate: _startDate!.toIso8601String().split('T')[0],
        endDate: _endDate!.toIso8601String().split('T')[0],
        reason: _reasonController.text.trim(),
        status: 'Pending',
      );

      await _leaveService.applyForLeave(request);

      if (mounted) {
        _reasonController.clear();
        setState(() {
          _startDate = null;
          _endDate = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leave request submitted successfully")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Leave Application"),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Apply for Leave", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: const Icon(Icons.date_range),
                        title: Text(_startDate == null 
                          ? "Select Date Range" 
                          : "${_startDate!.toIso8601String().split('T')[0]} to ${_endDate!.toIso8601String().split('T')[0]}"),
                        onTap: () => _selectDateRange(context),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: "Reason for Leave",
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E40AF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isSubmitting 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Submit Application"),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Your Leave History", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('leave_requests')
                  .where('facultyId', isEqualTo: widget.facultyCode)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No leaves found."));

                var requests = snapshot.data!.docs.map((d) => LeaveRequestModel.fromJson(d.data() as Map<String, dynamic>, d.id)).toList();
                
                requests.sort((a, b) {
                  var aTime = a.timestamp ?? Timestamp.now();
                  var bTime = b.timestamp ?? Timestamp.now();
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    var req = requests[index];
                    Color statusColor = req.status == 'Pending' ? Colors.orange : (req.status == 'Approved' ? Colors.green : Colors.red);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text("${req.startDate} to ${req.endDate}"),
                        subtitle: Text(req.reason),
                        trailing: Chip(
                          label: Text(req.status, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: statusColor,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
