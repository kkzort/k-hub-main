import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/style/app_colors.dart';

class AdminStatsView extends StatelessWidget {
  const AdminStatsView({super.key});

  Future<Map<String, int>> _fetchStats() async {
    final fs = FirebaseFirestore.instance;
    final users = await fs.collection('users').get();
    final notes = await fs.collection('notes').get();
    final messages = await fs.collection('messages').get();
    final reports = await fs.collection('reports').get();
    final tools = await fs.collection('tools').get();
    final announcements = await fs.collection('announcements').get();

    int adminCount =
        users.docs.where((d) => (d.data())['role'] == 'admin').length;
    int totalLikes = 0;
    for (var doc in notes.docs) {
      final data = doc.data();
      if (data['likes'] is int) totalLikes += data['likes'] as int;
    }

    return {
      'users': users.docs.length,
      'admins': adminCount,
      'notes': notes.docs.length,
      'messages': messages.docs.length,
      'reports': reports.docs.length,
      'tools': tools.docs.length,
      'announcements': announcements.docs.length,
      'likes': totalLikes,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("İstatistikler", style: TextStyle(color: AppColors.textHeader)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        iconTheme: IconThemeData(color: AppColors.textHeader),
      ),
      backgroundColor: AppColors.background,
      body: FutureBuilder<Map<String, int>>(
        future: _fetchStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snapshot.data!;

          final cards = [
            _StatItem("Toplam Kullanıcı", s['users']!, Icons.people, Colors.blue),
            _StatItem("Admin Sayısı", s['admins']!, Icons.admin_panel_settings, AppColors.primary),
            _StatItem("Paylaşılan Notlar", s['notes']!, Icons.menu_book, Colors.orange),
            _StatItem("Toplam Mesaj", s['messages']!, Icons.chat_bubble, Colors.green),
            _StatItem("Toplam Beğeni", s['likes']!, Icons.favorite, Colors.red),
            _StatItem("Açık Şikayetler", s['reports']!, Icons.flag, Colors.deepOrange),
            _StatItem("Aktif Araçlar", s['tools']!, Icons.build, Colors.purple),
            _StatItem("Duyurular", s['announcements']!, Icons.campaign, Colors.teal),
          ];

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.3,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final item = cards[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(item.icon, color: item.color, size: 28),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "${item.value}",
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: item.color,
                                ),
                              ),
                            ),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _StatItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}
