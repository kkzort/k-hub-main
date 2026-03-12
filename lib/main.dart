import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'view/auth/login_view.dart';
import 'view/auth/banned_view.dart';
import 'view/home/home_view.dart';
import 'service/auth_service.dart';
import 'service/notification_service.dart';
import 'view/auth/waiting_approval_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/style/app_colors.dart';
import 'firebase_options.dart';

// ═══ TEMALAR (Mavi-Turkuaz) ═══
final lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF0277BD),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0277BD),
    brightness: Brightness.light,
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF0F1724),
  ),
  scaffoldBackgroundColor: const Color(0xFFF8F9FC),
  cardColor: Colors.white,
  dividerColor: const Color(0xFFEEF0F5),
  textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
  iconTheme: const IconThemeData(color: Color(0xFF3D4A5C)),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF0F1724),
    elevation: 0,
    centerTitle: true,
    iconTheme: IconThemeData(color: Color(0xFF0F1724)),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xFF0277BD) : null),
    trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xFF0277BD).withValues(alpha: 0.5) : null),
  ),
  useMaterial3: true,
);

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF29B6F6),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF29B6F6),
    brightness: Brightness.dark,
    surface: const Color(0xFF131820),
    onSurface: const Color(0xFFF0F0F0),
  ),
  scaffoldBackgroundColor: const Color(0xFF0A0D10),
  cardColor: const Color(0xFF131820),
  dividerColor: const Color(0xFF161B24),
  textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
  iconTheme: const IconThemeData(color: Color(0xFF8A95A3)),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF131820),
    foregroundColor: Color(0xFFF0F0F0),
    elevation: 0,
    centerTitle: true,
    iconTheme: IconThemeData(color: Color(0xFFF0F0F0)),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xFF29B6F6) : null),
    trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xFF29B6F6).withValues(alpha: 0.5) : null),
  ),
  useMaterial3: true,
);


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Debug: Firebase bağlantı kontrolü
  if (kDebugMode) {
    final app = Firebase.app();
    debugPrint('[Firebase] projectId=${app.options.projectId}');
    debugPrint('[Firebase] appId=${app.options.appId}');
    debugPrint('[Firebase] storageBucket=${app.options.storageBucket}');
  }

  // Arka plan bildirim handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const KHubApp());
}

class KHubApp extends StatelessWidget {
  const KHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'K-Hub',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
        );
      },
    );
  }

}

/// Açılış ekranı
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    // Bildirimleri başlat
    try {
      await NotificationService().initialize();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final currentUser = FirebaseAuth.instance.currentUser;

    // Firebase Auth oturumu açıksa VE "Beni Hatırla" aktifse
    if (rememberMe && currentUser != null) {
      final authService = AuthService();
      String role = 'student';
      try {
        final banInfo = await authService.getBanInfo(currentUser.uid);
        if (banInfo != null) {
          await authService.signOut();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => BannedView(banReason: banInfo['banReason'])),
            );
          }
          return;
        }
        role = await authService.getUserRole(currentUser.uid);
      } catch (_) {}

      if (mounted) {
        // Onay durumunu kontrol et
        bool isApproved = await authService.checkApprovalStatus(currentUser.uid);
        
        if (mounted) {
          if (isApproved) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeView(isAdmin: role == 'admin')));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaitingApprovalView()));
          }
        }
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginView()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.5, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.elasticOut,
              builder: (context, val, child) {
                return Transform.scale(
                  scale: val,
                  child: child,
                );
              },
              child: Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.school_rounded, 
                  size: 100, 
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(height: 30),
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              builder: (context, val, child) {
                return Opacity(
                  opacity: val,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - val)),
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  Text(
                    "K-HUB", 
                    style: TextStyle(
                      fontSize: 42, 
                      fontWeight: FontWeight.w900, 
                      color: AppColors.primary, 
                      letterSpacing: 4
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Kırıkkale Üniversitesi", 
                    style: TextStyle(
                      fontSize: 16, 
                      color: AppColors.textBody, 
                      fontWeight: FontWeight.w600, 
                      letterSpacing: 1.5
                    ),
                  ),
                  SizedBox(height: 60),
                  CircularProgressIndicator(
                    color: AppColors.primary, 
                    strokeWidth: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
