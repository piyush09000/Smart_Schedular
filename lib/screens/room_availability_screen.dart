import 'package:flutter/material.dart';
import '../models/room_status_model.dart';
import '../services/room_service.dart';
import '../widgets/book_room_dialog.dart';

class RoomAvailabilityScreen extends StatelessWidget {
  final RoomService _roomService = RoomService();

  RoomAvailabilityScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Available':
        return Colors.green;
      case 'Occupied':
        return Colors.red;
      case 'Reserved':
        return Colors.amber;
      case 'Maintenance':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  void _onRoomTapped(BuildContext context, RoomStatusModel room) async {
    if (room.status == 'Available') {
      await showDialog(
        context: context,
        builder: (_) => BookRoomDialog(room: room),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Room ${room.id} is currently ${room.status}.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Smart Room Availability"),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<RoomStatusModel>>(
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

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              RoomStatusModel room = rooms[index];
              return InkWell(
                onTap: () => _onRoomTapped(context, room),
                borderRadius: BorderRadius.circular(12),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(room.status),
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Room ${room.id}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(room.status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            room.status,
                            style: TextStyle(
                              color: _getStatusColor(room.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (room.status == 'Occupied') ...[
                          const SizedBox(height: 8),
                          Text(
                            room.currentSubject,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "By: ${room.currentFacultyName}",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
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
