import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static String? _currentUserOrRole;

  static Future<void> init() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: android);

    await _notifications.initialize(settings);

    /// ✅ ANDROID 13+ PERMISSION
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showNotification(
      String title, String body) async {

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'lecture_channel',
      'Lecture Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecond, // unique ID to not overwrite
      title,
      body,
      details,
    );
  }

  /// Write a notification to Firestore targeting a specific user ID
  static Future<void> sendToUser(String userId, String title, String body) async {
    await _db.collection('notifications').add({
      'targetId': userId,
      'title': title,
      'body': body,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Write a notification to Firestore targeting a specific role
  static Future<void> sendToRole(String role, String title, String body) async {
    await _db.collection('notifications').add({
      'targetRole': role,
      'title': title,
      'body': body,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Listen for incoming notifications in Firestore for the current user
  /// Triggers a local notification when a new document is added.
  static void startListening(String userId, String role) {
    if (_currentUserOrRole == userId) return;
    _currentUserOrRole = userId;

    // Listen to personal notifications
    _db.collection('notifications')
      .where('targetId', isEqualTo: userId)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            var data = change.doc.data();
            if (data != null && data['timestamp'] != null) {
              Timestamp ts = data['timestamp'];
              if (DateTime.now().difference(ts.toDate()).inMinutes < 2) {
                 showNotification(data['title'], data['body']);
              }
            }
          }
        }
      });

    // Listen to role-based notifications
    _db.collection('notifications')
      .where('targetRole', isEqualTo: role)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            var data = change.doc.data();
            if (data != null && data['timestamp'] != null) {
              Timestamp ts = data['timestamp'];
              if (DateTime.now().difference(ts.toDate()).inMinutes < 2) {
                 showNotification(data['title'], data['body']);
              }
            }
          }
        }
      });
  }

  /// Mark notification as read
  static Future<void> markAsRead(String docId) async {
    await _db.collection('notifications').doc(docId).update({'isRead': true});
  }

  /// Delete notification
  static Future<void> deleteNotification(String docId) async {
    await _db.collection('notifications').doc(docId).delete();
  }
}