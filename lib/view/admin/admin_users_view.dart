import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/style/app_colors.dart';

class AdminUsersView extends StatefulWidget {
  const AdminUsersView({super.key});

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _changeUserRole(String uid, String currentRole) async {
    final newRole = currentRole == 'admin' ? 'student' : 'admin';
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Yetki Değişikliği'),
            content: Text(
              "Kullanıcı yetkisini '$newRole' olarak değiştirmek istiyor musunuz?",
            ),
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

    await _firestore.collection('users').doc(uid).update({'role': newRole});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Yeni yetki: $newRole olarak ayarlandı.')),
    );
  }

  Future<void> _approveUser(String uid, bool isApproved) async {
    final willApprove = !isApproved;
    await _firestore.collection('users').doc(uid).update({
      'isApproved': willApprove,
      'approvedAt': willApprove
          ? FieldValue.serverTimestamp()
          : FieldValue.delete(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isApproved ? 'Onay kaldırıldı.' : 'Kullanıcı onaylandı.'),
      ),
    );
  }

  Future<void> _toggleBanUser({
    required String uid,
    required bool isBanned,
    required String userName,
  }) async {
    final willBan = !isBanned;

    if (willBan) {
      // Ban nedeni girişi ile onay dialogu
      final reasonController = TextEditingController();
      final result = await showDialog<String?>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$userName Kullanıcısını Banla'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bu kullanıcının hesabını askıya almak istediğinize emin misiniz?',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Ban Nedeni',
                  hintText: 'Örn: Uygunsuz içerik paylaşımı',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceSecondary,
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                reasonController.text.trim().isEmpty
                    ? 'Yönetici tarafından askıya alındı'
                    : reasonController.text.trim(),
              ),
              child: const Text('Banla', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (result == null || !mounted) return;

      await _firestore.collection('users').doc(uid).update({
        'isBanned': true,
        'bannedAt': FieldValue.serverTimestamp(),
        'banReason': result,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$userName banlandı.')));
    } else {
      // Ban kaldırma onayı
      final confirm =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Ban Kaldır'),
              content: Text(
                '$userName kullanıcısının banını kaldırmak istiyor musunuz?',
              ),
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
        SnackBar(content: Text('$userName ban listesinden çıkarıldı.')),
      );
    }
  }

  Future<void> _toggleVerified(
    String uid,
    bool currentlyVerified,
    String userName,
  ) async {
    final willVerify = !currentlyVerified;
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(willVerify ? 'Mavi Tik Ver' : 'Mavi Tik Kaldır'),
            content: Text(
              willVerify
                  ? '$userName kullanıcısına mavi tik vermek istiyor musunuz?'
                  : '$userName kullanıcısının mavi tikini kaldırmak istiyor musunuz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hayır'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(willVerify ? 'Tik Ver' : 'Kaldır'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    await _firestore.collection('users').doc(uid).update({
      'isVerified': willVerify,
      'verifiedAt': willVerify
          ? FieldValue.serverTimestamp()
          : FieldValue.delete(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          willVerify
              ? '$userName mavi tik aldı ✓'
              : '$userName mavi tik kaldırıldı',
        ),
      ),
    );
  }

  Future<void> _viewDocument(String? url) async {
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Belge bulunamadı.')));
      }
      return;
    }

    if (!await launchUrl(Uri.parse(url)) && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Belge açılamadı.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Kullanıcı Yönetimi',
          style: TextStyle(color: AppColors.textHeader),
        ),
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
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Kayıtlı kullanıcı bulunamadı.'));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final uid = users[index].id;

              final email = user['email'] ?? 'Bilinmiyor';
              final name = user['name'] ?? 'Bilinmiyor';
              final role = user['role'] ?? 'student';
              final isApproved = user['isApproved'] ?? false;
              final isBanned = user['isBanned'] == true;
              final docUrl = user['studentDocumentUrl'];
              final isAdmin = role == 'admin';
              final isVerified = user['isVerified'] == true;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: AppColors.surface,
                elevation: isApproved ? 1 : 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isBanned
                        ? Colors.red
                        : (isApproved ? Colors.transparent : Colors.amber),
                    width: isBanned ? 2 : (isApproved ? 0 : 2),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isBanned
                        ? Colors.red[100]
                        : (isAdmin
                              ? Colors.red[100]
                              : (isApproved
                                    ? Colors.blue[100]
                                    : Colors.amber[100])),
                    child: Icon(
                      isBanned
                          ? Icons.block
                          : (isAdmin
                                ? Icons.admin_panel_settings
                                : (isApproved
                                      ? Icons.person
                                      : Icons.pending_actions)),
                      color: isBanned
                          ? Colors.red
                          : (isAdmin
                                ? Colors.red
                                : (isApproved
                                      ? Colors.blue
                                      : Colors.amber[900])),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textHeader,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isBanned && !isAdmin)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'BANLI',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else if (!isApproved && !isAdmin)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ONAY BEKLİYOR',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'Email: $email\nRol: ${role.toUpperCase()}',
                    style: TextStyle(color: AppColors.textBody),
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isAdmin) ...[
                        IconButton(
                          tooltip: isVerified
                              ? 'Mavi Tik Kaldır'
                              : 'Mavi Tik Ver',
                          icon: Icon(
                            Icons.verified,
                            color: isVerified
                                ? const Color(0xFF1DA1F2)
                                : Colors.grey[400],
                          ),
                          onPressed: () =>
                              _toggleVerified(uid, isVerified, name.toString()),
                        ),
                        IconButton(
                          tooltip: 'Belgeyi Görüntüle',
                          icon: Icon(
                            Icons.description_outlined,
                            color: docUrl != null ? Colors.blue : Colors.grey,
                          ),
                          onPressed: () => _viewDocument(docUrl),
                        ),
                        IconButton(
                          tooltip: isApproved ? 'Onayı Kaldır' : 'Onayla',
                          icon: Icon(
                            isApproved
                                ? Icons.cancel_outlined
                                : Icons.check_circle_outline,
                            color: isApproved ? Colors.red : Colors.green,
                          ),
                          onPressed: () => _approveUser(uid, isApproved),
                        ),
                        IconButton(
                          tooltip: isBanned ? 'Ban Kaldır' : 'Banla',
                          icon: Icon(
                            isBanned ? Icons.lock_open : Icons.block,
                            color: isBanned ? Colors.green : Colors.red,
                          ),
                          onPressed: () => _toggleBanUser(
                            uid: uid,
                            isBanned: isBanned,
                            userName: name.toString(),
                          ),
                        ),
                      ],
                      IconButton(
                        tooltip: 'Rolü Değiştir',
                        icon: const Icon(Icons.swap_horiz, color: Colors.grey),
                        onPressed: () => _changeUserRole(uid, role.toString()),
                      ),
                    ],
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
