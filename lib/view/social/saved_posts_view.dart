import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/style/app_colors.dart';
import '../../service/post_service.dart';
import 'post_detail_view.dart';

class SavedPostsView extends StatelessWidget {
  const SavedPostsView({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final postService = PostService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kaydedilen Gönderiler'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        elevation: 0,
      ),
      body: currentUser == null
          ? const Center(child: Text('Giriş yapmanız gerekiyor.'))
          : StreamBuilder<QuerySnapshot>(
              stream: postService.getSavedPosts(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final posts = snapshot.data?.docs ?? [];
                // Client-side sıralama (composite index gerektirmemek için)
                posts.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_border_rounded, size: 64, color: AppColors.border),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz kaydedilen gönderi yok',
                          style: TextStyle(fontSize: 16, color: AppColors.textBody),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gönderilerdeki kaydet simgesine dokunarak\ngönderileri buraya kaydedebilirsin.',
                          style: TextStyle(fontSize: 13, color: AppColors.textBody),
                          textAlign: TextAlign.center,
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
                          builder: (_) => PostDetailView(
                            postId: posts[index].id,
                            postData: data,
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
                            const Positioned(
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
                            const Positioned(
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
            ),
    );
  }
}
