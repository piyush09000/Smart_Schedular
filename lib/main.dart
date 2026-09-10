import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/splash_screen.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';

/// BACKGROUND HANDLER
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background message: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  /// ✅ INIT LOCAL NOTIFICATION (VERY IMPORTANT)
  await NotificationService.init();

  /// ✅ REQUEST FCM PERMISSION
  await FirebaseMessaging.instance.requestPermission();

  /// BACKGROUND HANDLER
  FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler);

  DatabaseService db = DatabaseService();

  runApp(MyApp(database: db));
}

class MyApp extends StatelessWidget {
  final DatabaseService database;

  const MyApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Scheduler and Management System',
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: SplashScreen(database: database),
    );
  }
}