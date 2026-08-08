import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> uploadExcelTimetable() async {

  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );

  if (result == null) return;

  File file = File(result.files.single.path!);

  var bytes = file.readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);

  FirebaseFirestore db = FirebaseFirestore.instance;

  Set<String> uniqueRooms = {};
  Map<String, Map<String, Set<String>>> deptHierarchy = {};

  for (var table in excel.tables.keys) {
    var rows = excel.tables[table]!.rows;
    if (rows.isEmpty) continue;

    // Build header map (e.g. "School" -> 0)
    Map<String, int> headers = {};
    var firstRow = rows.first;
    for (int i = 0; i < firstRow.length; i++) {
      var cellValue = firstRow[i]?.value?.toString().trim().toLowerCase();
      if (cellValue != null && cellValue.isNotEmpty) {
        headers[cellValue] = i;
      }
    }

    int getIndex(String key) => headers[key.toLowerCase()] ?? -1;
    String? getVal(List<Data?> row, String key) {
      int idx = getIndex(key);
      if (idx == -1 || idx >= row.length) return null;
      return row[idx]?.value?.toString().trim();
    }

    for (var row in rows.skip(1)) {
      if (row.isEmpty) continue;

      String? school = getVal(row, "school") ?? row[0]?.value?.toString();
      String? dept = getVal(row, "department") ?? row[1]?.value?.toString();
      String? year = getVal(row, "year") ?? row[2]?.value?.toString();
      String? div = getVal(row, "division") ?? row[3]?.value?.toString();
      String? room = getVal(row, "room") ?? row[9]?.value?.toString();
      String? batch = getVal(row, "batch") ?? row[4]?.value?.toString();
      String? day = getVal(row, "day") ?? row[5]?.value?.toString();
      String? startTime = getVal(row, "start time") ?? getVal(row, "starttime") ?? row[6]?.value?.toString();
      String? endTime = getVal(row, "end time") ?? getVal(row, "endtime") ?? row[7]?.value?.toString();
      String? subject = getVal(row, "subject") ?? row[8]?.value?.toString();
      String? facultyName = getVal(row, "faculty name") ?? getVal(row, "facultyname") ?? getVal(row, "faculty") ?? row[10]?.value?.toString();
      String? facultyCode = getVal(row, "faculty code") ?? getVal(row, "facultycode") ?? row[11]?.value?.toString();

      if (room != null && room.trim().isNotEmpty) {
        uniqueRooms.add(room.trim());
      }

      if (dept != null && year != null && div != null) {
        String d = dept.trim();
        String y = year.trim();
        String v = div.trim();

        deptHierarchy.putIfAbsent(d, () => {});
        deptHierarchy[d]!.putIfAbsent(y, () => {});
        deptHierarchy[d]![y]!.add(v);
      }

      await db.collection("timetable").add({
        "school": school,
        "department": dept,
        "year": year,
        "division": div,
        "batch": batch ?? "",
        "day": day,
        "startTime": startTime,
        "endTime": endTime,
        "subject": subject,
        "room": room,
        "facultyName": facultyName,
        "facultyCode": facultyCode,
      });

    }
  }

  // Sync Rooms
  for (String room in uniqueRooms) {
    // Keep metadata in rooms
    await db.collection("rooms").doc(room).set({
      "name": room
    }, SetOptions(merge: true));

    // Keep live tracking in room_status
    await db.collection("room_status").doc(room).set({
      "status": "Available",
      "currentFacultyName": "",
      "currentFacultyCode": "",
      "currentSubject": "",
      "currentDivision": "",
      "currentTimeSlot": "",
      "lastUpdated": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Sync Departments Hierarchy
  for (String dept in deptHierarchy.keys) {
    Map<String, dynamic> structure = {};
    deptHierarchy[dept]!.forEach((year, divSet) {
      var divList = divSet.toList();
      divList.sort();
      structure[year] = divList;
    });

    await db.collection("departments").doc(dept).set({
      "structure": structure
    }, SetOptions(merge: true));
  }

  print("Excel uploaded successfully and metadata synced!");
}