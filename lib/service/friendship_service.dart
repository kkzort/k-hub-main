import 'package:cloud_firestore/cloud_firestore.dart';

class FriendshipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _friendships => _firestore.collection('friendships');

  /// Deterministic friendship ID
  String getFriendshipId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Direkt takip et (istek gönderme yok, anında takip)
  Future<void> follow({
    required String requesterId,
    required String receiverId,
    required String requesterName,
    required String receiverName,
    String? requesterPhoto,
    String? receiverPhoto,
  }) async {
    final id = getFriendshipId(requesterId, receiverId);
    await _friendships.doc(id).set({
      'requesterId': requesterId,
      'receiverId': receiverId,
      'requesterName': requesterName,
      'receiverName': receiverName,
      'requesterPhoto': requesterPhoto,
      'receiverPhoto': receiverPhoto,
      'status': 'accepted',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Bildirim oluştur — "X seni takip etmeye başladı"
    await _firestore.collection('notifications').add({
      'type': 'follow',
      'fromUserId': requesterId,
      'fromUserName': requesterName,
      'fromUserPhoto': requesterPhoto,
      'toUserId': receiverId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFriend(String uid1, String uid2) {
    final id = getFriendshipId(uid1, uid2);
    return _friendships.doc(id).delete();
  }

  Stream<QuerySnapshot> getFriends(String userId) {
    // We need to query both directions - user can be requester or receiver
    // Firestore doesn't support OR queries on different fields in a single query
    // So we'll use a where on participantIds-like approach
    // But since we have requesterId/receiverId, we need two queries merged in the UI
    return _friendships
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  Stream<QuerySnapshot> getPendingRequests(String userId) {
    return _friendships
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<DocumentSnapshot?> checkFriendshipStatus(String uid1, String uid2) async {
    final id = getFriendshipId(uid1, uid2);
    final doc = await _friendships.doc(id).get();
    return doc.exists ? doc : null;
  }

  Stream<DocumentSnapshot> watchFriendship(String uid1, String uid2) {
    final id = getFriendshipId(uid1, uid2);
    return _friendships.doc(id).snapshots();
  }
}
