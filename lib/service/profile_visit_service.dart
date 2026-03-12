import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileVisitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Profil ziyareti kaydet
  Future<void> recordVisit({
    required String visitorId,
    required String profileOwnerId,
  }) async {
    // Kendi profilini ziyaret etmeyi kaydetme
    if (visitorId == profileOwnerId) return;

    final docId = '${profileOwnerId}_$visitorId';
    await _firestore.collection('profile_visits').doc(docId).set({
      'visitorId': visitorId,
      'profileOwnerId': profileOwnerId,
      'visitedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Profili ziyaret edenleri getir
  Stream<QuerySnapshot> getVisitors(String profileOwnerId) {
    return _firestore
        .collection('profile_visits')
        .where('profileOwnerId', isEqualTo: profileOwnerId)
        .snapshots();
  }

  /// Ziyaretçi sayısı
  Future<int> getVisitorCount(String profileOwnerId) async {
    final snap = await _firestore
        .collection('profile_visits')
        .where('profileOwnerId', isEqualTo: profileOwnerId)
        .count()
        .get();
    return snap.count ?? 0;
  }
}
