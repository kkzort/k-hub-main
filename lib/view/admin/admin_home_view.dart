import 'package:flutter/material.dart';
import 'admin_tools_view.dart';
import 'admin_announcements_view.dart';
import 'admin_users_view.dart';
import 'admin_chat_view.dart';
import 'admin_notes_view.dart';
import 'admin_reports_view.dart';
import 'admin_stats_view.dart';
import 'admin_events_view.dart';
import 'admin_event_preregistrations_view.dart';
import 'admin_polls_view.dart';
import 'admin_notifications_view.dart';
import 'admin_map_view.dart';
import 'admin_blacklist_view.dart';
import '../../core/style/app_colors.dart';

class AdminHomeView extends StatefulWidget {
  const AdminHomeView({super.key});

  @override
  State<AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<AdminHomeView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "K-Hub Admin Paneli",
          style: TextStyle(
            color: AppColors.textHeader,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hoş geldin kartı
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white70,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Hoş Geldiniz, Yönetici",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Buradan uygulamayı tam olarak yönetebilirsiniz.",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // İstatistikler (öne çıkan)
            _buildAdminCard(
              context,
              title: "İstatistikler",
              subtitle: "Kullanıcı, not, mesaj ve daha fazlası",
              icon: Icons.bar_chart,
              color: Colors.indigo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminStatsView()),
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Text(
                "İçerik Yönetimi",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            _buildAdminCard(
              context,
              title: "Duyuru & Fırsatlar",
              subtitle: "Slider ve fırsat kartlarını yönet",
              icon: Icons.campaign,
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminAnnouncementsView(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildAdminCard(
              context,
              title: "Etkinlik Yönetimi",
              subtitle: "Kampüs etkinliklerini ekle ve yönet",
              icon: Icons.event,
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminEventsView()),
              ),
            ),
            const SizedBox(height: 10),
            _buildAdminCard(
              context,
              title: "On Kayitlar",
              subtitle: "Etkinliklere kayit yaptiran ogrencileri gor",
              icon: Icons.how_to_reg_rounded,
              color: Colors.deepOrange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminEventPreRegistrationsView(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildAdminCard(
              context,
              title: "Araçları Yönet",
              subtitle: "Kampüs araçlarını aktif/pasif yap",
              icon: Icons.build,
              color: Colors.blueGrey,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminToolsView()),
              ),
            ),
            const SizedBox(height: 10),
            _buildAdminCard(
              context,
              title: "Harita Yönetimi",
              subtitle: "Mekanları ekle, düzenle, yorumları yönet",
              icon: Icons.map,
              color: Colors.cyan,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminMapView()),
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Text(
                "Kullanıcı & İletişim",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            _buildAdminCard(
              context,
              title: "Kullanıcıları Yönet",
              subtitle: "Rol değiştir, kullanıcı sil",
              icon: Icons.people,
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminUsersView()),
              ),
            ),
            const SizedBox(height: 10),
            _buildAdminCard(
              context,
              title: "Bildirim Gönder",
              subtitle: "Tüm kullanıcılara mesaj yayınla",
              icon: Icons.notifications_active,
              color: Colors.amber[800]!,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminNotificationsView(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildAdminCard(
              context,
              title: "Sohbet Yönetimi",
              subtitle: "Mesajları görüntüle ve sil",
              icon: Icons.chat,
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminChatView()),
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Text(
                "Moderasyon",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            _buildAdminCard(
              context,
              title: "Şikayet Yönetimi",
              subtitle: "Kullanıcı şikayetlerini incele ve işlem yap",
              icon: Icons.flag,
              color: Colors.red,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminReportsView()),
              ),
            ),
            const SizedBox(height: 10),
            _buildAdminCard(
              context,
              title: "Ders Notu Yönetimi",
              subtitle: "Paylaşılan notları listele ve sil",
              icon: Icons.menu_book,
              color: Colors.deepPurple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminNotesView()),
              ),
            ),
            const SizedBox(height: 10),
            _buildAdminCard(
              context,
              title: "Anket Yönetimi",
              subtitle: "Anket oluştur, sonuçları gör",
              icon: Icons.poll,
              color: Colors.pink,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPollsView()),
              ),
            ),
            const SizedBox(height: 10),
            _buildAdminCard(
              context,
              title: "Blacklist",
              subtitle: "Banlanan kullanicilari yonet",
              icon: Icons.block,
              color: Colors.redAccent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminBlacklistView()),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textHeader,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: AppColors.textBody),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
