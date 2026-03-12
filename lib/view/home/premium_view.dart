import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/style/app_colors.dart';
import '../../core/widgets/verified_badge.dart';

class PremiumView extends StatefulWidget {
  const PremiumView({super.key});

  @override
  State<PremiumView> createState() => _PremiumViewState();
}

class _PremiumViewState extends State<PremiumView> {
  bool _isActivating = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Future<void> _activatePremium() async {
    final user = _currentUser;
    if (user == null || _isActivating) return;

    setState(() => _isActivating = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isPremium': true,
        'premiumStatus': 'active',
        'premiumPlan': 'student_monthly',
        'premiumSource': 'app_manual',
        'premiumActivatedAt': FieldValue.serverTimestamp(),
        'premiumUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Premium aktif edildi. Mavi tik hesabina tanimlandi.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Premium aktif edilirken bir hata olustu.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Premium'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textHeader,
        ),
        body: Center(
          child: Text(
            'Premium icin once giris yapman gerekiyor.',
            style: TextStyle(color: AppColors.textBody),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final isPremium =
            userData?['isPremium'] == true ||
            userData?['premiumStatus'] == 'active';
        final activatedAt = userData?['premiumActivatedAt'] as Timestamp?;
        final activatedText = activatedAt == null
            ? 'Henüz aktif değil'
            : '${activatedAt.toDate().day}.${activatedAt.toDate().month}.${activatedAt.toDate().year}';

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Premium'),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textHeader,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF10203C),
                        Color(0xFF15386B),
                        Color(0xFF1DA1F2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1DA1F2).withValues(alpha: 0.18),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const VerifiedBadge(
                              type: 'verified',
                              size: 26,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isPremium ? 'AKTIF' : 'OGRENCI PLANI',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'K-Hub Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isPremium
                            ? 'Premium hesabin aktif. Mavi tik ve premium ozelliklerin hazir.'
                            : 'Mavi tik, premium rozet ve gelecek ekstra ozellikler icin ogrenci premium planini aktif et.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text(
                            '49,99 TL / ay',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.96),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Aktivasyon: $activatedText',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _PremiumInfoCard(
                  title: 'Aninda acilan premium haklari',
                  children: const [
                    _PremiumFeatureRow(
                      icon: Icons.verified_rounded,
                      title: 'Mavi tik',
                      subtitle:
                          'Premium alan ogrenciler profilde ve listelerde mavi tik alir.',
                    ),
                    _PremiumFeatureRow(
                      icon: Icons.visibility_outlined,
                      title: 'Tum profil ziyaretcileri',
                      subtitle:
                          'Ziyaret edenlerin tamamini blur olmadan gorebilirsin.',
                    ),
                    _PremiumFeatureRow(
                      icon: Icons.picture_as_pdf_outlined,
                      title: 'K-Bot AI',
                      subtitle:
                          'PDF ve fotograf yukleyip ozet cikarabilir, ana noktalar ve dokuman bazli soru-cevap alabilirsin.',
                    ),
                    _PremiumFeatureRow(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Premium altyapi',
                      subtitle:
                          'Ekstra ozellikler sonradan bu planin ustune kolayca eklenebilir.',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _PremiumInfoCard(
                  title: 'Yakinda eklenebilecek ekstralar',
                  children: const [
                    _PremiumFeatureRow(
                      icon: Icons.palette_outlined,
                      title: 'Ozel profil temalari',
                      subtitle:
                          'Profil kartinda premium gorunum ve vurgu renkleri.',
                    ),
                    _PremiumFeatureRow(
                      icon: Icons.forum_outlined,
                      title: 'Gelişmis mesaj avantajlari',
                      subtitle:
                          'Mesaj kutusunda ekstra filtre ve sabitleme ozellikleri.',
                    ),
                    _PremiumFeatureRow(
                      icon: Icons.star_outline_rounded,
                      title: 'Toplululuk avantajlari',
                      subtitle:
                          'Premium kullanicilara ozel rozet ve on plana cikma alanlari.',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (isPremium || _isActivating)
                        ? null
                        : _activatePremium,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DA1F2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      isPremium
                          ? 'Premium zaten aktif'
                          : _isActivating
                          ? 'Aktif ediliyor...'
                          : 'Premiumu baslat',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Not: Odeme entegrasyonu sonraki adimda App Store / Play Store satin alma altyapisina baglanabilir. Bu ekran premium durumunu simdiden hazirlar.',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PremiumInfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _PremiumInfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textHeader,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _PremiumFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PremiumFeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1DA1F2).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF1DA1F2), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textHeader,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textBody,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
