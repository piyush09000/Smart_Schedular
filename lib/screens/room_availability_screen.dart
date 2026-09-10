import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_status_model.dart';
import '../models/timetable_model.dart';
import '../services/room_service.dart';
import '../widgets/book_room_dialog.dart';
import 'package:intl/intl.dart';
import '../utils/ui_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoomAvailabilityScreen extends StatefulWidget {
  const RoomAvailabilityScreen({super.key});

  @override
  State<RoomAvailabilityScreen> createState() => _RoomAvailabilityScreenState();
}

class _RoomAvailabilityScreenState extends State<RoomAvailabilityScreen> {
  final RoomService _roomService = RoomService();
  DateTime _selectedDate = DateTime.now();
  String _myUserCode = '';
  Map<String, List<Map<String, dynamic>>> _manualBookingsByRoom = {};

  @override
  void initState() {
    super.initState();
    _loadUserCode();
    _fetchManualBookingsForDate();
  }

  Future<void> _loadUserCode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _myUserCode = prefs.getString('userCode') ?? '';
    });
  }

  Future<void> _fetchManualBookingsForDate() async {
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    var snapshot = await FirebaseFirestore.instance
        .collection('lecture_status')
        .where('date', isEqualTo: formattedDate)
        .where('type', isEqualTo: 'Manual Booking')
        .get();
        
    Map<String, List<Map<String, dynamic>>> map = {};
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String roomId = data['room'] ?? '';
      if (!map.containsKey(roomId)) {
        map[roomId] = [];
      }
      map[roomId]!.add(data);
    }
    
    if (mounted) {
      setState(() {
        _manualBookingsByRoom = map;
      });
    }
  }

  Color _getStatusColor(String status) {
    if (status.contains('Occupied by You')) return Colors.purple;
    if (status.contains('Occupied')) return Colors.red;
    if (status.contains('Bookings')) return Colors.purple;
    if (status == 'Available') return Colors.green;
    if (status == 'Reserved') return Colors.amber;
    if (status == 'Maintenance') return Colors.grey;
    return Colors.blue; // Default for Check Schedule
  }

  IconData _getStatusIcon(String status) {
    if (status.contains('Occupied')) return Icons.lock;
    if (status.contains('Book')) return Icons.event_available;
    if (status == 'Available') return Icons.check_circle_outline;
    if (status == 'Maintenance') return Icons.build;
    return Icons.meeting_room;
  }

  Widget _buildDateSelector() {
    return Container(
      height: 100,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 30, // next 30 days
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          DateTime date = DateTime.now().add(Duration(days: index));
          bool isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month && date.year == _selectedDate.year;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
              _fetchManualBookingsForDate();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 70,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              decoration: BoxDecoration(
                gradient: isSelected 
                    ? const LinearGradient(colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: isSelected ? null : Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected ? [
                  BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))
                ] : [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
                ],
                border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[200]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('MMM').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white70 : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${date.day}",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white70 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryDashboard(List<RoomStatusModel> rooms) {
    int availableCount = 0;
    int occupiedCount = 0;
    bool isToday = _selectedDate.day == DateTime.now().day && _selectedDate.month == DateTime.now().month && _selectedDate.year == DateTime.now().year;

    if (isToday) {
      DateTime now = DateTime.now();
      for (var room in rooms) {
        bool isActivelyOccupied = room.status == 'Occupied';
        
        List<Map<String, dynamic>> roomBookings = _manualBookingsByRoom[room.id] ?? [];
        for (var booking in roomBookings) {
           String timeSlot = booking['timeSlot'] ?? '';
           var parts = timeSlot.split('-');
           if (parts.length == 2) {
              var startParts = parts[0].trim().split(':');
              var endParts = parts[1].trim().split(':');
              if (startParts.length == 2 && endParts.length == 2) {
                 DateTime startTime = DateTime(now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
                 DateTime endTime = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));
                 if (now.isAfter(startTime) && now.isBefore(endTime)) {
                    isActivelyOccupied = true;
                    break;
                 }
              }
           }
        }
        
        if (isActivelyOccupied) {
          occupiedCount++;
        } else {
          availableCount++;
        }
      }
    } else {
      availableCount = rooms.length;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSummaryItem("Available", availableCount, Colors.green),
          if (isToday) _buildSummaryItem("Occupied", occupiedCount, Colors.red),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Future<List<TimetableModel>> _fetchScheduleForRoom(String roomId, String dayName, String formattedDate) async {
    // 1. Fetch base timetable
    QuerySnapshot timetableSnapshot = await FirebaseFirestore.instance
        .collection('timetable')
        .where('room', isEqualTo: roomId)
        .where('day', isEqualTo: dayName)
        .get();

    List<TimetableModel> lectures = timetableSnapshot.docs
        .map((d) => TimetableModel.fromJson(d.data() as Map<String, dynamic>, d.id))
        .toList();

    // 2. Fetch overrides for the selected date
    QuerySnapshot overrideSnapshot = await FirebaseFirestore.instance
        .collection('lecture_overrides')
        .where('date', isEqualTo: formattedDate)
        .get();

    Map<String, Map<String, dynamic>> overrides = {
      for (var doc in overrideSnapshot.docs)
        (doc.data() as Map<String, dynamic>)['timetableId']: doc.data() as Map<String, dynamic>
    };

    // 3. Merge overrides
    for (var lecture in lectures) {
      if (overrides.containsKey(lecture.docId ?? lecture.id.toString())) {
        var overrideData = overrides[lecture.docId ?? lecture.id.toString()]!;
        lecture.facultyName = overrideData['newFacultyName'] ?? lecture.facultyName;
        lecture.facultyCode = overrideData['newFacultyCode'] ?? lecture.facultyCode;
      }
    }

    // 4. Fetch Manual Bookings
    QuerySnapshot manualBookingsSnapshot = await FirebaseFirestore.instance
        .collection('lecture_status')
        .where('room', isEqualTo: roomId)
        .where('date', isEqualTo: formattedDate)
        .where('type', isEqualTo: 'Manual Booking')
        .get();

    for (var doc in manualBookingsSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String timeSlot = data['timeSlot'] ?? "00:00 - 00:00";
      var parts = timeSlot.split(" - ");
      String start = parts.isNotEmpty ? parts[0] : "";
      String end = parts.length > 1 ? parts[1] : "";
      
      String facCode = data['facultyId'] ?? '';
      String facName = data['facultyName'] ?? facCode;
      
      if (facCode == _myUserCode) {
        facName = "You";
      }

      lectures.add(
        TimetableModel(
          docId: doc.id,
          school: '',
          department: data['department'] ?? '',
          year: data['year'] ?? '',
          division: data['division'] ?? '',
          day: dayName,
          startTime: start,
          endTime: end,
          subject: data['subject'] ?? 'Manual Booking',
          room: roomId,
          facultyName: facName,
          facultyCode: facCode,
        )
      );
    }

    lectures.sort((a, b) => a.startTime.compareTo(b.startTime));
    return lectures;
  }

  void _onRoomTapped(BuildContext context, RoomStatusModel room) {
    String dayName = DateFormat('EEEE').format(_selectedDate);
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  height: 6,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Room ${room.id}",
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            DateFormat('EEEE, MMM d').format(_selectedDate),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.meeting_room, color: Colors.blue, size: 28),
                      )
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<List<TimetableModel>>(
                    future: _fetchScheduleForRoom(room.id ?? '', dayName, formattedDate),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                      }
                      
                      var lectures = snapshot.data ?? [];
                      if (lectures.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                "No lectures scheduled",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: lectures.length,
                        itemBuilder: (context, index) {
                          var l = lectures[index];
                          bool isManual = l.subject == 'Manual Booking';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isManual ? Colors.purple.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isManual ? Colors.purple.withOpacity(0.2) : Colors.blue.withOpacity(0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      l.startTime,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                                    ),
                                    Text(
                                      l.endTime,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  width: 4,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isManual ? Colors.purple : Colors.blue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.subject,
                                        style: TextStyle(
                                          fontSize: 16, 
                                          fontWeight: FontWeight.bold, 
                                          color: isManual ? Colors.purple[800] : const Color(0xFF1E293B)
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.person, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            l.facultyName,
                                            style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                      if (l.department.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.class_, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${l.department}-${l.year}-${l.division}",
                                              style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))
                    ]
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);

                        bool isToday = _selectedDate.day == DateTime.now().day && _selectedDate.month == DateTime.now().month && _selectedDate.year == DateTime.now().year;
                        if (isToday && room.status != 'Available') {
                          showAttractiveNotification(context, "Room ${room.id} is already ${room.status} today.", isSuccess: false);
                          return;
                        }

                        await showDialog(
                          context: context,
                          builder: (_) => BookRoomDialog(
                            room: room, 
                            targetDate: formattedDate,
                            targetDayName: dayName,
                          ),
                        );
                        
                        // Refresh manual bookings after dialog closes in case a new booking was added
                        _fetchManualBookingsForDate();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: const Text("Book / Occupy Room", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Lighter, modern background
      appBar: AppBar(
        title: const Text("Room Availability", style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          Expanded(
            child: StreamBuilder<List<RoomStatusModel>>(
              stream: _roomService.getRoomsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error loading rooms: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No room data available."));
                }

                List<RoomStatusModel> rooms = snapshot.data!;

                return Column(
                  children: [
                    _buildSummaryDashboard(rooms),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: rooms.length,
                        itemBuilder: (context, index) {
                          RoomStatusModel room = rooms[index];
                          
                          bool isToday = _selectedDate.day == DateTime.now().day && _selectedDate.month == DateTime.now().month && _selectedDate.year == DateTime.now().year;
                          List<Map<String, dynamic>> roomBookings = _manualBookingsByRoom[room.id] ?? [];
                          
                          String displayStatus = "Check Schedule";
                          String currentSubject = "";
                          String currentFaculty = "";
                          
                          if (isToday) {
                            displayStatus = room.status;
                            currentSubject = room.currentSubject;
                            currentFaculty = room.currentFacultyName;
                            
                            DateTime now = DateTime.now();
                            for (var booking in roomBookings) {
                               String timeSlot = booking['timeSlot'] ?? '';
                               var parts = timeSlot.split('-');
                               if (parts.length == 2) {
                                  var startParts = parts[0].trim().split(':');
                                  var endParts = parts[1].trim().split(':');
                                  if (startParts.length == 2 && endParts.length == 2) {
                                     DateTime startTime = DateTime(now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
                                     DateTime endTime = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));
                                     if (now.isAfter(startTime) && now.isBefore(endTime)) {
                                         if (booking['facultyId'] == _myUserCode) {
                                            displayStatus = "Occupied by You";
                                         } else {
                                            displayStatus = "Occupied";
                                         }
                                         currentSubject = booking['subject'] ?? '';
                                         currentFaculty = booking['facultyName'] ?? '';
                                         break;
                                     }
                                  }
                               }
                            }

                            if (displayStatus == 'Occupied' && room.currentFacultyCode == _myUserCode) {
                              displayStatus = "Occupied by You";
                            }
                          }

                          Color statusColor = _getStatusColor(displayStatus);

                          return InkWell(
                            onTap: () => _onRoomTapped(context, room),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withOpacity(0.15),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  )
                                ],
                                border: Border.all(
                                  color: statusColor.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  children: [
                                    // Background Icon watermark
                                    Positioned(
                                      right: -15,
                                      top: -15,
                                      child: Icon(
                                        _getStatusIcon(displayStatus),
                                        size: 90,
                                        color: statusColor.withOpacity(0.08),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(_getStatusIcon(displayStatus), color: statusColor, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  "Room ${room.id}",
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.2,
                                                    color: Color(0xFF1E293B)
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          if (isToday && displayStatus.contains('Occupied')) ...[
                                            Text(
                                              currentSubject,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "By: $currentFaculty",
                                              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              displayStatus,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

