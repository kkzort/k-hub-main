import 'package:cloud_firestore/cloud_firestore.dart';

class DmMessageModel {
  final String uid;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final Timestamp? createdAt;

  DmMessageModel({
    required this.uid,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.createdAt,
  });

  factory DmMessageModel.fromMap(String uid, Map<String, dynamic> data) {
    return DmMessageModel(
      uid: uid,
      conversationId: data['conversationId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      text: data['text'] ?? '',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
