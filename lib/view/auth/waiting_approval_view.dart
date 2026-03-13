import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/style/app_colors.dart';
import '../../service/auth_service.dart';
import '../auth/login_view.dart';
import '../auth/banned_view.dart';
import '../home/home_view.dart';

class WaitingApprovalView extends StatefulWidget {
  const WaitingApprovalView({super.key});

  @override
  State<WaitingApprovalView> createState() => _WaitingApprovalViewState();
}

class _WaitingApprovalViewState extends State<WaitingApprovalView> {
  final authService = AuthService();
  final currentUser = FirebaseAuth.instance.currentUser;
  StreamSubscription? _banSubscription;

  @override
  void initState() {
    super.initState();
    _listenBanStatus();
  }

  @override
  void dispose() {
    _banSubscription?.cancel();
    super.dispose();
  }

  void _listenBanStatus() {
    if (currentUser == null) return;
    _banSubscription = authService.banStatusStream(currentUser!.uid).listen((banInfo) {
      if (banInfo != null && mounted) {
        authService.signOut();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => BannedView(banReason: banInfo['banReason'])),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: currentUser != null
          ? authService.approvalStatusStream(currentUser!.uid)
          : const Stream.empty(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeView()),
              (route) => false,
            );
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pending_actions_rounded,
                      size: 80,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Kayıt İşlemi Devam Ediyor',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textHeader,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Öğrenci belgeniz yetkililerimiz tarafından incelenmektedir.\n\nBu işlem genellikle 6 saat içerisinde tamamlanır. Onaylandığında uygulamayı tam yetkiyle kullanabilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textBody,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 60),
                  GestureDetector(
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginView()),
                          (route) => false,
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Giriş Ekranına Dön',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
