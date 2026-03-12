import 'package:cloud_firestore/cloud_firestore.dart';

class DmService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _conversations => _firestore.collection('conversations');

  /// Create deterministic conversation ID from two user IDs
  String getConversationId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Get or create a conversation between two users
  Future<String> getOrCreateConversation({
    required String currentUserId,
    required String currentUserName,
    required String? currentUserPhoto,
    required String otherUserId,
    required String otherUserName,
    required String? otherUserPhoto,
  }) async {
    final convId = getConversationId(currentUserId, otherUserId);
    final docRef = _conversations.doc(convId);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'participantIds': [currentUserId, otherUserId],
        'participantNames': {
          currentUserId: currentUserName,
          otherUserId: otherUserName,
        },
        'participantPhotos': {
          currentUserId: currentUserPhoto,
          otherUserId: otherUserPhoto,
        },
        'lastMessage': null,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {currentUserId: 0, otherUserId: 0},
      });
    }
    return convId;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    required String receiverId,
    String? replyToText,
    String? replyToSender,
    String? mediaUrl,
    String? mediaType,
    String? mediaName,
  }) async {
    // expiresAt hesapla
    Timestamp? expiresAt;
    final autoDeleteDays = await getAutoDeleteDays(conversationId);
    if (autoDeleteDays != null) {
      expiresAt = Timestamp.fromDate(
        DateTime.now().add(Duration(days: autoDeleteDays)),
      );
    }

    await _conversations.doc(conversationId).collection('messages').add({
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'isRead': false,
      'replyToText': replyToText,
      'replyToSender': replyToSender,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'mediaName': mediaName,
      'expiresAt': expiresAt,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Son mesaj önizlemesi
    String lastMsg = text;
    if (text.isEmpty && mediaType != null) {
      switch (mediaType) {
        case 'image':
          lastMsg = '📷 Fotoğraf';
          break;
        case 'video':
          lastMsg = '🎥 Video';
          break;
        case 'file':
          lastMsg = '📄 ${mediaName ?? 'Dosya'}';
          break;
      }
    }

    await _conversations.doc(conversationId).update({
      'lastMessage': lastMsg,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
      'unreadCount.$receiverId': FieldValue.increment(1),
    });
  }

  /// Kaybolan mesaj süresini ayarla (null = kapalı)
  Future<void> setAutoDelete(String conversationId, int? days) async {
    await _conversations.doc(conversationId).update({
      'autoDeleteDays': days,
    });
  }

  /// Kaybolan mesaj süresini getir
  Future<int?> getAutoDeleteDays(String conversationId) async {
    final doc = await _conversations.doc(conversationId).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>?;
    return data?['autoDeleteDays'] as int?;
  }

  Stream<QuerySnapshot> getConversations(String userId) {
    return _conversations
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getMessages(String conversationId) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> markRead(String conversationId, String userId) {
    return _conversations.doc(conversationId).update({
      'unreadCount.$userId': 0,
    });
  }

  /// Mark all messages from the other user as read
  Future<void> markMessagesAsRead(String conversationId, String currentUserId) async {
    final messagesRef = _conversations.doc(conversationId).collection('messages');
    final unreadMessages = await messagesRef
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in unreadMessages.docs) {
      final data = doc.data();
      // Only mark messages from the OTHER user as read
      if (data['senderId'] != currentUserId) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }
}
