import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../core/style/app_colors.dart';
import '../../core/widgets/profile_photo_preview.dart';
import '../../service/post_service.dart';
import 'post_detail_view.dart';
import 'user_profile_view.dart';

/// Instagram tarzı — profildeki grid'e tıklayınca
/// tüm postları dikey scroll ile gösteren view.
class ProfilePostsScrollView extends StatefulWidget {
  final String userId;
  final List<QueryDocumentSnapshot> posts;
  final int initialIndex;

  const ProfilePostsScrollView({
    super.key,
    required this.userId,
    required this.posts,
    required this.initialIndex,
  });

  @override
  State<ProfilePostsScrollView> createState() => _ProfilePostsScrollViewState();
}

class _ProfilePostsScrollViewState extends State<ProfilePostsScrollView> {
  final PostService _postService = PostService();
  final currentUser = FirebaseAuth.instance.currentUser;
  late final ScrollController _scrollController;
  final GlobalKey _targetKey = GlobalKey();
  bool _scrolledToInitial = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textHeader,
        elevation: 0,
        title: Text(
          'Gönderiler',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textHeader,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _postService.getUserPosts(widget.userId),
        builder: (context, snapshot) {
          final posts = snapshot.data?.docs ?? widget.posts;
          if (posts.isEmpty) {
            return Center(
              child: Text(
                'Henüz gönderi yok',
                style: TextStyle(color: AppColors.textBody),
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final data = posts[index].data() as Map<String, dynamic>;
              final postId = posts[index].id;

              return _ProfilePostCard(
                key: index == widget.initialIndex ? _targetKey : null,
                postId: postId,
                data: data,
                currentUser: currentUser,
                postService: _postService,
                onOpenProfile: (id) {
                  if (id != null)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileView(userId: id),
                      ),
                    );
                },
                onOpenComments: (id, d) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailView(postId: id, postData: d),
                    ),
                  );
                },
                onDeleted: () => setState(() {}),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_scrolledToInitial && widget.initialIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_targetKey.currentContext != null) {
          Scrollable.ensureVisible(
            _targetKey.currentContext!,
            alignment: 0.0,
            duration: const Duration(milliseconds: 300),
          );
          _scrolledToInitial = true;
        }
      });
    }
  }
}

class _ProfilePostCard extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;
  final User? currentUser;
  final PostService postService;
  final void Function(String?) onOpenProfile;
  final void Function(String, Map<String, dynamic>) onOpenComments;
  final VoidCallback onDeleted;

  const _ProfilePostCard({
    super.key,
    required this.postId,
    required this.data,
    required this.currentUser,
    required this.postService,
    required this.onOpenProfile,
    required this.onOpenComments,
    required this.onDeleted,
  });

  @override
  State<_ProfilePostCard> createState() => _ProfilePostCardState();
}

class _ProfilePostCardState extends State<_ProfilePostCard>
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  // Çift tıklama kalp animasyonu
  bool _showHeart = false;
  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnim;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _pageController.dispose();
    _heartAnimController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    if (widget.currentUser == null) return;
    final isLiked = List<String>.from(
      widget.data['likedBy'] ?? [],
    ).contains(widget.currentUser!.uid);
    if (!isLiked) {
      widget.postService.toggleLike(
        widget.postId,
        widget.currentUser!.uid,
        false,
      );
    }
    setState(() => _showHeart = true);
    _heartAnimController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Gönderiyi Sil',
          style: TextStyle(color: AppColors.textHeader),
        ),
        content: Text(
          'Bu gönderi kalıcı olarak silinecek.',
          style: TextStyle(color: AppColors.textBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: TextStyle(color: AppColors.textBody)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sil',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.postService.deletePost(widget.postId);
      widget.onDeleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
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
    final isOwn = data['authorId'] == widget.currentUser?.uid;

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
                        Text(
                          data['authorName'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textHeader,
                          ),
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
                    if (v == 'delete') _deletePost();
                    if (v == 'report') {
                      widget.postService.reportPost(widget.postId, {
                        'status': 'pending',
                        'reporterEmail': widget.currentUser?.email ?? '',
                        'reportedUserEmail': data['authorId'] ?? '',
                        'reason': 'Uygunsuz içerik',
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Paylaşım şikayet edildi.'),
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    if (isOwn)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Sil', style: TextStyle(color: Colors.red)),
                      ),
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

          // Media + çift tıklama
          GestureDetector(
            onDoubleTap: _onDoubleTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildMediaSection(mediaUrls, mediaIsVideo),
                // Kalp animasyonu
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
                        widget.postId,
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
                  onPressed: () => widget.onOpenComments(widget.postId, data),
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
                        widget.postId,
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
                onTap: () => widget.onOpenComments(widget.postId, data),
                child: Text(
                  "$commentCount yorumun tümünü gör",
                  style: TextStyle(fontSize: 13, color: AppColors.textBody),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Divider(color: AppColors.divider, height: 1),
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
    if (isVideo) return _ScrollVideoPlayer(url: url);
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

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}sa';
    if (diff.inDays < 7) return '${diff.inDays}g';
    return DateFormat('dd.MM.yyyy').format(date);
  }
}

class _ScrollVideoPlayer extends StatefulWidget {
  final String url;
  const _ScrollVideoPlayer({required this.url});
  @override
  State<_ScrollVideoPlayer> createState() => _ScrollVideoPlayerState();
}

class _ScrollVideoPlayerState extends State<_ScrollVideoPlayer> {
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
