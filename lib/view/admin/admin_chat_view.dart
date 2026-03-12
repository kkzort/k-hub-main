import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/style/app_colors.dart';

class AdminChatView extends StatefulWidget {
  const AdminChatView({super.key});

  @override
  State<AdminChatView> createState() => _AdminChatViewState();
}

class _AdminChatViewState extends State<AdminChatView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _deleteMessage(String docId) async {
    bool confirm = await showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text("Mesajı Sil"),
         content: const Text("Bu mesajı silmek istediğinizden emin misiniz? (Tüm kullanıcılardan silinecektir.)"),
         actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
            TextButton(
              onPressed: () => Navigator.pop(context, true), 
              child: const Text("Sil", style: TextStyle(color: Colors.red)),
            ),
         ],
       ),
    );

    if (confirm) {
       await _firestore.collection('messages').doc(docId).delete();
       if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Mesaj veritabanından başarıyla silindi.")),
           );
       }
    }
  }

  String _formatDate(Timestamp? t) {
     if (t == null) return "Bilinmeyen Tarih";
     return DateFormat('dd.MM.yyyy HH:mm:ss').format(t.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Sohbet Yönetimi", style: TextStyle(color: AppColors.textHeader)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        iconTheme: IconThemeData(color: AppColors.textHeader),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Henüz hiç mesaj atılmamış."));
          }

          final messages = snapshot.data!.docs;

          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
               var msg = messages[index].data() as Map<String, dynamic>;
               String text = msg['text'] ?? "Bos Mesaj";
               String sender = msg['senderName'] ?? "Bilinmiyor";
               String email = msg['senderEmail'] ?? "";
               String time = _formatDate(msg['createdAt'] as Timestamp?);

               return Card(
                 margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                 color: AppColors.surface,
                 child: ListTile(
                   leading: CircleAvatar(
                     backgroundColor: AppColors.surfaceSecondary,
                     child: Icon(Icons.chat_bubble_outline, color: AppColors.textTertiary),
                   ),
                   title: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHeader)),
                   subtitle: Text("Gönderen: $sender ($email)\nTarih: $time", style: TextStyle(color: AppColors.textBody)),
                   isThreeLine: true,
                   trailing: IconButton(
                     tooltip: "Bu mesajı kalıcı olarak sil",
                     icon: const Icon(Icons.delete, color: Colors.red),
                     onPressed: () => _deleteMessage(messages[index].id),
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
