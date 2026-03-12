import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import '../../service/story_service.dart';
import 'user_profile_view.dart';

class StoryViewerView extends StatefulWidget {
  final List<QueryDocumentSnapshot> stories;

  const StoryViewerView({super.key, required this.stories});

  @override
  State<StoryViewerView> createState() => _StoryViewerViewState();
}

class _StoryViewerViewState extends State<StoryViewerView>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _progressController;
  final StoryService _storyService = StoryService();
  final currentUser = FirebaseAuth.instance.currentUser;
  VideoPlayerController? _videoController;
  bool _isPaused = false;
  bool _isAdmin = false;
  StreamSubscription<DocumentSnapshot>? _storyListener;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });
    _loadStory();
    _checkAdmin();
  }

  /// Mevcut hikayeyi gerçek zamanlı dinle — silinirse otomatik geç
  void _watchCurrentStory() {
    _storyListener?.cancel();
    if (_currentIndex >= widget.stories.length) return;

    final storyId = widget.stories[_currentIndex].id;
    _storyListener = FirebaseFirestore.instance
        .collection('stories')
        .doc(storyId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (!snapshot.exists) {
        // Hikaye silindi — sonrakine geç veya kapat
        _videoController?.pause();
        _progressController.stop();
        if (_currentIndex < widget.stories.length - 1) {
          setState(() => _currentIndex++);
          _loadStory();
        } else {
          Navigator.pop(context);
        }
      }
    });
  }

  Future<void> _loadStory() async {
    _progressController.reset();
    _videoController?.dispose();
    _videoController = null;

    if (_currentIndex >= widget.stories.length) return;

    // Gerçek zamanlı dinlemeyi başlat
    _watchCurrentStory();

    final data = widget.stories[_currentIndex].data() as Map<String, dynamic>;
    final isVideo = data['isVideo'] == true;

    // Mark as viewed
    if (currentUser != null) {
      _storyService.markViewed(
        widget.stories[_currentIndex].id,
        currentUser!.uid,
      );
    }

    if (isVideo) {
      final url = data['imageUrl'] ?? '';
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _videoController = controller;
      await controller.initialize();
      if (!mounted) return;

      final videoDuration = controller.value.duration;
      _progressController.duration = videoDuration;

      setState(() {});
      controller.play();
      _progressController.forward();

      controller.addListener(() {
        if (controller.value.position >= controller.value.duration &&
            !controller.value.isPlaying) {
          // video ended
        }
      });
    } else {
      _progressController.duration = const Duration(seconds: 5);
      setState(() {});
      _progressController.forward();
    }
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _loadStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _loadStory();
    }
  }

  void _onTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth / 3) {
      _prevStory();
    } else {
      _nextStory();
    }
  }

  void _onLongPressStart(LongPressStartDetails _) {
    setState(() => _isPaused = true);
    _progressController.stop();
    _videoController?.pause();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    setState(() => _isPaused = false);
    _progressController.forward();
    _videoController?.play();
  }

  @override
  void dispose() {
    _storyListener?.cancel();
    _progressController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.stories[_currentIndex].data() as Map<String, dynamic>;
    final createdAt = data['createdAt'] as Timestamp?;
    final isVideo = data['isVideo'] == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media content
            if (isVideo && _videoController != null && _videoController!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else if (!isVideo)
              Image.network(
                data['imageUrl'] ?? '',
                fit: BoxFit.contain,
                errorBuilder: (_, e, s) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.white)),

            // Gradient overlay top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 160,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ),

            // Progress bars
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: List.generate(widget.stories.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: index < _currentIndex
                          ? const LinearProgressIndicator(
                              value: 1,
                              backgroundColor: Colors.white30,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                              minHeight: 2.5,
                            )
                          : index == _currentIndex
                              ? AnimatedBuilder(
                                  animation: _progressController,
                                  builder: (context, child) => LinearProgressIndicator(
                                    value: _progressController.value,
                                    backgroundColor: Colors.white30,
                                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                                    minHeight: 2.5,
                                  ),
                                )
                              : const LinearProgressIndicator(
                                  value: 0,
                                  backgroundColor: Colors.white30,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                  minHeight: 2.5,
                                ),
                    ),
                  );
                }),
              ),
            ),

            // User info
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      final authorId = data['authorId']?.toString();
                      if (authorId != null && authorId.isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileView(userId: authorId)));
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: data['authorPhoto'] != null
                              ? NetworkImage(data['authorPhoto'])
                              : null,
                          backgroundColor: Colors.white24,
                          child: data['authorPhoto'] == null
                              ? const Icon(Icons.person, size: 18, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          data['authorName'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (createdAt != null)
                    Text(
                      _timeAgo(createdAt.toDate()),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  const Spacer(),
                  // Üç nokta menü (sil / şikayet)
                  IconButton(
                    onPressed: () => _showStoryOptions(data),
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Paused indicator
            if (_isPaused)
              const Center(
                child: Icon(Icons.pause_circle_filled, color: Colors.white54, size: 64),
              ),

            // Story text overlay
            if (data['text'] != null && (data['text'] as String).isNotEmpty)
              Positioned(
                bottom: 80,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data['text'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Görüntüleyenler butonu — sadece kendi storynde
            if (_isOwnStory(data))
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showViewersSheet(data),
                  onVerticalDragUpdate: (details) {
                    if (details.delta.dy < -5) _showViewersSheet(data);
                  },
                  child: Column(
                    children: [
                      const Icon(Icons.keyboard_arrow_up, color: Colors.white70, size: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.visibility_outlined, color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${List<String>.from(data['viewedBy'] ?? []).length}',
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkAdmin() async {
    if (currentUser == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    final role = (doc.data() ?? {})['role'] ?? '';
    if (mounted && role == 'admin') setState(() => _isAdmin = true);
  }

  bool _isOwnStory(Map<String, dynamic> data) {
    return currentUser != null && data['authorId'] == currentUser!.uid;
  }

  void _showStoryOptions(Map<String, dynamic> data) {
    _progressController.stop();
    _videoController?.pause();

    final isOwn = _isOwnStory(data);
    final storyId = widget.stories[_currentIndex].id;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (isOwn || _isAdmin)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Hikayeyi Sil', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteStory(storyId);
                  },
                ),
              if (!isOwn)
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.orangeAccent),
                  title: const Text('Hikayeyi Şikayet Et', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _reportStory(storyId, data);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.white54),
                title: const Text('İptal', style: TextStyle(color: Colors.white54)),
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted && !_isPaused) {
        _progressController.forward();
        _videoController?.play();
      }
    });
  }

  void _confirmDeleteStory(String storyId) {
    _progressController.stop();
    _videoController?.pause();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hikayeyi Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Bu hikaye kalıcı olarak silinecek. Emin misin?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _storyService.deleteStory(storyId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hikaye silindi'), duration: Duration(seconds: 2)),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).whenComplete(() {
      if (mounted && !_isPaused) {
        _progressController.forward();
        _videoController?.play();
      }
    });
  }

  void _reportStory(String storyId, Map<String, dynamic> data) {
    _progressController.stop();
    _videoController?.pause();

    final reasons = [
      'Uygunsuz İçerik',
      'Spam',
      'Nefret Söylemi',
      'Taciz / Zorbalık',
      'Diğer',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Colors.orangeAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Şikayet Nedeni Seç',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ...reasons.map((reason) => ListTile(
                    title: Text(reason, style: const TextStyle(color: Colors.white70)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _storyService.reportStory(storyId, {
                        'reason': reason,
                        'reporterId': currentUser?.uid ?? '',
                        'authorId': data['authorId'] ?? '',
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Şikayet gönderildi. Teşekkürler!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted && !_isPaused) {
        _progressController.forward();
        _videoController?.play();
      }
    });
  }

  void _showViewersSheet(Map<String, dynamic> storyData) {
    _progressController.stop();
    _videoController?.pause();
    final viewedBy = List<String>.from(storyData['viewedBy'] ?? []);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Görüntüleyenler (${viewedBy.length})',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: viewedBy.isEmpty
                  ? const Center(child: Text('Henüz kimse görüntülemedi', style: TextStyle(color: Colors.white38, fontSize: 14)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: viewedBy.length,
                      itemBuilder: (ctx, index) {
                        final uid = viewedBy[index];
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                          builder: (ctx, snap) {
                            final userData = snap.data?.data() as Map<String, dynamic>?;
                            final name = userData?['name'] ?? 'Kullanıcı';
                            final photo = userData?['photoUrl'];
                            final nick = userData?['nick'] ?? '';
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundImage: photo != null ? NetworkImage(photo) : null,
                                backgroundColor: Colors.white12,
                                child: photo == null ? const Icon(Icons.person, color: Colors.white54, size: 20) : null,
                              ),
                              title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                              subtitle: nick.isNotEmpty ? Text('@$nick', style: const TextStyle(color: Colors.white38, fontSize: 12)) : null,
                              onTap: () {
                                Navigator.pop(ctx);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileView(userId: uid)));
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // Sheet kapanınca story devam etsin
      if (mounted && !_isPaused) {
        _progressController.forward();
        _videoController?.play();
      }
    });
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}sa';
    return '${diff.inDays}g';
  }
}
