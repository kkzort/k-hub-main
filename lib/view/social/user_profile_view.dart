import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/style/app_colors.dart';
import '../../service/post_service.dart';
import '../../service/friendship_service.dart';
import '../../service/dm_service.dart';
import 'profile_posts_scroll_view.dart';
import 'dm_chat_view.dart';
import '../../core/widgets/profile_photo_preview.dart';
import '../../core/widgets/verified_badge.dart';
import '../../service/profile_visit_service.dart';

class UserProfileView extends StatefulWidget {
  final String userId;
  const UserProfileView({super.key, required this.userId});

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  final PostService _postService = PostService();
  final FriendshipService _friendshipService = FriendshipService();
  final DmService _dmService = DmService();
  final ProfileVisitService _visitService = ProfileVisitService();
  final currentUser = FirebaseAuth.instance.currentUser;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    // Profil ziyareti kaydet
    if (currentUser != null) {
      _visitService.recordVisit(
        visitorId: currentUser!.uid,
        profileOwnerId: widget.userId,
      );
    }
  }

  Future<void> _checkAdmin() async {
    if (currentUser == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    final role = (doc.data() ?? {})['role'] ?? '';
    if (mounted && role == 'admin') setState(() => _isAdmin = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists)
            return const Center(child: Text('Kullanıcı bulunamadı.'));

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final isOwnProfile = currentUser?.uid == widget.userId;

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.textHeader,
                elevation: 0,
                pinned: true,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        userData['nick'] ?? userData['name'] ?? 'Profil',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHeader,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (VerifiedBadge.fromUserData(userData) != null) ...[
                      const SizedBox(width: 5),
                      VerifiedBadge.fromUserData(userData, size: 18)!,
                    ],
                  ],
                ),
                actions: [
                  if (_isAdmin && !isOwnProfile)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: AppColors.textHeader),
                      onSelected: (v) {
                        if (v == 'remove_photo') _adminRemoveProfilePhoto();
                      },
                      itemBuilder: (_) => [
                        if (userData['photoUrl'] != null)
                          const PopupMenuItem(
                            value: 'remove_photo',
                            child: Text(
                              'Profil Fotoğrafını Kaldır',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: _buildProfileHeader(userData, isOwnProfile),
              ),
              SliverToBoxAdapter(
                child: Divider(color: AppColors.divider, height: 1),
              ),
            ],
            body: _buildPostsGrid(),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData, bool isOwnProfile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Row(
            children: [
              PreviewableProfileAvatar(
                imageUrl: userData['photoUrl']?.toString(),
                radius: 42,
                backgroundColor: AppColors.primaryLight,
                placeholder: Icon(
                  Icons.person,
                  size: 42,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Name + Tik
          Row(
            children: [
              Flexible(
                child: Text(
                  userData['name'] ?? 'Kullanıcı',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textHeader,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (VerifiedBadge.fromUserData(userData) != null) ...[
                const SizedBox(width: 4),
                VerifiedBadge.fromUserData(userData)!,
              ],
            ],
          ),

          // Bio
          if (userData['bio'] != null && (userData['bio'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                userData['bio'],
                style: TextStyle(fontSize: 13, color: AppColors.textBody),
              ),
            ),

          // Action buttons
          if (!isOwnProfile) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _buildFriendshipButton()),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () => _openDm(userData),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textHeader,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Mesaj',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFriendshipButton() {
    if (currentUser == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: _friendshipService.watchFriendship(
        currentUser!.uid,
        widget.userId,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: _sendFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Takip Et',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }
        // Direkt takip sistemi — accepted ise takip ediliyor
        return SizedBox(
          height: 36,
          child: OutlinedButton(
            onPressed: _removeFriend,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textBody,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Takip Ediliyor',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }

  Future<void> _adminRemoveProfilePhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Profil Fotoğrafını Kaldır'),
        content: const Text(
          'Bu kullanıcının profil fotoğrafını tüm içeriklerden kaldırmak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaldır', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final fs = FirebaseFirestore.instance;
      final userId = widget.userId;

      // 1. Users koleksiyonundan kaldır
      await fs.collection('users').doc(userId).update({
        'photoUrl': FieldValue.delete(),
      });

      // 2. Posts — authorPhoto kaldır
      final posts = await fs
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .get();
      for (final doc in posts.docs) {
        await doc.reference.update({'authorPhoto': FieldValue.delete()});
      }

      // 3. Stories — authorPhoto kaldır
      final stories = await fs
          .collection('stories')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in stories.docs) {
        await doc.reference.update({'authorPhoto': FieldValue.delete()});
      }

      // 4. Friendships — requester veya receiver fotosu kaldır
      final friendsAsRequester = await fs
          .collection('friendships')
          .where('requesterId', isEqualTo: userId)
          .get();
      for (final doc in friendsAsRequester.docs) {
        await doc.reference.update({'requesterPhoto': FieldValue.delete()});
      }
      final friendsAsReceiver = await fs
          .collection('friendships')
          .where('receiverId', isEqualTo: userId)
          .get();
      for (final doc in friendsAsReceiver.docs) {
        await doc.reference.update({'receiverPhoto': FieldValue.delete()});
      }

      // 5. Notifications — fromUserPhoto kaldır
      final notifs = await fs
          .collection('notifications')
          .where('fromUserId', isEqualTo: userId)
          .get();
      for (final doc in notifs.docs) {
        await doc.reference.update({'fromUserPhoto': FieldValue.delete()});
      }

      // 6. Notes — userImage kaldır
      final notes = await fs
          .collection('notes')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in notes.docs) {
        await doc.reference.update({'userImage': FieldValue.delete()});
      }

      // 7. Messages — senderImage kaldır
      final userDoc = await fs.collection('users').doc(userId).get();
      final userEmail = userDoc.data()?['email'];
      if (userEmail != null) {
        final msgs = await fs
            .collection('messages')
            .where('senderEmail', isEqualTo: userEmail)
            .get();
        for (final doc in msgs.docs) {
          await doc.reference.update({'senderImage': FieldValue.delete()});
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil fotoğrafı tüm içeriklerden kaldırıldı'),
          ),
        );
        setState(() {});
      }
    }
  }

  Future<void> _sendFollow() async {
    if (currentUser == null) return;
    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    final otherDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    final myData = myDoc.data() ?? {};
    final otherData = otherDoc.data() ?? {};
    await _friendshipService.follow(
      requesterId: currentUser!.uid,
      receiverId: widget.userId,
      requesterName: myData['name'] ?? '',
      receiverName: otherData['name'] ?? '',
      requesterPhoto: myData['photoUrl'],
      receiverPhoto: otherData['photoUrl'],
    );
  }

  Future<void> _removeFriend() async {
    if (currentUser == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Takibi Bırak'),
        content: const Text('Bu kişiyi takip etmeyi bırakmak istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bırak', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true)
      await _friendshipService.removeFriend(currentUser!.uid, widget.userId);
  }

  Future<void> _openDm(Map<String, dynamic> otherUserData) async {
    if (currentUser == null) return;
    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    final myData = myDoc.data() ?? {};
    final convId = await _dmService.getOrCreateConversation(
      currentUserId: currentUser!.uid,
      currentUserName: myData['name'] ?? 'Ben',
      currentUserPhoto: myData['photoUrl'],
      otherUserId: widget.userId,
      otherUserName: otherUserData['name'] ?? 'Kullanıcı',
      otherUserPhoto: otherUserData['photoUrl'],
    );
    if (mounted)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DmChatView(
            conversationId: convId,
            otherUserName: otherUserData['name'] ?? 'Kullanıcı',
            otherUserPhoto: otherUserData['photoUrl'],
            otherUserId: widget.userId,
          ),
        ),
      );
  }

  Widget _buildPostsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: _postService.getUserPosts(widget.userId),
      builder: (context, snapshot) {
        final posts = snapshot.data?.docs ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grid_on, size: 48, color: AppColors.border),
                const SizedBox(height: 12),
                Text(
                  'Henüz gönderi yok',
                  style: TextStyle(color: AppColors.textBody),
                ),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final data = posts[index].data() as Map<String, dynamic>;
            final mediaUrls = data['mediaUrls'] != null
                ? List<String>.from(data['mediaUrls'])
                : [data['imageUrl'] ?? ''];
            final hasMultiple = mediaUrls.length > 1;
            final isVideo = data['isVideo'] == true;

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePostsScrollView(
                    userId: widget.userId,
                    posts: posts,
                    initialIndex: index,
                  ),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    mediaUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => Container(
                      color: AppColors.background,
                      child: Icon(Icons.broken_image, color: AppColors.border),
                    ),
                  ),
                  if (hasMultiple)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.collections_rounded,
                        color: Colors.white,
                        size: 18,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                    ),
                  if (isVideo)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 20,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
