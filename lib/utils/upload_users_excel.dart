import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> uploadUsersExcel() async {

  try {

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null) {
      print("No file selected");
      return;
    }

    File file = File(result.files.single.path!);

    var bytes = file.readAsBytesSync();

    var excel = Excel.decodeBytes(bytes);

    FirebaseFirestore db = FirebaseFirestore.instance;

    for (var table in excel.tables.keys) {

      for (var row in excel.tables[table]!.rows.skip(1)) {

        String userCode = row[0]?.value?.toString() ?? "";

        if (userCode.isEmpty) continue;

        await db.collection("users").doc(userCode).set({

          "name": row[1]?.value?.toString() ?? "",
          "role": row[2]?.value?.toString() ?? "",
          "school": row[3]?.value?.toString() ?? "",
          "department": row[4]?.value?.toString() ?? "",
          "password": row[5]?.value?.toString() ?? "",

        });

      }
    }

    print("Users uploaded successfully");

  } catch (e) {

    print("Upload error: $e");

  }

}