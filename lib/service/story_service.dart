import 'package:cloud_firestore/cloud_firestore.dart';

class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _stories => _firestore.collection('stories');

  Future<DocumentReference> createStory(Map<String, dynamic> data) {
    return _stories.add(data);
  }

  Future<void> deleteStory(String storyId) {
    return _stories.doc(storyId).delete();
  }

  Stream<QuerySnapshot> getActiveStories() {
    return _stories
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt', descending: false)
        .snapshots();
  }

  Future<void> markViewed(String storyId, String uid) {
    return _stories.doc(storyId).update({
      'viewedBy': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> reportStory(String storyId, Map<String, dynamic> data) async {
    await _firestore.collection('reports').add({
      'type': 'story',
      'storyId': storyId,
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
