import 'package:cloud_firestore/cloud_firestore.dart';

class NoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> toggleLike(String noteId, String uid, bool currentlyLiked) async {
    final docRef = _firestore.collection('notes').doc(noteId);
    
    if (currentlyLiked) {
      await docRef.update({
        'likes': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      await docRef.update({
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> toggleSave(String noteId, String uid, bool currentlySaved) async {
    final docRef = _firestore.collection('notes').doc(noteId);
    
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

  Future<void> addComment(String noteId, Map<String, dynamic> comment) async {
    await _firestore.collection('notes').doc(noteId).update({
      'comments': FieldValue.arrayUnion([comment]),
    });
  }
}
