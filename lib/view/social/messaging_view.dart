import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/style/app_colors.dart';
import '../../service/dm_service.dart';
import '../../service/storage_service.dart';
import '../../service/chat_settings_service.dart';
import '../../core/widgets/profile_photo_preview.dart';
import '../../core/widgets/verified_badge.dart';
// friendship_service used indirectly via Firestore queries
import 'dm_chat_view.dart';
import 'user_profile_view.dart';
import 'campus_chat_info_view.dart';

class MessagingView extends StatefulWidget {
  const MessagingView({super.key});

  @override
  State<MessagingView> createState() => _MessagingViewState();
}

class _MessagingViewState extends State<MessagingView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DmService _dmService = DmService();
  final StorageService _storageService = StorageService();
  final ChatSettingsService _chatSettingsService = ChatSettingsService();
  final currentUser = FirebaseAuth.instance.currentUser;
  bool _isCampusUploading = false;

  // DM search state
  final TextEditingController _dmSearchController = TextEditingController();
  String _dmSearchQuery = '';
  List<Map<String, dynamic>> _dmSearchResults = [];
  bool _isDmSearching = false;

  // User cache for verified badges
  final Map<String, Map<String, dynamic>?> _userCache = {};

  // Campus chat state
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  String? _replyToMessageId;
  String? _replyToText;
  String? _replyToSender;
  String? _replyToSenderEmail;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<Map<String, dynamic>?> _fetchUserData(String userId) async {
    if (_userCache.containsKey(userId)) return _userCache[userId];
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = doc.exists ? doc.data() : null;
      _userCache[userId] = data;
      return data;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _dmSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mesajlar'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        elevation: 0,
        actions: [
          // Genel sohbet bilgi butonu (sadece genel sohbet sekmesinde göster)
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              if (_tabController.index == 1) {
                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: currentUser == null
                      ? null
                      : FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser!.uid)
                            .get(),
                  builder: (context, snap) {
                    final isAdmin = snap.data?.data()?['role'] == 'admin';
                    return IconButton(
                      icon: Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.textHeader,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CampusChatInfoView(isAdmin: isAdmin),
                        ),
                      ),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textBody,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'DM'),
            Tab(text: 'Genel Sohbet'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildDmList(), _buildCampusChat()],
      ),
    );
  }

  // ===== DM SEARCH =====
  Future<void> _searchFollowedUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _dmSearchResults = [];
        _isDmSearching = false;
      });
      return;
    }
    setState(() => _isDmSearching = true);
    final q = query.trim().toLowerCase();

    // Takip edilen kullanıcıları bul
    final friendshipSnap = await FirebaseFirestore.instance
        .collection('friendships')
        .where('status', isEqualTo: 'accepted')
        .get();

    final followedUids = <String>[];
    for (final doc in friendshipSnap.docs) {
      final data = doc.data();
      if (data['requesterId'] == currentUser!.uid) {
        followedUids.add(data['receiverId']);
      } else if (data['receiverId'] == currentUser!.uid) {
        followedUids.add(data['requesterId']);
      }
    }

    if (followedUids.isEmpty) {
      setState(() {
        _dmSearchResults = [];
        _isDmSearching = false;
      });
      return;
    }

    // Kullanıcı bilgilerini getir ve filtrele (admin dahil)
    final userSnap = await FirebaseFirestore.instance.collection('users').get();

    final results = userSnap.docs
        .map((d) => {'uid': d.id, ...d.data()})
        .where(
          (u) =>
              followedUids.contains(u['uid']) &&
              (u['isApproved'] == true || u['role'] == 'admin') &&
              ((u['nick'] ?? '').toString().toLowerCase().contains(q) ||
                  (u['name'] ?? '').toString().toLowerCase().contains(q)),
        )
        .toList();

    setState(() {
      _dmSearchResults = results;
      _isDmSearching = false;
    });
  }

  Future<void> _startDmWith(Map<String, dynamic> otherUser) async {
    if (currentUser == null) return;
    final otherUid = otherUser['uid']?.toString() ?? '';
    if (otherUid.isEmpty) return;

    // Mevcut kullanıcı bilgilerini al
    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    final myData = myDoc.data() ?? {};

    final convId = await _dmService.getOrCreateConversation(
      currentUserId: currentUser!.uid,
      currentUserName: myData['nick'] ?? myData['name'] ?? '',
      currentUserPhoto: myData['photoUrl'],
      otherUserId: otherUid,
      otherUserName: otherUser['nick'] ?? otherUser['name'] ?? '',
      otherUserPhoto: otherUser['photoUrl'],
    );

    // Aramayı temizle
    _dmSearchController.clear();
    setState(() {
      _dmSearchQuery = '';
      _dmSearchResults = [];
    });

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DmChatView(
            conversationId: convId,
            otherUserName: otherUser['nick'] ?? otherUser['name'] ?? '',
            otherUserPhoto: otherUser['photoUrl'],
            otherUserId: otherUid,
          ),
        ),
      );
    }
  }

  // ===== DM LIST TAB =====
  Widget _buildDmList() {
    if (currentUser == null) {
      return const Center(child: Text('Giriş yapmanız gerekiyor.'));
    }

    return Column(
      children: [
        // Arama çubuğu
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _dmSearchController,
              onChanged: (val) {
                setState(() => _dmSearchQuery = val);
                _searchFollowedUsers(val);
              },
              decoration: InputDecoration(
                hintText: 'Takip ettiklerinde ara...',
                hintStyle: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
                suffixIcon: _dmSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: () {
                          _dmSearchController.clear();
                          setState(() {
                            _dmSearchQuery = '';
                            _dmSearchResults = [];
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),

        // Arama sonuçları
        if (_isDmSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_isDmSearching &&
            _dmSearchQuery.isNotEmpty &&
            _dmSearchResults.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Takip ettiklerinde sonuç bulunamadı',
              style: TextStyle(color: AppColors.textBody),
            ),
          ),
        if (_dmSearchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8)],
            ),
            child: Column(
              children: _dmSearchResults.map((u) {
                final nick = u['nick']?.toString() ?? '';
                final name = u['name']?.toString() ?? '';
                final photo = u['photoUrl']?.toString();
                return ListTile(
                  leading: PreviewableProfileAvatar(
                    imageUrl: photo,
                    radius: 20,
                    backgroundColor: AppColors.primaryLight,
                    placeholder: Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '@$nick',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHeader,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: name.isNotEmpty
                      ? Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textBody,
                          ),
                        )
                      : null,
                  trailing: Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  onTap: () => _startDmWith(u),
                );
              }).toList(),
            ),
          ),

        // Konuşma listesi
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _dmService.getConversations(currentUser!.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final conversations = snapshot.data?.docs ?? [];
              if (conversations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_outlined,
                        size: 64,
                        color: AppColors.border,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz mesaj yok',
                        style: TextStyle(
                          color: AppColors.textBody,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Takip ettiğin kişileri arayarak\nmesajlaşmaya başla!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final data =
                      conversations[index].data() as Map<String, dynamic>;
                  final participantNames = Map<String, String>.from(
                    data['participantNames'] ?? {},
                  );
                  final participantPhotos = Map<String, String?>.from(
                    data['participantPhotos'] ?? {},
                  );
                  final unreadCount = Map<String, int>.from(
                    data['unreadCount'] ?? {},
                  );

                  // Find the other user
                  final otherUserId = (data['participantIds'] as List)
                      .firstWhere(
                        (id) => id != currentUser!.uid,
                        orElse: () => '',
                      );
                  final otherName =
                      participantNames[otherUserId] ?? 'Kullanıcı';
                  final otherPhoto = participantPhotos[otherUserId];
                  final myUnread = unreadCount[currentUser!.uid] ?? 0;
                  final otherUnread = unreadCount[otherUserId] ?? 0;
                  final lastMessage = data['lastMessage'] ?? '';
                  final lastTime = data['lastMessageTime'] as Timestamp?;
                  final lastSenderId = data['lastMessageSenderId']?.toString();
                  final bool lastMessageIsMine =
                      lastSenderId == currentUser!.uid;
                  final bool lastMessageIsRead =
                      lastMessageIsMine && otherUnread == 0;

                  return ListTile(
                    leading: PreviewableProfileAvatar(
                      imageUrl: otherPhoto?.toString(),
                      radius: 24,
                      backgroundColor: AppColors.primaryLight,
                      placeholder: Icon(Icons.person, color: AppColors.primary),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileView(userId: otherUserId),
                        ),
                      ),
                    ),
                    title: FutureBuilder<Map<String, dynamic>?>(
                      future: _fetchUserData(otherUserId),
                      builder: (context, userSnapshot) {
                        final userData = userSnapshot.data;
                        final role = userData?['role'] ?? '';
                        return Row(
                          children: [
                            Flexible(
                              child: Text(
                                otherName,
                                style: TextStyle(
                                  fontWeight: myUnread > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: AppColors.textHeader,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (role == 'admin') ...[
                              const SizedBox(width: 4),
                              const VerifiedBadge(type: 'admin', size: 14),
                            ] else if (VerifiedBadge.hasBlueBadge(
                              userData,
                            )) ...[
                              const SizedBox(width: 4),
                              const VerifiedBadge(type: 'verified', size: 14),
                            ],
                          ],
                        );
                      },
                    ),
                    subtitle: Row(
                      children: [
                        if (lastMessageIsMine) ...[
                          Icon(
                            Icons.done_all_rounded,
                            size: 14,
                            color: lastMessageIsRead
                                ? const Color(0xFF34B7F1) // WhatsApp blue
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: myUnread > 0
                                  ? AppColors.textHeader
                                  : AppColors.textBody,
                              fontWeight: myUnread > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (lastTime != null)
                          Text(
                            _timeAgo(lastTime.toDate()),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textBody,
                            ),
                          ),
                        if (myUnread > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$myUnread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DmChatView(
                            conversationId: conversations[index].id,
                            otherUserName: otherName,
                            otherUserPhoto: otherPhoto,
                            otherUserId: otherUserId,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ===== CAMPUS CHAT TAB (moved from home_view.dart) =====
  Widget _buildCampusChat() {
    return Column(
      children: [
        Expanded(
          child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: currentUser == null
                ? null
                : FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser!.uid)
                      .get(),
            builder: (context, userSnap) {
              if (currentUser == null) {
                return const Center(child: Text('Sohbet için giriş yapın.'));
              }
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!userSnap.hasData || !userSnap.data!.exists) {
                return const Center(
                  child: Text('Kullanıcı bilgisi bulunamadı.'),
                );
              }

              final userData = userSnap.data!.data() ?? <String, dynamic>{};
              final bool isAdmin = userData['role'] == 'admin';
              final Timestamp? approvedAt =
                  userData['approvedAt'] as Timestamp?;
              final Timestamp? createdAt = userData['createdAt'] as Timestamp?;
              final DateTime chatStartAt = isAdmin
                  ? DateTime.fromMillisecondsSinceEpoch(0)
                  : (approvedAt?.toDate() ??
                        createdAt?.toDate() ??
                        DateTime.now());

              final Query messageQuery = FirebaseFirestore.instance
                  .collection('messages')
                  .where(
                    'createdAt',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(chatStartAt),
                  )
                  .orderBy('createdAt', descending: true);

              return StreamBuilder<QuerySnapshot>(
                stream: messageQuery.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          "Sohbet yüklenemedi: ${snapshot.error}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "Henüz mesaj yok.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _chatScrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final isMe = data['senderEmail'] == currentUser?.email;
                      final t = data['createdAt'] as Timestamp?;
                      final messageDate = t?.toDate() ?? DateTime.now();
                      final shouldShowDate = index == docs.length - 1
                          ? true
                          : !_isSameDay(
                              messageDate,
                              ((docs[index + 1].data()
                                              as Map<
                                                String,
                                                dynamic
                                              >)['createdAt']
                                          as Timestamp?)
                                      ?.toDate() ??
                                  DateTime.now(),
                            );
                      final timeStr = t != null
                          ? DateFormat('HH:mm').format(t.toDate())
                          : "";

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (shouldShowDate)
                            _buildChatDateSeparator(
                              _chatDateLabel(messageDate),
                            ),
                          _buildChatBubble(
                            messageId: docs[index].id,
                            data: data,
                            isMe: isMe,
                            timeStr: timeStr,
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),

        // Upload indicator
        if (_isCampusUploading)
          LinearProgressIndicator(
            backgroundColor: AppColors.background,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),

        // Input bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyToMessageId != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
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
                              children: [
                                Text(
                                  _replyToSender ?? "Öğrenci",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _replyToText ?? "",
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
                          IconButton(
                            onPressed: () => setState(() {
                              _replyToMessageId = null;
                              _replyToSender = null;
                              _replyToSenderEmail = null;
                              _replyToText = null;
                            }),
                            icon: const Icon(Icons.close, size: 18),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      // Ataç butonu (campus chat)
                      GestureDetector(
                        onTap: _isCampusUploading
                            ? null
                            : _showCampusMediaPicker,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.attach_file_rounded,
                            color: _isCampusUploading
                                ? AppColors.textTertiary
                                : AppColors.textBody,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          decoration: const InputDecoration(
                            hintText: "Mesaj yazın...",
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isCampusUploading ? null : _sendCampusMessage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isCampusUploading
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _sendCampusMessage({
    String? mediaUrl,
    String? mediaType,
    String? mediaName,
  }) async {
    final hasText = _chatController.text.trim().isNotEmpty;
    final hasMedia = mediaUrl != null;
    if ((!hasText && !hasMedia) || currentUser == null) return;

    String message = _chatController.text.trim();
    _chatController.clear();

    String userName = currentUser?.displayName ?? "Öğrenci";
    String? userImage;

    try {
      final uDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (uDoc.exists) {
        userName = uDoc.data()?['name'] ?? userName;
        userImage = uDoc.data()?['photoUrl'];
      }
    } catch (_) {}

    // expiresAt for campus chat
    Timestamp? expiresAt;
    try {
      final settings = await _chatSettingsService.getSettings();
      if (settings['autoDeleteEnabled'] == true) {
        final days = settings['autoDeleteDays'] as int? ?? 7;
        expiresAt = Timestamp.fromDate(
          DateTime.now().add(Duration(days: days)),
        );
      }
    } catch (_) {}

    await FirebaseFirestore.instance.collection('messages').add({
      'text': message,
      'senderId': currentUser!.uid,
      'senderEmail': currentUser?.email,
      'senderName': userName,
      'senderImage': userImage,
      'replyToMessageId': _replyToMessageId,
      'replyToText': _replyToText,
      'replyToSender': _replyToSender,
      'replyToEmail': _replyToSenderEmail,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'mediaName': mediaName,
      'expiresAt': expiresAt,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _replyToMessageId = null;
      _replyToSender = null;
      _replyToSenderEmail = null;
      _replyToText = null;
    });

    if (_chatScrollController.hasClients) {
      _chatScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ===== CAMPUS CHAT MEDYA SEÇİCİ =====
  void _showCampusMediaPicker() async {
    // Admin izin kontrolü
    try {
      final settings = await _chatSettingsService.getSettings();
      if (settings['mediaUploadEnabled'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Medya paylaşımı yönetici tarafından kapatılmıştır',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    } catch (_) {
      // Ayarlar okunamazsa varsayılan olarak engelle
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Medya paylaşımı yönetici tarafından kapatılmıştır',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
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
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Fotoğraf Çek',
                  style: TextStyle(
                    color: AppColors.textHeader,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCampusImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF34C759),
                    size: 24,
                  ),
                ),
                title: Text(
                  'Galeriden Seç',
                  style: TextStyle(
                    color: AppColors.textHeader,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCampusImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.insert_drive_file_rounded,
                    color: Color(0xFF007AFF),
                    size: 24,
                  ),
                ),
                title: Text(
                  'Dosya Seç',
                  style: TextStyle(
                    color: AppColors.textHeader,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCampusFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCampusImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1920,
      );
      if (picked == null) return;

      setState(() => _isCampusUploading = true);
      final file = File(picked.path);
      final url = await _storageService.uploadChatMedia(
        file,
        'chat_media/campus',
      );

      if (url != null && mounted) {
        _sendCampusMessage(
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
      if (mounted) setState(() => _isCampusUploading = false);
    }
  }

  Future<void> _pickCampusFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      if (pickedFile.path == null) return;

      setState(() => _isCampusUploading = true);
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

      final url = await _storageService.uploadChatMedia(
        file,
        'chat_media/campus',
        isVideo: isVideo,
      );

      if (url != null && mounted) {
        _sendCampusMessage(
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
      if (mounted) setState(() => _isCampusUploading = false);
    }
  }

  Widget _buildChatBubble({
    required String messageId,
    required Map<String, dynamic> data,
    required bool isMe,
    required String timeStr,
  }) {
    // Client-side expiresAt filter
    final expiresAt = data['expiresAt'] as Timestamp?;
    if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
      return const SizedBox.shrink();
    }

    final String sender = data['senderName'] ?? "Öğrenci";
    final String msg = data['text'] ?? "";
    final String senderEmail = (data['senderEmail'] ?? '').toString();
    final String? replyToText = data['replyToText']?.toString();
    final String? replyToSender = data['replyToSender']?.toString();
    final String? mediaUrl = data['mediaUrl']?.toString();
    final String? mediaType = data['mediaType']?.toString();
    final String? mediaName = data['mediaName']?.toString();

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              PreviewableProfileAvatar(
                imageUrl: data['senderImage']?.toString(),
                radius: 18,
                backgroundColor: AppColors.primaryLight,
                placeholder: Icon(
                  Icons.person,
                  size: 18,
                  color: AppColors.primary,
                ),
                onTap: () {
                  final sid = data['senderId']?.toString();
                  if (sid != null && sid.isNotEmpty) {
                    _showProfilePreview(sid);
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) > 250) {
                    setState(() {
                      _replyToMessageId = messageId;
                      _replyToSender = sender;
                      _replyToSenderEmail = senderEmail;
                      _replyToText = msg.isNotEmpty
                          ? msg
                          : (mediaType == 'image'
                                ? '📷 Fotoğraf'
                                : mediaType == 'video'
                                ? '🎥 Video'
                                : '📄 Dosya');
                    });
                  }
                },
                onLongPress: () {
                  if (msg.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: msg));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mesaj kopyalandı.')),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (replyToText != null && replyToText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.14)
                                  : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  replyToSender ?? "Öğrenci",
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
                                  replyToText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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

                      // Media content
                      if (mediaUrl != null && mediaType != null)
                        _buildCampusMediaContent(
                          mediaUrl: mediaUrl,
                          mediaType: mediaType,
                          mediaName: mediaName,
                          isMe: isMe,
                        ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              GestureDetector(
                                onTap: () {
                                  final sid = data['senderId']?.toString();
                                  if (sid != null && sid.isNotEmpty) {
                                    _showProfilePreview(sid);
                                  }
                                },
                                child: FutureBuilder<Map<String, dynamic>?>(
                                  future: data['senderId'] != null
                                      ? _fetchUserData(
                                          data['senderId'].toString(),
                                        )
                                      : Future.value(null),
                                  builder: (context, userSnap) {
                                    final uData = userSnap.data;
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          sender,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        if (uData?['role'] == 'admin') ...[
                                          const SizedBox(width: 3),
                                          const VerifiedBadge(
                                            type: 'admin',
                                            size: 12,
                                          ),
                                        ] else if (VerifiedBadge.hasBlueBadge(
                                          uData,
                                        )) ...[
                                          const SizedBox(width: 3),
                                          const VerifiedBadge(
                                            type: 'verified',
                                            size: 12,
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ),
                            if (!isMe) const SizedBox(height: 4),
                            if (msg.isNotEmpty)
                              Text(
                                msg,
                                style: TextStyle(
                                  color: isMe
                                      ? Colors.white
                                      : AppColors.textHeader,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.done_all_rounded,
                                color: Colors.white70,
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final sid = data['senderId']?.toString();
                  if (sid != null && sid.isNotEmpty) {
                    _showProfilePreview(sid);
                  }
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: (data['senderImage'] != null)
                      ? NetworkImage(data['senderImage'])
                      : null,
                  backgroundColor: AppColors.primaryLight,
                  child: (data['senderImage'] == null)
                      ? Icon(Icons.person, size: 18, color: AppColors.primary)
                      : null,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCampusMediaContent({
    required String mediaUrl,
    required String mediaType,
    String? mediaName,
    required bool isMe,
  }) {
    if (mediaType == 'image') {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _CampusFullScreenImageView(imageUrl: mediaUrl),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
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
          if (await canLaunchUrl(uri))
            await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      return GestureDetector(
        onTap: () async {
          final uri = Uri.parse(mediaUrl);
          if (await canLaunchUrl(uri))
            await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  void _showProfilePreview(String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Center(
                child: Text(
                  'Kullanıcı bulunamadı',
                  style: TextStyle(color: AppColors.textBody),
                ),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final photo = data['photoUrl']?.toString();
          final name = data['name']?.toString() ?? '';
          final nick = data['nick']?.toString() ?? '';
          final department = data['department']?.toString() ?? '';

          return Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
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
                  const SizedBox(height: 20),
                  PreviewableProfileAvatar(
                    imageUrl: photo,
                    radius: 40,
                    backgroundColor: AppColors.primaryLight,
                    placeholder: Icon(
                      Icons.person,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHeader,
                    ),
                  ),
                  if (nick.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '@$nick',
                      style: TextStyle(fontSize: 14, color: AppColors.textBody),
                    ),
                  ],
                  if (department.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      department,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileView(userId: userId),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Profili Gör',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textBody,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _chatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (_isSameDay(target, today)) return 'BUGÜN';
    if (_isSameDay(target, yesterday)) return 'DÜN';
    return DateFormat('dd.MM.yyyy').format(target);
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}sa';
    if (diff.inDays < 7) return '${diff.inDays}g';
    return DateFormat('dd.MM.yyyy').format(date);
  }
}

/// Tam ekran görsel görüntüleyici (campus chat)
class _CampusFullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const _CampusFullScreenImageView({required this.imageUrl});

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
