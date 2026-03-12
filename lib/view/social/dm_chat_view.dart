import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/style/app_colors.dart';
import '../../service/dm_service.dart';
import '../../service/storage_service.dart';
import '../../core/widgets/verified_badge.dart';
import 'user_profile_view.dart';

class DmChatView extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserPhoto;
  final String otherUserId;

  const DmChatView({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserPhoto,
    required this.otherUserId,
  });

  @override
  State<DmChatView> createState() => _DmChatViewState();
}

class _DmChatViewState extends State<DmChatView> {
  final DmService _dmService = DmService();
  final StorageService _storageService = StorageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final currentUser = FirebaseAuth.instance.currentUser;

  // Reply state
  String? _replyToText;
  String? _replyToSender;

  // Media upload state
  bool _isUploading = false;

  // Auto-delete state
  int? _autoDeleteDays;

  // Verified badge state
  Map<String, dynamic>? _otherUserData;

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _dmService.markRead(widget.conversationId, currentUser!.uid);
      _dmService.markMessagesAsRead(widget.conversationId, currentUser!.uid);
    }
    _loadAutoDeleteSetting();
    _loadOtherUserData();
  }

  Future<void> _loadOtherUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();
      if (doc.exists && mounted) setState(() => _otherUserData = doc.data());
    } catch (_) {}
  }

  Future<void> _loadAutoDeleteSetting() async {
    final days = await _dmService.getAutoDeleteDays(widget.conversationId);
    if (mounted) setState(() => _autoDeleteDays = days);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setReply(String text, String sender) {
    setState(() {
      _replyToText = text;
      _replyToSender = sender;
    });
    _focusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyToText = null;
      _replyToSender = null;
    });
  }

  Future<void> _sendMessage({
    String? mediaUrl,
    String? mediaType,
    String? mediaName,
  }) async {
    final hasText = _messageController.text.trim().isNotEmpty;
    final hasMedia = mediaUrl != null;
    if ((!hasText && !hasMedia) || currentUser == null) return;

    final text = _messageController.text.trim();
    final replyText = _replyToText;
    final replySender = _replyToSender;
    _messageController.clear();
    _clearReply();

    String userName = 'Kullanıcı';
    try {
      final uDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (uDoc.exists) {
        userName = uDoc.data()?['name'] ?? userName;
      }
    } catch (_) {}

    await _dmService.sendMessage(
      conversationId: widget.conversationId,
      senderId: currentUser!.uid,
      senderName: userName,
      text: text,
      receiverId: widget.otherUserId,
      replyToText: replyText,
      replyToSender: replySender,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      mediaName: mediaName,
    );

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ===== MEDYA SEÇİCİ =====
  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _buildPickerOption(
                icon: Icons.camera_alt_rounded,
                color: AppColors.primary,
                label: 'Fotoğraf Çek',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              _buildPickerOption(
                icon: Icons.photo_library_rounded,
                color: const Color(0xFF34C759),
                label: 'Galeriden Seç',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              _buildPickerOption(
                icon: Icons.insert_drive_file_rounded,
                color: const Color(0xFF007AFF),
                label: 'Dosya Seç',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: AppColors.textHeader,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1920,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);
      final file = File(picked.path);
      final storagePath = 'chat_media/dm/${widget.conversationId}';
      final url = await _storageService.uploadChatMedia(file, storagePath);

      if (url != null && mounted) {
        await _sendMessage(
          mediaUrl: url,
          mediaType: 'image',
          mediaName: picked.name,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf gönderilemedi. Boyut sınırı: 5MB'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf seçilirken hata oluştu')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      if (pickedFile.path == null) return;

      setState(() => _isUploading = true);
      final file = File(pickedFile.path!);
      final ext = pickedFile.extension?.toLowerCase() ?? '';
      final bool isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
      final bool isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);

      String mediaType;
      if (isImage) {
        mediaType = 'image';
      } else if (isVideo) {
        mediaType = 'video';
      } else {
        mediaType = 'file';
      }

      final storagePath = 'chat_media/dm/${widget.conversationId}';
      final url = await _storageService.uploadChatMedia(
        file,
        storagePath,
        isVideo: isVideo,
      );

      if (url != null && mounted) {
        await _sendMessage(
          mediaUrl: url,
          mediaType: mediaType,
          mediaName: pickedFile.name,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Dosya gönderilemedi. Boyut sınırı: ${isVideo ? '10MB' : '5MB'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosya seçilirken hata oluştu')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ===== KAYBOLAN MESAJLAR AYARI =====
  void _showAutoDeleteSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Kaybolan Mesajlar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHeader,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Yeni mesajlar belirlenen süre sonra otomatik silinir.',
                style: TextStyle(fontSize: 13, color: AppColors.textBody),
              ),
              const SizedBox(height: 16),
              _buildAutoDeleteOption(ctx, null, 'Kapalı'),
              _buildAutoDeleteOption(ctx, 1, '1 Gün'),
              _buildAutoDeleteOption(ctx, 7, '7 Gün'),
              _buildAutoDeleteOption(ctx, 30, '30 Gün'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoDeleteOption(BuildContext ctx, int? days, String label) {
    final isSelected = _autoDeleteDays == days;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? AppColors.primary : AppColors.textTertiary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: AppColors.textHeader,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () async {
        Navigator.pop(ctx);
        await _dmService.setAutoDelete(widget.conversationId, days);
        if (mounted) setState(() => _autoDeleteDays = days);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        elevation: 0,
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileView(userId: widget.otherUserId),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.otherUserPhoto != null
                    ? NetworkImage(widget.otherUserPhoto!)
                    : null,
                backgroundColor: AppColors.primaryLight,
                child: widget.otherUserPhoto == null
                    ? Icon(Icons.person, size: 18, color: AppColors.primary)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.otherUserName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHeader,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_otherUserData != null) ...[
                      if (_otherUserData!['role'] == 'admin') ...[
                        const SizedBox(width: 4),
                        const VerifiedBadge(type: 'admin', size: 16),
                      ] else if (VerifiedBadge.hasBlueBadge(
                        _otherUserData,
                      )) ...[
                        const SizedBox(width: 4),
                        const VerifiedBadge(type: 'verified', size: 16),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textHeader),
            onSelected: (value) {
              if (value == 'auto_delete') {
                _showAutoDeleteSettings();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'auto_delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 20,
                      color: AppColors.textHeader,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Kaybolan Mesajlar',
                      style: TextStyle(color: AppColors.textHeader),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Auto-delete banner
          if (_autoDeleteDays != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: AppColors.primary.withValues(alpha: 0.08),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Mesajlar $_autoDeleteDays gün sonra kayboluyor',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Upload indicator
          if (_isUploading)
            LinearProgressIndicator(
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),

          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _dmService.getMessages(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Henüz mesaj yok. Bir mesaj gönderin!',
                      style: TextStyle(color: AppColors.textBody),
                    ),
                  );
                }

                // Mark as read
                if (currentUser != null) {
                  _dmService.markRead(widget.conversationId, currentUser!.uid);
                  _dmService.markMessagesAsRead(
                    widget.conversationId,
                    currentUser!.uid,
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;

                    // Client-side expiresAt filter
                    final expiresAt = data['expiresAt'] as Timestamp?;
                    if (expiresAt != null &&
                        expiresAt.toDate().isBefore(DateTime.now())) {
                      return const SizedBox.shrink();
                    }

                    final isMe = data['senderId'] == currentUser?.uid;
                    final t = data['createdAt'] as Timestamp?;
                    final timeStr = t != null
                        ? DateFormat('HH:mm').format(t.toDate())
                        : '';
                    final bool isRead = data['isRead'] == true;
                    final bool isDelivered = t != null;
                    final senderName = data['senderName'] ?? 'Kullanıcı';
                    final msgText = data['text'] ?? '';
                    final replyText = data['replyToText']?.toString();
                    final replySender = data['replyToSender']?.toString();
                    final mediaUrl = data['mediaUrl']?.toString();
                    final mediaType = data['mediaType']?.toString();
                    final mediaName = data['mediaName']?.toString();

                    // ─── Tarih Ayırıcı ───
                    Widget? dateSeparator;
                    if (t != null) {
                      final msgDate = t.toDate();
                      bool showDate = false;
                      if (index == messages.length - 1) {
                        showDate = true;
                      } else {
                        final nextData =
                            messages[index + 1].data() as Map<String, dynamic>;
                        final nextT = nextData['createdAt'] as Timestamp?;
                        if (nextT != null) {
                          final nextDate = nextT.toDate();
                          if (msgDate.year != nextDate.year ||
                              msgDate.month != nextDate.month ||
                              msgDate.day != nextDate.day) {
                            showDate = true;
                          }
                        } else {
                          showDate = true;
                        }
                      }
                      if (showDate) {
                        final now = DateTime.now();
                        String dateLabel;
                        if (msgDate.year == now.year &&
                            msgDate.month == now.month &&
                            msgDate.day == now.day) {
                          dateLabel = 'Bugün';
                        } else if (msgDate.year == now.year &&
                            msgDate.month == now.month &&
                            msgDate.day == now.day - 1) {
                          dateLabel = 'Dün';
                        } else {
                          dateLabel = DateFormat(
                            'd MMMM yyyy',
                            'tr',
                          ).format(msgDate);
                        }
                        dateSeparator = Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              dateLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textBody,
                              ),
                            ),
                          ),
                        );
                      }
                    }

                    return Column(
                      children: [
                        if (dateSeparator != null) dateSeparator,
                        _SwipeableMessage(
                          isMe: isMe,
                          onReply: () => _setReply(
                            msgText.isNotEmpty
                                ? msgText
                                : (mediaType == 'image'
                                      ? '📷 Fotoğraf'
                                      : mediaType == 'video'
                                      ? '🎥 Video'
                                      : '📄 Dosya'),
                            senderName,
                          ),
                          child: Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Builder(
                              builder: (context) {
                                final bool isMediaOnly =
                                    mediaUrl != null && msgText.isEmpty;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                        0.75,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMediaOnly
                                        ? Colors.transparent
                                        : (isMe
                                              ? AppColors.primary
                                              : AppColors.surface),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft: Radius.circular(
                                        isMe ? 18 : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMe ? 4 : 18,
                                      ),
                                    ),
                                    boxShadow: isMediaOnly
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: AppColors.shadow,
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Reply preview inside bubble
                                      if (replyText != null &&
                                          replyText.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            10,
                                            14,
                                            0,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isMe
                                                  ? Colors.white.withValues(
                                                      alpha: 0.14,
                                                    )
                                                  : AppColors.primaryLight,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border(
                                                left: BorderSide(
                                                  color: isMe
                                                      ? Colors.white70
                                                      : AppColors.primary,
                                                  width: 3,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  replySender ?? '',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isMe
                                                        ? Colors.white
                                                        : AppColors.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  replyText,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: isMe
                                                        ? Colors.white70
                                                        : AppColors.textBody,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                      // Media content — sadece medyalı + textsiz mesajlarda saat görselin üstünde
                                      if (mediaUrl != null && mediaType != null)
                                        Stack(
                                          children: [
                                            _buildMediaContent(
                                              mediaUrl: mediaUrl,
                                              mediaType: mediaType,
                                              mediaName: mediaName,
                                              isMe: isMe,
                                              isMediaOnly: msgText.isEmpty,
                                            ),
                                            // Saat + tik overlay — sadece text yoksa görselin üstünde
                                            if (msgText.isEmpty)
                                              Positioned(
                                                bottom: 6,
                                                right: 8,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.50,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        timeStr,
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                      if (isMe) ...[
                                                        const SizedBox(
                                                          width: 3,
                                                        ),
                                                        Icon(
                                                          isDelivered
                                                              ? Icons
                                                                    .done_all_rounded
                                                              : Icons
                                                                    .done_rounded,
                                                          size: 13,
                                                          color: isRead
                                                              ? const Color(
                                                                  0xFF34B7F1,
                                                                )
                                                              : Colors.white70,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),

                                      // Message text
                                      if (msgText.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            6,
                                            14,
                                            0,
                                          ),
                                          child: Text(
                                            msgText,
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : AppColors.textHeader,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),

                                      // Time + ticks — sadece medyasız veya textli mesajlarda alt kısımda
                                      if (mediaUrl == null ||
                                          msgText.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            4,
                                            14,
                                            10,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                timeStr,
                                                style: TextStyle(
                                                  color: isMe
                                                      ? Colors.white70
                                                      : Colors.grey,
                                                  fontSize: 10,
                                                ),
                                              ),
                                              if (isMe) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  isDelivered
                                                      ? Icons.done_all_rounded
                                                      : Icons.done_rounded,
                                                  size: 14,
                                                  color: isRead
                                                      ? const Color(0xFF34B7F1)
                                                      : Colors.white70,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      // Sadece medyalı + textsiz mesajlarda alt boşluk azalt
                                      if (mediaUrl != null && msgText.isEmpty)
                                        const SizedBox(height: 4),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Reply preview + Input
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reply preview bar
              if (_replyToText != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
                  color: AppColors.surface,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(color: AppColors.primary, width: 3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _replyToSender ?? '',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _replyToText!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textBody,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _clearReply,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Input bar
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: SafeArea(
                  bottom: true,
                  child: Row(
                    children: [
                      // Ataç butonu
                      GestureDetector(
                        onTap: _isUploading ? null : _showMediaPicker,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.attach_file_rounded,
                            color: _isUploading
                                ? AppColors.textTertiary
                                : AppColors.textBody,
                            size: 24,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            decoration: const InputDecoration(
                              hintText: 'Mesaj yaz...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isUploading ? null : _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isUploading
                                ? AppColors.textTertiary
                                : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== MEDYA İÇERİĞİ RENDER =====
  Widget _buildMediaContent({
    required String mediaUrl,
    required String mediaType,
    String? mediaName,
    required bool isMe,
    bool isMediaOnly = false,
  }) {
    if (mediaType == 'image') {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullScreenImageView(imageUrl: mediaUrl),
          ),
        ),
        child: ClipRRect(
          borderRadius: isMediaOnly
              ? BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                )
              : const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
          child: Image.network(
            mediaUrl,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 180,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.background,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                    color: isMe ? Colors.white70 : AppColors.primary,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              height: 100,
              color: isMe
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.background,
              child: Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  color: isMe ? Colors.white54 : AppColors.textTertiary,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      );
    } else if (mediaType == 'video') {
      return GestureDetector(
        onTap: () async {
          final uri = Uri.parse(mediaUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withValues(alpha: 0.12)
                : AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.15)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: isMe ? Colors.white : AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mediaName ?? 'Video',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isMe ? Colors.white : AppColors.textHeader,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Oynatmak için dokunun',
                      style: TextStyle(
                        color: isMe ? Colors.white60 : AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // File
      return GestureDetector(
        onTap: () async {
          final uri = Uri.parse(mediaUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withValues(alpha: 0.12)
                : AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.15)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.insert_drive_file_rounded,
                  color: isMe ? Colors.white : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mediaName ?? 'Dosya',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isMe ? Colors.white : AppColors.textHeader,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Açmak için dokunun',
                      style: TextStyle(
                        color: isMe ? Colors.white60 : AppColors.textTertiary,
                        fontSize: 11,
                      ),
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
}

/// Tam ekran görsel görüntüleyici
class _FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageView({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Swipeable message wrapper with WhatsApp-like swipe-to-reply animation
class _SwipeableMessage extends StatefulWidget {
  final Widget child;
  final bool isMe;
  final VoidCallback onReply;

  const _SwipeableMessage({
    required this.child,
    required this.isMe,
    required this.onReply,
  });

  @override
  State<_SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<_SwipeableMessage>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _hasTriggered = false;
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  static const double _triggerThreshold = 60.0;
  static const double _maxDrag = 80.0;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _resetAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _resetController, curve: Curves.easeOut));
    _resetController.addListener(() {
      setState(() => _dragOffset = _resetAnimation.value);
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
      if (widget.isMe) {
        // Kendi mesajımız: sola çek (negatif)
        if (_dragOffset > 0) _dragOffset = 0;
        if (_dragOffset < -_maxDrag) _dragOffset = -_maxDrag;
      } else {
        // Karşı tarafın mesajı: sağa çek (pozitif)
        if (_dragOffset < 0) _dragOffset = 0;
        if (_dragOffset > _maxDrag) _dragOffset = _maxDrag;
      }
    });

    // Haptic feedback when crossing threshold
    final absOffset = _dragOffset.abs();
    if (absOffset >= _triggerThreshold && !_hasTriggered) {
      _hasTriggered = true;
      HapticFeedback.mediumImpact();
    } else if (absOffset < _triggerThreshold) {
      _hasTriggered = false;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() >= _triggerThreshold) {
      widget.onReply();
    }
    // Animate back to 0
    _resetAnimation = Tween<double>(
      begin: _dragOffset,
      end: 0,
    ).animate(CurvedAnimation(parent: _resetController, curve: Curves.easeOut));
    _resetController.forward(from: 0);
    _hasTriggered = false;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset.abs() / _triggerThreshold).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          // Reply icon that appears during swipe
          Positioned(
            left: widget.isMe ? null : 4,
            right: widget.isMe ? 4 : null,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.5 + (progress * 0.5),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: progress * 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.reply_rounded,
                    color: AppColors.primary.withValues(alpha: progress),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          // Sliding message
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
