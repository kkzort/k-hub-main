import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/style/app_colors.dart';

class AdminBlacklistView extends StatefulWidget {
  const AdminBlacklistView({super.key});

  @override
  State<AdminBlacklistView> createState() => _AdminBlacklistViewState();
}

class _AdminBlacklistViewState extends State<AdminBlacklistView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _unbanUser({
    required String uid,
    required String name,
  }) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ban Kaldır'),
            content: Text('$name kullanıcısının banını kaldırmak istiyor musunuz?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hayır'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Evet'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    await _firestore.collection('users').doc(uid).update({
      'isBanned': false,
      'bannedAt': FieldValue.delete(),
      'banReason': FieldValue.delete(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name ban listesinden çıkarıldı.')),
    );
  }

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return '-';
    try {
      return DateFormat('dd.MM.yyyy HH:mm').format(value.toDate());
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Blacklist', style: TextStyle(color: AppColors.textHeader)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        iconTheme: IconThemeData(color: AppColors.textHeader),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Veri alınamadı.'));
          }

          final bannedUsers = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['isBanned'] == true;
          }).toList();

          if (bannedUsers.isEmpty) {
            return const Center(
              child: Text('Banlı kullanıcı bulunmuyor.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: bannedUsers.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = bannedUsers[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? 'Bilinmiyor').toString();
              final email = (data['email'] ?? 'Bilinmiyor').toString();
              final banReason =
                  (data['banReason'] ?? 'Yönetici tarafından banlandı').toString();
              final bannedAt = data['bannedAt'];

              return Card(
                elevation: 2,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.red, width: 1.5),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red[100],
                    child: const Icon(Icons.block, color: Colors.red),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHeader),
                  ),
                  subtitle: Text(
                    'Email: $email\nSebep: $banReason\nTarih: ${_formatDate(bannedAt)}',
                    style: TextStyle(color: AppColors.textBody),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Ban Kaldır',
                    icon: const Icon(Icons.lock_open, color: Colors.green),
                    onPressed: () => _unbanUser(uid: doc.id, name: name),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
