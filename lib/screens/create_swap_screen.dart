import 'package:flutter/material.dart';
import '../models/timetable_model.dart';
import '../models/swap_request_model.dart';
import '../services/database_service.dart';
import '../services/swap_service.dart';

class CreateSwapScreen extends StatefulWidget {
  final TimetableModel myLecture;
  final DatabaseService database;

  const CreateSwapScreen({
    super.key,
    required this.myLecture,
    required this.database,
  });

  @override
  State<CreateSwapScreen> createState() => _CreateSwapScreenState();
}

class _CreateSwapScreenState extends State<CreateSwapScreen> {
  final SwapService _swapService = SwapService();
  final TextEditingController _reasonController = TextEditingController();

  List<Map<String, dynamic>> _facultyList = [];
  String? _selectedFacultyId;
  String? _selectedFacultyName;

  List<TimetableModel> _targetLectures = [];
  TimetableModel? _selectedTargetLecture;

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadFaculty();
  }

  Future<void> _loadFaculty() async {
    try {
      var allFaculty = await widget.database.getAllFaculty();
      // Remove self
      allFaculty.removeWhere((f) => f['id'] == widget.myLecture.facultyCode);
      setState(() {
        _facultyList = allFaculty;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFacultyLectures(String facultyId) async {
    setState(() {
      _isLoading = true;
      _targetLectures = [];
      _selectedTargetLecture = null;
    });

    try {
      var lectures = await widget.database.getFacultyTimetable(facultyId);
      setState(() {
        _targetLectures = lectures;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedTargetLecture == null) return;
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide a reason")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      SwapRequestModel request = SwapRequestModel(
        requestedByFacultyId: widget.myLecture.facultyCode,
        requestedByFacultyName: widget.myLecture.facultyName,
        requestedToFacultyId: _selectedFacultyId!,
        requestedToFacultyName: _selectedFacultyName!,
        
        currentLectureId: widget.myLecture.docId ?? widget.myLecture.id.toString(),
        currentLectureSubject: widget.myLecture.subject,
        currentLectureTime: "${widget.myLecture.day} ${widget.myLecture.startTime}-${widget.myLecture.endTime}",
        currentLectureRoom: widget.myLecture.room,
        currentLectureClass: "${widget.myLecture.department}-${widget.myLecture.year}-${widget.myLecture.division}",
        
        requestedLectureId: _selectedTargetLecture!.docId ?? _selectedTargetLecture!.id.toString(),
        requestedLectureSubject: _selectedTargetLecture!.subject,
        requestedLectureTime: "${_selectedTargetLecture!.day} ${_selectedTargetLecture!.startTime}-${_selectedTargetLecture!.endTime}",
        requestedLectureRoom: _selectedTargetLecture!.room,
        requestedLectureClass: "${_selectedTargetLecture!.department}-${_selectedTargetLecture!.year}-${_selectedTargetLecture!.division}",
        
        reason: _reasonController.text.trim(),
        status: 'Pending',
      );

      await _swapService.createSwapRequest(request);

      if (mounted) {
        Navigator.pop(context); // Go back to timetable
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Swap Request Sent!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Swap"),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _facultyList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Your Lecture:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Card(
                    child: ListTile(
                      title: Text(widget.myLecture.subject),
                      subtitle: Text("${widget.myLecture.day} ${widget.myLecture.startTime} - ${widget.myLecture.endTime} | Room: ${widget.myLecture.room}"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text("Select Target Faculty:", style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("Choose a Faculty"),
                    value: _selectedFacultyId,
                    items: _facultyList.map((f) {
                      return DropdownMenuItem<String>(
                        value: f['id'],
                        child: Text(f['name']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedFacultyId = val;
                          _selectedFacultyName = _facultyList.firstWhere((f) => f['id'] == val)['name'];
                        });
                        _loadFacultyLectures(val);
                      }
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_targetLectures.isNotEmpty) ...[
                    const Text("Select Target Lecture:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._targetLectures.map((lec) {
                      return RadioListTile<TimetableModel>(
                        title: Text("${lec.subject} (${lec.department}-${lec.year}-${lec.division})"),
                        subtitle: Text("${lec.day} ${lec.startTime}-${lec.endTime} | Room ${lec.room}"),
                        value: lec,
                        groupValue: _selectedTargetLecture,
                        onChanged: (val) => setState(() => _selectedTargetLecture = val),
                      );
                    }).toList(),
                    
                    const SizedBox(height: 20),
                    const Text("Reason for Swap:", style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        hintText: "e.g. Medical emergency",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitRequest,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white),
                        child: _isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Send Swap Request"),
                      ),
                    )
                  ]
                ],
              ),
            ),
    );
  }
}
