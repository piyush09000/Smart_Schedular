import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAddUser extends StatefulWidget {
  const AdminAddUser({super.key});

  @override
  State<AdminAddUser> createState() => _AdminAddUserState();
}

class _AdminAddUserState extends State<AdminAddUser> {

  final _formKey = GlobalKey<FormState>();

  String role = "faculty";
  String school = "engineering";
  String department = "CSE";

  final TextEditingController code = TextEditingController();
  final TextEditingController name = TextEditingController();
  final TextEditingController password = TextEditingController();

  void addUser() async {

    if (!_formKey.currentState!.validate()) return;

    await FirebaseFirestore.instance.collection("users").doc(code.text).set({
      "name": name.text,
      "role": role,
      "password": password.text,
      "school": school,
      "department": department
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User Added Successfully"))
    );

    code.clear();
    name.clear();
    password.clear();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Add User"),
        backgroundColor: const Color(0xFF1E40AF),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Form(
          key: _formKey,

          child: ListView(
            children: [

              DropdownButtonFormField(
                value: role,
                items: const [
                  DropdownMenuItem(value: "faculty", child: Text("Faculty")),
                  DropdownMenuItem(value: "hos", child: Text("HOS")),
                ],
                onChanged: (v) => setState(() => role = v!),
                decoration: const InputDecoration(labelText: "Role"),
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: code,
                decoration: const InputDecoration(labelText: "User Code (ID)"),
                validator: (v) => v!.isEmpty ? "Enter code" : null,
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: "Name"),
                validator: (v) => v!.isEmpty ? "Enter name" : null,
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: password,
                decoration: const InputDecoration(labelText: "Password"),
                validator: (v) => v!.isEmpty ? "Enter password" : null,
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField(
                value: school,
                items: const [
                  DropdownMenuItem(value: "engineering", child: Text("Engineering")),
                  DropdownMenuItem(value: "science", child: Text("Science")),
                  DropdownMenuItem(value: "business", child: Text("Business")),
                ],
                onChanged: (v) => setState(() => school = v!),
                decoration: const InputDecoration(labelText: "School"),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField(
                value: department,
                items: const [
                  DropdownMenuItem(value: "CSE", child: Text("CSE")),
                  DropdownMenuItem(value: "ECE", child: Text("ECE")),
                ],
                onChanged: (v) => setState(() => department = v!),
                decoration: const InputDecoration(labelText: "Department"),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: addUser,
                child: const Text("ADD USER"),
              )

            ],
          ),
        ),
      ),
    );
  }
}