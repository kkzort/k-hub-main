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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        VerifiedBadge(type: 'verified', size: 22),
                        SizedBox(width: 8),
                        Text(
                          'K-Bot Premium',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'K-Bot kullanimi premium plan ile acik. PDF/fotograf ozeti ve dokuman bazli soru-cevap ozellikleri burada.',
                      style: TextStyle(fontSize: 13.5, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _LockedFeatureRow(
                icon: Icons.picture_as_pdf_rounded,
                title: 'PDF ozeti',
                subtitle: 'Yukledigin dosyayi hizli ozetler.',
              ),
              const _LockedFeatureRow(
                icon: Icons.image_search_rounded,
                title: 'Gorsel analizi',
                subtitle: 'Not ve ekran goruntusunden metin cikarir.',
              ),
              const _LockedFeatureRow(
                icon: Icons.quiz_outlined,
                title: 'Dokuman sorulari',
                subtitle: 'Yuklenen icerik uzerinden soru-cevap yapar.',
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
                    backgroundColor: widget.kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Premiuma gec',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
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
            Icon(Icons.smart_toy_rounded, size: 22),
            SizedBox(width: 10),
            Text('K-Bot'),
          ],
        ),
        backgroundColor: widget.kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          if (_activeDocument != null || _isProcessingAttachment)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    _isProcessingAttachment
                        ? Icons.hourglass_bottom_rounded
                        : Icons.description_outlined,
                    color: widget.kPrimaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isProcessingAttachment
                          ? 'Dosya analiz ediliyor...'
                          : _activeDocumentLabel(),
                      style: TextStyle(
                        color: AppColors.textBody,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (_activeDocument != null && !_isProcessingAttachment)
                    TextButton(
                      onPressed: _clearDocumentContext,
                      child: const Text('Temizle'),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
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
                                : 'K-Bot yaziyor...',
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
                    margin: const EdgeInsets.only(bottom: 8),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.86,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? widget.kPrimaryColor : AppColors.surface,
                      border: isUser
                          ? null
                          : Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: isUser
                            ? const Radius.circular(14)
                            : Radius.zero,
                        bottomRight: isUser
                            ? Radius.zero
                            : const Radius.circular(14),
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
                                  'K-Bot',
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
                            fontSize: 13.5,
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
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _isProcessingAttachment
                      ? null
                      : _showAttachmentSheet,
                  icon: Icon(
                    Icons.add_circle_outline_rounded,
                    color: widget.kPrimaryColor,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: _activeDocument == null
                          ? 'Mesaj yaz...'
                          : 'Dokuman hakkinda sorunu yaz...',
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
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: widget.kPrimaryColor,
                  radius: 20,
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
