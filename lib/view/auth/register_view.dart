import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../service/storage_service.dart';
import 'package:flutter/material.dart';
import '../../service/auth_service.dart';
import '../../core/style/app_colors.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});
  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nickController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  File? _selectedDocument;
  String? _documentName;

  @override
  void dispose() {
    _nameController.dispose();
    _nickController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      setState(() {
        _selectedDocument = File(result.files.single.path!);
        _documentName = result.files.single.name;
      });
    }
  }

  void _handleRegister() async {
    if (_nameController.text.isEmpty || _nickController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun!")));
      return;
    }
    // Nick doğrulama: 3-20 karakter, sadece harf/rakam/alt çizgi
    final nickRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
    if (!nickRegex.hasMatch(_nickController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Kullanıcı adı 3-20 karakter olmalı, sadece harf, rakam ve _ içerebilir!"),
      ));
      return;
    }

    if (_selectedDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen öğrenci belgenizi yükleyin!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? result = await _authService.registerUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        nick: _nickController.text.trim(),
        storageService: _storageService,
        selectedFile: _selectedDocument,
      );

      if (!mounted) return;
      
      if (result == "success") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Kayıt Başarılı! Hesabınız 6 saat içinde onaylanacaktır."),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          )
        );
        Navigator.pop(context);
      } else {
        throw result ?? "Bir hata oluştu.";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textHeader), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_add_alt_1_rounded, size: 48, color: AppColors.primary),
                ),
                SizedBox(height: 24),
                Text("Kayıt Ol", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textHeader)),
                Text("K-HUB Ailesine Katıl", style: TextStyle(fontSize: 14, color: AppColors.textBody, fontWeight: FontWeight.w500)),
                SizedBox(height: 48),

                _buildInputLabel("Ad Soyad (Gizli - Sadece Admin Görür)"),
                _buildStitchTextField(controller: _nameController, hint: "Ahmet Yılmaz", icon: Icons.person_outline_rounded),
                SizedBox(height: 20),
                _buildInputLabel("Kullanıcı Adı (Nick)"),
                _buildStitchTextField(controller: _nickController, hint: "ahmet_42", icon: Icons.alternate_email_rounded),
                SizedBox(height: 20),
                _buildInputLabel("E-posta"),
                _buildStitchTextField(controller: _emailController, hint: "ogrenci@kku.edu.tr", icon: Icons.email_outlined),
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
                SizedBox(height: 20),
                _buildInputLabel("Öğrenci Belgesi (PDF veya Görsel)"),
                GestureDetector(
                  onTap: _pickDocument,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _selectedDocument != null ? AppColors.primary : Colors.transparent, width: 2),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Icon(_selectedDocument != null ? Icons.check_circle_rounded : Icons.file_upload_outlined, 
                             color: _selectedDocument != null ? Colors.green : AppColors.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _documentName ?? "Belge Seçin",
                            style: TextStyle(color: _selectedDocument != null ? AppColors.textHeader : AppColors.textBody.withValues(alpha: 0.7), fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 48),

                _isLoading
                    ? CircularProgressIndicator(color: AppColors.primary)
                    : GestureDetector(
                        onTap: _handleRegister,
                        child: Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 15, offset: Offset(0, 8))],
                          ),
                          alignment: Alignment.center,
                          child: Text("Hesap Oluştur", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: "Zaten hesabın var mı? ",
                      style: TextStyle(color: AppColors.textBody, fontSize: 14),
                      children: [
                        TextSpan(text: "Giriş Yap", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
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
