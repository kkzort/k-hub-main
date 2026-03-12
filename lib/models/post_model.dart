import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String uid;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final String imageUrl;
  final String caption;
  final int likeCount;
  final int commentCount;
  final List<String> likedBy;
  final Timestamp? createdAt;

  PostModel({
    required this.uid,
    required this.authorId,
    required this.authorName,
    this.authorPhoto,
    required this.imageUrl,
    required this.caption,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedBy = const [],
    this.createdAt,
  });

  factory PostModel.fromMap(String uid, Map<String, dynamic> data) {
    return PostModel(
      uid: uid,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorPhoto: data['authorPhoto'],
      imageUrl: data['imageUrl'] ?? '',
      caption: data['caption'] ?? '',
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhoto': authorPhoto,
      'imageUrl': imageUrl,
      'caption': caption,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'likedBy': likedBy,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
