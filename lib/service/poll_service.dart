import 'package:cloud_firestore/cloud_firestore.dart';

class PollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> vote(String pollId, String uid, int optionIndex) async {
    final docRef = _firestore.collection('polls').doc(pollId);

    try {
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) return false;

        final data = snapshot.data() as Map<String, dynamic>;
        final votedBy = data['votedBy'] as Map<String, dynamic>? ?? {};

        // Daha önce oy vermiş mi kontrol et
        if (votedBy.containsKey(uid)) return false;

        final options = List<Map<String, dynamic>>.from(
            (data['options'] as List).map((o) => Map<String, dynamic>.from(o)));
        final totalVotes = (data['totalVotes'] ?? 0) as int;

        // Oyu ekle
        options[optionIndex]['votes'] = (options[optionIndex]['votes'] ?? 0) + 1;
        votedBy[uid] = optionIndex;

        transaction.update(docRef, {
          'options': options,
          'totalVotes': totalVotes + 1,
          'votedBy': votedBy,
        });

        return true;
      });
    } catch (e) {
      return false;
    }
  }
}
