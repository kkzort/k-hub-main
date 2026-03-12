import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String uid;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantPhotos;
  final String? lastMessage;
  final Timestamp? lastMessageTime;
  final Map<String, int> unreadCount;

  ConversationModel({
    required this.uid,
    required this.participantIds,
    required this.participantNames,
    this.participantPhotos = const {},
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = const {},
  });

  factory ConversationModel.fromMap(String uid, Map<String, dynamic> data) {
    return ConversationModel(
      uid: uid,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      participantPhotos: Map<String, String?>.from(data['participantPhotos'] ?? {}),
      lastMessage: data['lastMessage'],
      lastMessageTime: data['lastMessageTime'] as Timestamp?,
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participantIds': participantIds,
      'participantNames': participantNames,
      'participantPhotos': participantPhotos,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime ?? FieldValue.serverTimestamp(),
      'unreadCount': unreadCount,
    };
  }
}
