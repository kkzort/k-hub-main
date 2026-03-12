import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/style/app_colors.dart';

class AdminNotificationsView extends StatefulWidget {
  const AdminNotificationsView({super.key});

  @override
  State<AdminNotificationsView> createState() =>
      _AdminNotificationsViewState();
}

class _AdminNotificationsViewState extends State<AdminNotificationsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showSendNotificationDialog() {
    final titleC = TextEditingController();
    final bodyC = TextEditingController();
    String selectedType = 'info';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Bildirim Gönder"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: "Bildirim Türü"),
                items: const [
                  DropdownMenuItem(
                      value: 'info',
                      child: Row(children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text("Bilgi")
                      ])),
                  DropdownMenuItem(
                      value: 'warning',
                      child: Row(children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Text("Uyarı")
                      ])),
                  DropdownMenuItem(
                      value: 'success',
                      child: Row(children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text("Başarı")
                      ])),
                  DropdownMenuItem(
                      value: 'urgent',
                      child: Row(children: [
                        Icon(Icons.priority_high, color: Colors.red),
                        SizedBox(width: 8),
                        Text("Acil")
                      ])),
                ],
                onChanged: (val) =>
                    setDialogState(() => selectedType = val!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: titleC,
                decoration:
                    const InputDecoration(labelText: "Başlık"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bodyC,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: "Mesaj içeriği"),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("İptal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              onPressed: () async {
                if (titleC.text.isEmpty || bodyC.text.isEmpty) return;
                await _firestore.collection('notifications').add({
                  'title': titleC.text,
                  'body': bodyC.text,
                  'type': selectedType,
                  'createdAt': FieldValue.serverTimestamp(),
                  'readBy': [],
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ Bildirim tüm kullanıcılara gönderildi!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text("Gönder",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteNotification(String id) async {
    await _firestore.collection('notifications').doc(id).delete();
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'warning':
        return Colors.orange;
      case 'success':
        return Colors.green;
      case 'urgent':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'warning':
        return Icons.warning;
      case 'success':
        return Icons.check_circle;
      case 'urgent':
        return Icons.priority_high;
      default:
        return Icons.info;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'warning':
        return 'Uyarı';
      case 'success':
        return 'Başarı';
      case 'urgent':
        return 'Acil';
      default:
        return 'Bilgi';
    }
  }

  String _formatDate(Timestamp? t) {
    if (t == null) return '';
    return DateFormat('dd.MM.yyyy HH:mm').format(t.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Bildirim Yönetimi", style: TextStyle(color: AppColors.textHeader)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        iconTheme: IconThemeData(color: AppColors.textHeader),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSendNotificationDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.send),
        label: const Text("Bildirim Gönder"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Text("Henüz bildirim gönderilmemiş.",
                    style: TextStyle(color: AppColors.textTertiary)));
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var n =
                  notifications[index].data() as Map<String, dynamic>;
              String type = n['type'] ?? 'info';
              List readBy = n['readBy'] ?? [];
              Color color = _typeColor(type);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(_typeIcon(type), color: color),
                  ),
                  title: Text(
                    n['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${n['body'] ?? ''}\n${_formatDate(n['createdAt'] as Timestamp?)} • ${readBy.length} kişi okudu",
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: SizedBox(
                    width: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Chip(
                            label: Text(_typeLabel(type),
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white)),
                            backgroundColor: color,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red, size: 20),
                          onPressed: () =>
                              _deleteNotification(notifications[index].id),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36),
                        ),
                      ],
                    ),
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
