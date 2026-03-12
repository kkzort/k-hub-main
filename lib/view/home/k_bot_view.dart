import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/style/app_colors.dart';
import '../../core/widgets/verified_badge.dart';
import '../../service/kbot_service.dart';
import 'premium_view.dart';

class KBotView extends StatefulWidget {
  final Color kPrimaryColor;

  const KBotView({super.key, required this.kPrimaryColor});

  @override
  State<KBotView> createState() => _KBotViewState();
}

class _KBotViewState extends State<KBotView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final KBotService _kbotService = KBotService();
  final List<Map<String, dynamic>> _messages = [];

  bool _isTyping = false;
  bool _isProcessingAttachment = false;
  KBotDocumentAnalysis? _activeDocument;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'text':
          'Merhaba! Ben K-Bot.\n\nPremium kullanicilar icin PDF ve fotograf ozetleri cikarabilir, yukledigin dokuman uzerinden soru cevap yapabilir ve genel bir ogrenim asistani gibi yardimci olabilirim.',
      'isUser': false,
      'time': DateTime.now(),
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _hasPremiumAccess(Map<String, dynamic>? userData) {
    return userData?['role'] == 'admin' ||
        userData?['isPremium'] == true ||
        userData?['premiumStatus'] == 'active';
  }

  Future<void> _pickPdf() async {
    if (_isProcessingAttachment) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );

    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;

    final file = File(picked.path!);
    await _analyzeAttachment(
      userMessage: 'PDF yuklendi: ${picked.name}',
      analyzer: () => _kbotService.analyzePdf(file, fileName: picked.name),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isProcessingAttachment) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 100,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final fileName = picked.name.isNotEmpty
        ? picked.name
        : picked.path.split('/').last;

    await _analyzeAttachment(
      userMessage: source == ImageSource.camera
          ? 'Fotograf cekildi: $fileName'
          : 'Fotograf secildi: $fileName',
      analyzer: () => _kbotService.analyzeImage(file, fileName: fileName),
    );
  }

  Future<void> _analyzeAttachment({
    required String userMessage,
    required Future<KBotDocumentAnalysis> Function() analyzer,
  }) async {
    setState(() {
      _isProcessingAttachment = true;
      _isTyping = true;
      _messages.add({
        'text': userMessage,
        'isUser': true,
        'time': DateTime.now(),
      });
    });
    _scrollToBottom();

    try {
      final analysis = await analyzer();
      if (!mounted) return;
      setState(() {
        _activeDocument = analysis;
        _isProcessingAttachment = false;
        _isTyping = false;
        _messages.add({
          'text': _kbotService.buildDocumentSummaryMessage(analysis),
          'isUser': false,
          'time': DateTime.now(),
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingAttachment = false;
        _isTyping = false;
        _messages.add({
          'text': 'Dosya okunurken bir sorun oldu: $e',
          'isUser': false,
          'time': DateTime.now(),
        });
      });
    }

    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'isUser': true, 'time': DateTime.now()});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 450));
    final response = _kbotService.replyToPrompt(
      text,
      document: _activeDocument,
    );

    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add({
        'text': response,
        'isUser': false,
        'time': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  void _clearDocumentContext() {
    setState(() {
      _activeDocument = null;
      _messages.add({
        'text':
            'Yuklu dokuman baglami temizlendi. Istersen yeni bir PDF veya fotograf yukleyebilir ya da genel sohbete devam edebilirsin.',
        'isUser': false,
        'time': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  void _usePrompt(String prompt) {
    _controller.text = prompt;
    _sendMessage();
  }

  void _showAttachmentSheet() {
    if (_isProcessingAttachment) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: widget.kPrimaryColor,
                  ),
                  title: const Text('PDF sec'),
                  subtitle: const Text('Dokuman yukleyip ozet cikar'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPdf();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: widget.kPrimaryColor,
                  ),
                  title: const Text('Galeriden fotograf sec'),
                  subtitle: const Text('Not, slayt veya ekran goruntusu tara'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_camera_outlined,
                    color: widget.kPrimaryColor,
                  ),
                  title: const Text('Kamera ile cek'),
                  subtitle: const Text('Anlik fotograf cekip ozet al'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _activeDocumentLabel() {
    final document = _activeDocument;
    if (document == null) {
      return 'PDF veya fotograf yukleyip ozet cikarabilir ya da dogrudan sohbete baslayabilirsin.';
    }

    if (document.isPdf) {
      return 'Aktif dokuman: ${document.fileName} (${document.unitCount} ${document.unitLabel})';
    }

    return 'Aktif gorsel: ${document.fileName}';
  }

  Widget _buildLockedState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('K-Bot'),
        backgroundColor: widget.kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0F274A),
                    Color(0xFF144782),
                    Color(0xFF1DA1F2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VerifiedBadge(type: 'verified', size: 24),
                      SizedBox(width: 8),
                      Text(
                        'K-Bot Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Premium kullanicilar PDF ve fotograf ozetleri cikarabilir, yukledigi dokumanlar uzerinden soru sorabilir ve K-Bot ile daha gelismis sekilde sohbet edebilir.',
                    style: TextStyle(
                      color: Colors.white,
                      height: 1.45,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _LockedFeatureRow(
              icon: Icons.picture_as_pdf_rounded,
              title: 'PDF ozetleri',
              subtitle: 'Yuklenen PDF icin hizli ozet ve ana noktalar',
            ),
            _LockedFeatureRow(
              icon: Icons.photo_library_outlined,
              title: 'Fotograf ozetleri',
              subtitle:
                  'Not, slayt ve ekran goruntusundeki metni ozetle ve ana basliklari cikar',
            ),
            _LockedFeatureRow(
              icon: Icons.quiz_outlined,
              title: 'Dokuman bazli soru-cevap',
              subtitle: 'Yukleme sonrasi icerik uzerinden soru sor',
            ),
            _LockedFeatureRow(
              icon: Icons.smart_toy_outlined,
              title: 'Genel amacli K-Bot sohbeti',
              subtitle: 'Cihaz ici premium ogrenim asistani deneyimi',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PremiumView()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DA1F2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Premium al ve K-Bot ac',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 22),
            SizedBox(width: 8),
            Text('K-Bot'),
          ],
        ),
        backgroundColor: widget.kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: widget.kPrimaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Premium K-Bot',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textHeader,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _activeDocumentLabel(),
                  style: TextStyle(
                    color: AppColors.textBody,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _isProcessingAttachment ? null : _pickPdf,
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.kPrimaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text('PDF sec'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isProcessingAttachment
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textHeader,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Fotograf sec'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isProcessingAttachment
                          ? null
                          : () => _pickImage(ImageSource.camera),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textHeader,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Kamera'),
                    ),
                    if (_activeDocument != null)
                      OutlinedButton.icon(
                        onPressed: _clearDocumentContext,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textHeader,
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Belge kaldir'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_messages.length <= 2)
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _PromptChip(
                      label: 'Ne yapabiliyorsun?',
                      onTap: () => _usePrompt('Ne yapabiliyorsun?'),
                    ),
                    _PromptChip(
                      label: 'Calisma plani yap',
                      onTap: () => _usePrompt('Bana calisma plani yap'),
                    ),
                    _PromptChip(
                      label: _activeDocument == null
                          ? 'Fotograf ozeti'
                          : 'Ana noktalar',
                      onTap: () => _usePrompt(
                        _activeDocument == null
                            ? 'Fotograf yuklersem nasil ozet cikartirsin?'
                            : 'Ana noktalar neler?',
                      ),
                    ),
                    _PromptChip(
                      label: 'Soru hazirla',
                      onTap: () => _usePrompt('Bu konudan soru hazirla'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.kPrimaryColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isProcessingAttachment
                                ? 'Dosya okunuyor...'
                                : 'K-Bot dusunuyor...',
                            style: TextStyle(
                              color: AppColors.textBody,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final message = _messages[index];
                final isUser = message['isUser'] as bool;

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? widget.kPrimaryColor : AppColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser
                            ? const Radius.circular(16)
                            : Radius.zero,
                        bottomRight: isUser
                            ? Radius.zero
                            : const Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 14,
                                  color: widget.kPrimaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'K-Bot Premium',
                                  style: TextStyle(
                                    color: widget.kPrimaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          message['text'] as String,
                          style: TextStyle(
                            color: isUser
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 5),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _isProcessingAttachment
                      ? null
                      : _showAttachmentSheet,
                  icon: Icon(
                    Icons.attach_file_rounded,
                    color: widget.kPrimaryColor,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: _activeDocument == null
                          ? 'K-Bot\'a bir sey sor...'
                          : 'PDF, fotograf veya genel sohbet icin mesaj yaz...',
                      hintStyle: TextStyle(color: AppColors.textBody),
                      fillColor: AppColors.background,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: widget.kPrimaryColor,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    if (user == null) {
      return _buildLockedState();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        if (!_hasPremiumAccess(userData)) {
          return _buildLockedState();
        }
        return _buildMainView();
      },
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: onTap,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: AppColors.border),
        label: Text(
          label,
          style: TextStyle(
            color: AppColors.textHeader,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _LockedFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _LockedFeatureRow({
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textBody,
                    height: 1.35,
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
