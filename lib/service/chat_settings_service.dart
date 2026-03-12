import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference get _settingsDoc =>
      _firestore.collection('chat_settings').doc('campus_chat');

  /// Ayarları stream olarak dinle
  Stream<Map<String, dynamic>> settingsStream() {
    return _settingsDoc.snapshots().map((snap) {
      if (!snap.exists) {
        return {
          'mediaUploadEnabled': false,
          'autoDeleteEnabled': false,
          'autoDeleteDays': 7,
        };
      }
      return snap.data() as Map<String, dynamic>;
    });
  }

  /// Ayarları tek sefer getir
  Future<Map<String, dynamic>> getSettings() async {
    final snap = await _settingsDoc.get();
    if (!snap.exists) {
      return {
        'mediaUploadEnabled': false,
        'autoDeleteEnabled': false,
        'autoDeleteDays': 7,
      };
    }
    return snap.data() as Map<String, dynamic>;
  }

  /// Ayarları güncelle (sadece admin)
  Future<void> updateSettings(Map<String, dynamic> data) async {
    await _settingsDoc.set(data, SetOptions(merge: true));
  }
}
