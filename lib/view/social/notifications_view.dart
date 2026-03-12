import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/style/app_colors.dart';
import 'user_profile_view.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // Sayfaya girince tüm bildirimleri okundu yap
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    if (currentUser == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('toUserId', isEqualTo: currentUser!.uid)
        .where('read', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.update({'read': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Bildirimler',
            style: TextStyle(
                color: AppColors.textHeader, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        elevation: 0,
      ),
      body: currentUser == null
          ? const Center(child: Text('Giriş yapmalısınız'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('toUserId', isEqualTo: currentUser!.uid)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none,
                            size: 64, color: AppColors.border),
                        const SizedBox(height: 16),
                        Text('Henüz bildirim yok',
                            style: TextStyle(
                                color: AppColors.textBody, fontSize: 16)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (context2, index2) =>
                      Divider(color: AppColors.divider, height: 1),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildNotificationTile(data);
                  },
                );
              },
            ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final fromName = data['fromUserName'] ?? 'Kullanıcı';
    final fromPhoto = data['fromUserPhoto'];
    final fromUserId = data['fromUserId'] ?? '';
    final isRead = data['read'] == true;
    final createdAt = data['createdAt'] as Timestamp?;
    final timeAgo = createdAt != null ? _timeAgo(createdAt.toDate()) : '';

    String message;
    IconData icon;
    Color iconColor;

    switch (type) {
      case 'follow':
        message = 'seni takip etmeye başladı';
        icon = Icons.person_add;
        iconColor = AppColors.primary;
        break;
      default:
        message = 'bir bildirim gönderdi';
        icon = Icons.notifications;
        iconColor = AppColors.textTertiary;
    }

    return ListTile(
      tileColor: isRead ? null : AppColors.primary.withValues(alpha: 0.05),
      leading: GestureDetector(
        onTap: () => _openProfile(fromUserId),
        child: CircleAvatar(
          radius: 22,
          backgroundImage: fromPhoto != null ? NetworkImage(fromPhoto) : null,
          backgroundColor: AppColors.primaryLight,
          child: fromPhoto == null
              ? Icon(Icons.person, size: 20, color: AppColors.primary)
              : null,
        ),
      ),
      title: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 14, color: AppColors.textHeader),
          children: [
            TextSpan(
              text: fromName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: ' $message',
              style: TextStyle(color: AppColors.textBody),
            ),
          ],
        ),
      ),
      subtitle: Text(timeAgo,
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
      trailing: Icon(icon, color: iconColor, size: 20),
      onTap: () => _openProfile(fromUserId),
    );
  }

  void _openProfile(String userId) {
    if (userId.isNotEmpty) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => UserProfileView(userId: userId)));
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    if (diff.inHours < 24) return '${diff.inHours}sa önce';
    if (diff.inDays < 7) return '${diff.inDays}g önce';
    return '${diff.inDays ~/ 7}h önce';
  }
}
