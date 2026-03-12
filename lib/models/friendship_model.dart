import 'package:cloud_firestore/cloud_firestore.dart';

class FriendshipModel {
  final String uid;
  final String requesterId;
  final String receiverId;
  final String requesterName;
  final String receiverName;
  final String? requesterPhoto;
  final String? receiverPhoto;
  final String status; // pending, accepted, rejected
  final Timestamp? createdAt;

  FriendshipModel({
    required this.uid,
    required this.requesterId,
    required this.receiverId,
    required this.requesterName,
    required this.receiverName,
    this.requesterPhoto,
    this.receiverPhoto,
    this.status = 'pending',
    this.createdAt,
  });

  factory FriendshipModel.fromMap(String uid, Map<String, dynamic> data) {
    return FriendshipModel(
      uid: uid,
      requesterId: data['requesterId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      requesterName: data['requesterName'] ?? '',
      receiverName: data['receiverName'] ?? '',
      requesterPhoto: data['requesterPhoto'],
      receiverPhoto: data['receiverPhoto'],
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requesterId': requesterId,
      'receiverId': receiverId,
      'requesterName': requesterName,
      'receiverName': receiverName,
      'requesterPhoto': requesterPhoto,
      'receiverPhoto': receiverPhoto,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
