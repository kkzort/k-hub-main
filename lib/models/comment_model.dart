import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String uid;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final String text;
  final Timestamp? createdAt;

  CommentModel({
    required this.uid,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorPhoto,
    required this.text,
    this.createdAt,
  });

  factory CommentModel.fromMap(String uid, Map<String, dynamic> data) {
    return CommentModel(
      uid: uid,
      postId: data['postId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorPhoto: data['authorPhoto'],
      text: data['text'] ?? '',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhoto': authorPhoto,
      'text': text,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
