import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../core/style/app_colors.dart';
import '../../core/widgets/profile_photo_preview.dart';
import '../../service/post_service.dart';
import 'user_profile_view.dart';

class PostDetailView extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const PostDetailView({
    super.key,
    required this.postId,
    required this.postData,
  });

  @override
  State<PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<PostDetailView> {
  final PostService _postService = PostService();
  final TextEditingController _commentController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty || currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    final userData = userDoc.data() ?? {};

    await _postService.addComment(widget.postId, {
      'postId': widget.postId,
      'authorId': currentUser!.uid,
      'authorName': userData['name'] ?? 'Kullanıcı',
      'authorPhoto': userData['photoUrl'],
      'text': _commentController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yorumlar'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Post header
          Container(
            padding: const EdgeInsets.all(14),
            color: AppColors.surface,
            child: Row(
              children: [
                PreviewableProfileAvatar(
                  imageUrl: widget.postData['authorPhoto']?.toString(),
                  radius: 18,
                  backgroundColor: AppColors.primaryLight,
                  placeholder: Icon(
                    Icons.person,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  onTap: () {
                    final authorId = widget.postData['authorId']?.toString();
                    if (authorId != null && authorId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileView(userId: authorId),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final authorId = widget.postData['authorId']?.toString();
                      if (authorId != null && authorId.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileView(userId: authorId),
                          ),
                        );
                      }
                    },
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textHeader,
                        ),
                        children: [
                          TextSpan(
                            text: "${widget.postData['authorName']} ",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: widget.postData['caption'] ?? ''),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divider),

          // Comments list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _postService.getComments(widget.postId),
              builder: (context, snapshot) {
                final comments = snapshot.data?.docs ?? [];
                if (comments.isEmpty) {
                  return Center(
                    child: Text(
                      'Henüz yorum yok.',
                      style: TextStyle(color: AppColors.textBody),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final data = comments[index].data() as Map<String, dynamic>;
                    final createdAt = data['createdAt'] as Timestamp?;
                    final timeStr = createdAt != null
                        ? _timeAgo(createdAt.toDate())
                        : '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PreviewableProfileAvatar(
                            imageUrl: data['authorPhoto']?.toString(),
                            radius: 16,
                            backgroundColor: AppColors.primaryLight,
                            placeholder: Icon(
                              Icons.person,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            onTap: () {
                              final cid = data['authorId']?.toString();
                              if (cid != null && cid.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        UserProfileView(userId: cid),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    final cid = data['authorId']?.toString();
                                    if (cid != null && cid.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              UserProfileView(userId: cid),
                                        ),
                                      );
                                    }
                                  },
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textHeader,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: "${data['authorName']} ",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(text: data['text'] ?? ''),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textBody,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (data['authorId'] == currentUser?.uid)
                            IconButton(
                              onPressed: () => _postService.deleteComment(
                                widget.postId,
                                comments[index].id,
                              ),
                              icon: Icon(
                                Icons.close,
                                size: 16,
                                color: AppColors.textBody,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Comment input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              bottom: true,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Yorum yaz...',
                        hintStyle: TextStyle(color: AppColors.textBody),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _addComment,
                    child: Text(
                      'Gönder',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
