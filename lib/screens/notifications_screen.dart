import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  final String userId;
  final String role;

  const NotificationsScreen({super.key, required this.userId, required this.role});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Notifications"),
          backgroundColor: const Color(0xFF1E40AF),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Personal"),
              Tab(text: "Broadcasts"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _NotificationList(queryField: 'targetId', queryValue: userId),
            _NotificationList(queryField: 'targetRole', queryValue: role),
          ],
        ),
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  final String queryField;
  final String queryValue;

  const _NotificationList({required this.queryField, required this.queryValue});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where(queryField, isEqualTo: queryValue)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text("No notifications yet", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
              ],
            ),
          );
        }

        var docs = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            bool isRead = data['isRead'] ?? false;
            String title = data['title'] ?? '';
            String body = data['body'] ?? '';
            DateTime? timestamp;
            if (data['timestamp'] != null) {
              timestamp = (data['timestamp'] as Timestamp).toDate();
            }

            return Dismissible(
              key: Key(doc.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) async {
                await NotificationService.deleteNotification(doc.id);
              },
              child: Card(
                elevation: isRead ? 0 : 3,
                color: isRead ? Colors.grey.shade100 : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isRead ? Colors.transparent : const Color(0xFF1E40AF).withAlpha(76),
                    width: 1.5,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isRead ? Colors.grey.shade300 : const Color(0xFF1E40AF),
                    child: Icon(
                      _iconForTitle(title),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(body, style: const TextStyle(fontSize: 13)),
                      if (timestamp != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ]
                    ],
                  ),
                  trailing: !isRead
                      ? IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: Color(0xFF1E40AF)),
                          tooltip: "Mark as read",
                          onPressed: () => NotificationService.markAsRead(doc.id),
                        )
                      : null,
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _iconForTitle(String title) {
    if (title.toLowerCase().contains('swap')) return Icons.swap_horiz;
    if (title.toLowerCase().contains('leave')) return Icons.event_busy;
    if (title.toLowerCase().contains('substitute')) return Icons.person_add_alt;
    return Icons.notifications;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
