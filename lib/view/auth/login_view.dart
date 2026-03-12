import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../service/auth_service.dart';
import 'register_view.dart';
import 'waiting_approval_view.dart';
import 'banned_view.dart';
import '../home/home_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/style/app_colors.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email') ?? '';
    final rememberMe = prefs.getBool('remember_me') ?? false;
    if (rememberMe && savedEmail.isNotEmpty) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  Future<void> _savePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text.trim());
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.setBool('remember_me', false);
    }
  }

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen e-posta ve şifre girin!")));
      return;
    }
    setState(() => _isLoading = true);
    Map<String, dynamic> result = await _authService.signInUser(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    if (mounted) setState(() => _isLoading = false);
    if (result["status"] == "success") {
      await _savePreference();
      if (mounted) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          bool isApproved = await _authService.checkApprovalStatus(currentUser.uid);
          if (mounted) {
            if (isApproved) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeView(isAdmin: result["role"] == "admin")));
            } else {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaitingApprovalView()));
            }
          }
        }
      }
    } else if (result["status"] == "banned") {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BannedView(banReason: result["banReason"])));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${result["message"]}"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: Offset(0, 10))],
                  ),
                  child: Icon(Icons.school_rounded, size: 48, color: AppColors.isDark ? AppColors.textHeader : Colors.white),
                ),
                SizedBox(height: 24),
                Text("K-HUB", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textHeader, letterSpacing: 1.5)),
                Text("Kampüsün Dijital Hali", style: TextStyle(fontSize: 14, color: AppColors.textBody, fontWeight: FontWeight.w500)),
                SizedBox(height: 48),

                // Form Section
                _buildInputLabel("E-posta"),
                _buildStitchTextField(controller: _emailController, hint: "ogrenci@kku.edu.tr", icon: Icons.alternate_email_rounded),
                SizedBox(height: 20),
                _buildInputLabel("Şifre"),
                _buildStitchTextField(
                  controller: _passwordController,
                  hint: "••••••••",
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (val) => setState(() => _rememberMe = val ?? false),
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text("Beni Hatırla", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textHeader)),
                      ],
                    ),
                    TextButton(onPressed: () {}, child: Text("Şifremi Unuttum", style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold))),
                  ],
                ),
                SizedBox(height: 40),

                // Action Buttons
                _isLoading
                    ? CircularProgressIndicator(color: AppColors.primary)
                    : Column(
                        children: [
                          GestureDetector(
                            onTap: _handleLogin,
                            child: Container(
                              width: double.infinity,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 15, offset: Offset(0, 8))],
                              ),
                              alignment: Alignment.center,
                              child: Text("Giriş Yap", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          SizedBox(height: 24),
                          TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterView())),
                            child: RichText(
                              text: TextSpan(
                                text: "Hesabın yok mu? ",
                                style: TextStyle(color: AppColors.textBody, fontSize: 14),
                                children: [
                                  TextSpan(text: "Kayıt Ol", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 8, left: 4),
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textHeader)),
      ),
    );
  }

  Widget _buildStitchTextField({required TextEditingController controller, required String hint, required IconData icon, bool isPassword = false, bool obscureText = false, VoidCallback? onToggle}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(color: AppColors.textHeader),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textBody.withValues(alpha: 0.7), fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.primary.withValues(alpha: 0.7)),
          suffixIcon: isPassword ? IconButton(icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: AppColors.textBody), onPressed: onToggle) : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
