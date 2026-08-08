import 'package:flutter/material.dart';
import '../models/timetable_model.dart';

class TimetableRow extends StatelessWidget {
  final TimetableModel t;

  const TimetableRow({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// DAY + TIME
            Text(
              "${t.day}  ${t.startTime} - ${t.endTime}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),

            const SizedBox(height: 6),

            /// SUBJECT + ROOM
            Text(
              "${t.subject} (${t.room})",
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 4),

            /// FACULTY
            Text(
              t.facultyName,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
