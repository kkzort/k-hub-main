import 'package:cloud_firestore/cloud_firestore.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _posts => _firestore.collection('posts');

  Future<DocumentReference> createPost(Map<String, dynamic> data) {
    return _posts.add(data);
  }

  Future<void> deletePost(String postId) async {
    final comments = await _posts.doc(postId).collection('comments').get();
    for (final doc in comments.docs) {
      await doc.reference.delete();
    }
    await _posts.doc(postId).delete();
  }

  Future<void> toggleLike(String postId, String uid, bool currentlyLiked) async {
    final docRef = _posts.doc(postId);
    if (currentlyLiked) {
      await docRef.update({
        'likeCount': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      await docRef.update({
        'likeCount': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> toggleSave(String postId, String uid, bool currentlySaved) async {
    final docRef = _posts.doc(postId);
    if (currentlySaved) {
      await docRef.update({
        'savedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      await docRef.update({
        'savedBy': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<DocumentReference> addComment(String postId, Map<String, dynamic> commentData) async {
    final ref = await _posts.doc(postId).collection('comments').add(commentData);
    await _posts.doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });
    return ref;
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _posts.doc(postId).collection('comments').doc(commentId).delete();
    await _posts.doc(postId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }

  Stream<QuerySnapshot> getPostsFeed({int limit = 20}) {
    return _posts
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserPosts(String userId) {
    return _posts
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getSavedPosts(String uid) {
    return _posts
        .where('savedBy', arrayContains: uid)
        .snapshots();
  }

  Stream<QuerySnapshot> getComments(String postId) {
    return _posts
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> reportPost(String postId, Map<String, dynamic> data) async {
    await _firestore.collection('reports').add({
      'type': 'post',
      'postId': postId,
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
