import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../core/style/app_colors.dart';
import '../../core/widgets/profile_photo_preview.dart';
import '../../service/post_service.dart';
import '../../service/story_service.dart';
import '../../core/widgets/verified_badge.dart';
import 'story_viewer_view.dart';
import 'create_story_view.dart';
import 'create_post_view.dart';
import 'post_detail_view.dart';
import 'messaging_view.dart';
import 'user_profile_view.dart';
import 'notifications_view.dart';

class SocialFeedView extends StatefulWidget {
  const SocialFeedView({super.key});

  @override
  State<SocialFeedView> createState() => _SocialFeedViewState();
}

class _SocialFeedViewState extends State<SocialFeedView> {
  final PostService _postService = PostService();
  final StoryService _storyService = StoryService();
  final currentUser = FirebaseAuth.instance.currentUser;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
          child: Row(
            children: [
              Text(
                "K-Hub",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeader,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _showAddMenu,
                icon: Icon(
                  Icons.add_box_outlined,
                  color: AppColors.textHeader,
                  size: 26,
                ),
              ),
              // Bildirimler ikonu
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('toUserId', isEqualTo: currentUser?.uid ?? '')
                    .where('read', isEqualTo: false)
                    .snapshots(),
                builder: (ctx, snap) {
                  final unreadCount = snap.data?.docs.length ?? 0;
                  return IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsView(),
                      ),
                    ),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          color: AppColors.textHeader,
                          size: 26,
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              // DM ikonu
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('conversations')
                    .where(
                      'participants',
                      arrayContains: currentUser?.uid ?? '',
                    )
                    .snapshots(),
                builder: (ctx, snap) {
                  int totalUnread = 0;
                  if (snap.hasData) {
                    for (final doc in snap.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final unreadMap = Map<String, int>.from(
                        data['unreadCount'] ?? {},
                      );
                      totalUnread += unreadMap[currentUser?.uid ?? ''] ?? 0;
                    }
                  }
                  return IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MessagingView()),
                    ),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.send_outlined,
                          color: AppColors.textHeader,
                          size: 24,
                        ),
                        if (totalUnread > 0)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DA1F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                totalUnread > 99 ? '99+' : '$totalUnread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildStoryBar()),
                SliverToBoxAdapter(
                  child: Divider(color: AppColors.divider, height: 1),
                ),
                _buildPostFeed(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassStrong,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(color: AppColors.glassBorder, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                    Text(
                      'Oluştur',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeader,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildMenuTile(
                      icon: Icons.auto_stories_rounded,
                      title: 'Hikaye Ekle',
                      subtitle: '24 saat sonra kaybolan fotoğraf veya video',
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateStoryView(),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuTile(
                      icon: Icons.grid_on_rounded,
                      title: 'Gönderi Ekle',
                      subtitle:
                          'Fotoğraf veya video paylaş, çoklu seçim yapabilirsin',
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreatePostView(),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textHeader,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryBar() {
    return SizedBox(
      height: 110,
      child: StreamBuilder<QuerySnapshot>(
        stream: _storyService.getActiveStories(),
        builder: (context, snapshot) {
          final stories = snapshot.data?.docs ?? [];
          final Map<String, List<QueryDocumentSnapshot>> grouped = {};
          for (final doc in stories) {
            final data = doc.data() as Map<String, dynamic>;
            grouped.putIfAbsent(data['authorId'] ?? '', () => []).add(doc);
          }
          // Kendi storylerini ayır
          final myStories = grouped.remove(currentUser?.uid ?? '');
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              _buildMyStoryButton(myStories),
              ...grouped.entries.map((entry) {
                final authorStories = entry.value;
                final firstData =
                    authorStories.first.data() as Map<String, dynamic>;
                final hasViewed =
                    currentUser != null &&
                    authorStories.every((s) {
                      final d = s.data() as Map<String, dynamic>;
                      return List<String>.from(
                        d['viewedBy'] ?? [],
                      ).contains(currentUser!.uid);
                    });
                return _buildStoryAvatar(
                  name: firstData['authorName'] ?? '',
                  photoUrl: firstData['authorPhoto'],
                  hasViewed: hasViewed,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryViewerView(stories: authorStories),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  /// Instagram tarzı "Hikaye" butonu — kendi storyn varsa görüntüle, yoksa ekle
  Widget _buildMyStoryButton(List<QueryDocumentSnapshot>? myStories) {
    final bool hasStory = myStories != null && myStories.isNotEmpty;
    return GestureDetector(
      onTap: () {
        if (hasStory) {
          // Kendi storyni görüntüle
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoryViewerView(stories: myStories),
            ),
          );
        } else {
          // Yeni story oluştur
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateStoryView()),
          ).then((_) => setState(() {}));
        }
      },
      onLongPress: hasStory
          ? () {
              // Uzun basınca yeni story ekle (storyn varken de ekleyebilsin)
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateStoryView()),
              ).then((_) => setState(() {}));
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            Stack(
              children: [
                if (hasStory)
                  // Kendi storyn var — gradient çerçeveli profil fotoğrafı
                  Container(
                    width: 68,
                    height: 68,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, Colors.orange],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage:
                          (myStories.first.data()
                                  as Map<String, dynamic>)['authorPhoto'] !=
                              null
                          ? NetworkImage(
                              (myStories.first.data()
                                  as Map<String, dynamic>)['authorPhoto'],
                            )
                          : null,
                      backgroundColor: AppColors.primaryLight,
                      child:
                          (myStories.first.data()
                                  as Map<String, dynamic>)['authorPhoto'] ==
                              null
                          ? Icon(
                              Icons.person,
                              size: 24,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                  )
                else
                  // Storyn yok — boş avatar
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: Icon(
                      Icons.person,
                      color: AppColors.textBody,
                      size: 32,
                    ),
                  ),
                // Her zaman + ikonu göster
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Hikaye",
              style: TextStyle(fontSize: 11, color: AppColors.textBody),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryAvatar({
    required String name,
    String? photoUrl,
    required bool hasViewed,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasViewed
                    ? null
                    : LinearGradient(
                        colors: [AppColors.primary, Colors.orange],
                      ),
                border: hasViewed
                    ? Border.all(color: AppColors.border, width: 2)
                    : null,
              ),
              child: PreviewableProfileAvatar(
                imageUrl: photoUrl,
                radius: 28,
                backgroundColor: AppColors.primaryLight,
                placeholder: Icon(
                  Icons.person,
                  size: 24,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 64,
              child: Text(
                name.split(' ').first,
                style: TextStyle(fontSize: 11, color: AppColors.textBody),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: _postService.getPostsFeed(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Gönderiler yüklenemedi: ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ),
          );
        }
        final posts = snapshot.data?.docs ?? [];
        if (posts.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: AppColors.border,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Henüz paylaşım yok",
                    style: TextStyle(color: AppColors.textBody, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _PostCardWidget(
              doc: posts[index],
              currentUser: currentUser,
              postService: _postService,
              isAdmin: _isAdmin,
              onOpenProfile: (id) {
                if (id != null)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileView(userId: id),
                    ),
                  );
              },
              onOpenDetail: (id, d) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetailView(postId: id, postData: d),
                ),
              ),
            ),
            childCount: posts.length,
          ),
        );
      },
    );
  }
}

class _PostCardWidget extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final User? currentUser;
  final PostService postService;
  final bool isAdmin;
  final void Function(String?) onOpenProfile;
  final void Function(String, Map<String, dynamic>) onOpenDetail;
  const _PostCardWidget({
    required this.doc,
    required this.currentUser,
    required this.postService,
    this.isAdmin = false,
    required this.onOpenProfile,
    required this.onOpenDetail,
  });
  @override
  State<_PostCardWidget> createState() => _PostCardWidgetState();
}

class _PostCardWidgetState extends State<_PostCardWidget>
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  final PageController _pageController = PageController();
  bool _showHeart = false;
  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnim;
  Map<String, dynamic>? _authorData;

  @override
  void initState() {
    super.initState();
    _loadAuthorData();
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heartScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_heartAnimController);
  }

  Future<void> _loadAuthorData() async {
    final data = widget.doc.data() as Map<String, dynamic>;
    final authorId = data['authorId']?.toString();
    if (authorId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(authorId)
          .get();
      if (doc.exists && mounted) setState(() => _authorData = doc.data());
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _heartAnimController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    if (widget.currentUser == null) return;
    final data = widget.doc.data() as Map<String, dynamic>;
    final isLiked = List<String>.from(
      data['likedBy'] ?? [],
    ).contains(widget.currentUser!.uid);
    if (!isLiked) {
      widget.postService.toggleLike(
        widget.doc.id,
        widget.currentUser!.uid,
        false,
      );
    }
    setState(() => _showHeart = true);
    _heartAnimController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final isLiked =
        widget.currentUser != null &&
        List<String>.from(
          data['likedBy'] ?? [],
        ).contains(widget.currentUser!.uid);
    final isSaved =
        widget.currentUser != null &&
        List<String>.from(
          data['savedBy'] ?? [],
        ).contains(widget.currentUser!.uid);
    final likeCount = data['likeCount'] ?? 0;
    final commentCount = data['commentCount'] ?? 0;
    final createdAt = data['createdAt'] as Timestamp?;
    final timeAgo = createdAt != null ? _timeAgo(createdAt.toDate()) : '';
    final List<String> mediaUrls = data['mediaUrls'] != null
        ? List<String>.from(data['mediaUrls'])
        : [data['imageUrl'] ?? ''];
    final List<bool> mediaIsVideo = data['mediaIsVideo'] != null
        ? List<bool>.from(data['mediaIsVideo'])
        : [data['isVideo'] == true];

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                PreviewableProfileAvatar(
                  imageUrl: data['authorPhoto']?.toString(),
                  radius: 18,
                  backgroundColor: AppColors.primaryLight,
                  placeholder: Icon(
                    Icons.person,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  onTap: () => widget.onOpenProfile(data['authorId']),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onOpenProfile(data['authorId']),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                data['authorName'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textHeader,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_authorData?['role'] == 'admin') ...[
                              const SizedBox(width: 4),
                              const VerifiedBadge(type: 'admin', size: 14),
                            ] else if (VerifiedBadge.hasBlueBadge(
                              _authorData,
                            )) ...[
                              const SizedBox(width: 4),
                              const VerifiedBadge(type: 'verified', size: 14),
                            ],
                          ],
                        ),
                        if (timeAgo.isNotEmpty)
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textBody,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'report') {
                      _reportPost();
                    } else if (v == 'delete') {
                      _deletePost();
                    }
                  },
                  itemBuilder: (_) => [
                    if (data['authorId'] == widget.currentUser?.uid ||
                        widget.isAdmin)
                      const PopupMenuItem(value: 'delete', child: Text('Sil')),
                    if (data['authorId'] != widget.currentUser?.uid)
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('Şikayet Et'),
                      ),
                  ],
                  icon: Icon(Icons.more_vert, color: AppColors.textBody),
                ),
              ],
            ),
          ),
          // Media + çift tıklama beğenme
          GestureDetector(
            onDoubleTap: _onDoubleTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildMediaSection(mediaUrls, mediaIsVideo),
                if (_showHeart)
                  AnimatedBuilder(
                    animation: _heartScaleAnim,
                    builder: (context, child) => Transform.scale(
                      scale: _heartScaleAnim.value,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 80,
                        shadows: [
                          Shadow(blurRadius: 20, color: Colors.black38),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (widget.currentUser != null)
                      widget.postService.toggleLike(
                        widget.doc.id,
                        widget.currentUser!.uid,
                        isLiked,
                      );
                  },
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : AppColors.textHeader,
                    size: 26,
                  ),
                ),
                IconButton(
                  onPressed: () => widget.onOpenDetail(widget.doc.id, data),
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.textHeader,
                    size: 24,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    if (widget.currentUser != null)
                      widget.postService.toggleSave(
                        widget.doc.id,
                        widget.currentUser!.uid,
                        isSaved,
                      );
                  },
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: AppColors.textHeader,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
          if (likeCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "$likeCount beğeni",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textHeader,
                ),
              ),
            ),
          if ((data['caption'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 13, color: AppColors.textHeader),
                  children: [
                    TextSpan(
                      text: "${data['authorName']} ",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: data['caption'] ?? ''),
                  ],
                ),
              ),
            ),
          if (commentCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: GestureDetector(
                onTap: () => widget.onOpenDetail(widget.doc.id, data),
                child: Text(
                  "$commentCount yorumun tümünü gör",
                  style: TextStyle(fontSize: 13, color: AppColors.textBody),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMediaSection(List<String> urls, List<bool> isVids) {
    if (urls.length == 1) return _buildSingleMedia(urls[0], isVids[0]);
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.width,
          child: PageView.builder(
            controller: _pageController,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _buildSingleMedia(urls[i], isVids[i]),
          ),
        ),
        if (urls.length > 1)
          Positioned(
            bottom: 10,
            child: Row(
              children: List.generate(
                urls.length,
                (i) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _currentPage
                        ? AppColors.primary
                        : Colors.white54,
                  ),
                ),
              ),
            ),
          ),
        if (urls.length > 1)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentPage + 1}/${urls.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSingleMedia(String url, bool isVideo) {
    if (isVideo) return _FeedVideoPlayer(url: url);
    return Image.network(
      url,
      fit: BoxFit.fitWidth,
      width: double.infinity,
      errorBuilder: (_, e, s) => Container(
        height: 200,
        color: AppColors.background,
        child: Icon(Icons.broken_image, size: 48, color: AppColors.border),
      ),
    );
  }

  void _reportPost() {
    final data = widget.doc.data() as Map<String, dynamic>;
    widget.postService.reportPost(widget.doc.id, {
      'status': 'pending',
      'reporterEmail': widget.currentUser?.email ?? '',
      'reportedUserEmail': data['authorId'] ?? '',
      'reason': 'Uygunsuz içerik',
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Paylaşım şikayet edildi.')));
  }

  void _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paylaşımı Sil'),
        content: const Text('Bu paylaşımı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await widget.postService.deletePost(widget.doc.id);
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Paylaşım silindi.')));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Silme hatası: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
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

class _FeedVideoPlayer extends StatefulWidget {
  final String url;
  const _FeedVideoPlayer({required this.url});
  @override
  State<_FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<_FeedVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
        _controller.setLooping(true);
        _controller.setVolume(0);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized)
      return Container(
        height: 300,
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    return GestureDetector(
      onTap: () => setState(() {
        _controller.value.isPlaying ? _controller.pause() : _controller.play();
      }),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          if (!_controller.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
        ],
      ),
    );
  }
}
