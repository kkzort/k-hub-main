import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String uid;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final String imageUrl;
  final String? text;
  final Timestamp? createdAt;
  final Timestamp? expiresAt;
  final List<String> viewedBy;

  StoryModel({
    required this.uid,
    required this.authorId,
    required this.authorName,
    this.authorPhoto,
    required this.imageUrl,
    this.text,
    this.createdAt,
    this.expiresAt,
    this.viewedBy = const [],
  });

  factory StoryModel.fromMap(String uid, Map<String, dynamic> data) {
    return StoryModel(
      uid: uid,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorPhoto: data['authorPhoto'],
      imageUrl: data['imageUrl'] ?? '',
      text: data['text'],
      createdAt: data['createdAt'] as Timestamp?,
      expiresAt: data['expiresAt'] as Timestamp?,
      viewedBy: List<String>.from(data['viewedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhoto': authorPhoto,
      'imageUrl': imageUrl,
      'text': text,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'expiresAt': expiresAt ??
          Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 24)),
          ),
      'viewedBy': viewedBy,
    };
  }
}
