import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/style/app_colors.dart';

class AdminNotesView extends StatefulWidget {
  const AdminNotesView({super.key});

  @override
  State<AdminNotesView> createState() => _AdminNotesViewState();
}

class _AdminNotesViewState extends State<AdminNotesView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _deleteNote(String docId) async {
     bool confirm = await showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text("Notu Sil"),
         content: const Text("Bu notu sistemden tamamen silmek istediğinize emin misiniz?"),
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
       await _firestore.collection('notes').doc(docId).delete();
       if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Not başarıyla silindi.")),
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
        title: Text("Not Yönetimi", style: TextStyle(color: AppColors.textHeader)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        iconTheme: IconThemeData(color: AppColors.textHeader),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Sistemde henüz hiç not yok."));
          }

          final notes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
               var note = notes[index].data() as Map<String, dynamic>;
               String title = note['title'] ?? "Başlıksız Not";
               String author = note['userName'] ?? "Bilinmiyor";
               String course = note['course'] ?? "Bilinmeyen Ders";
               String time = _formatDate(note['createdAt'] as Timestamp?);
               int likes = (note['likes'] is int) ? note['likes'] : 0;

               return Card(
                 margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                 color: AppColors.surface,
                 child: ListTile(
                   leading: CircleAvatar(
                     backgroundColor: AppColors.primaryLight,
                     child: Icon(Icons.menu_book, color: AppColors.primary),
                   ),
                   title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHeader)),
                   subtitle: Text("Yazar: $author | Ders: $course\nTarih: $time | $likes Beğeni", style: TextStyle(color: AppColors.textBody)),
                   isThreeLine: true,
                   trailing: IconButton(
                     tooltip: "Bu notu sil",
                     icon: const Icon(Icons.delete, color: Colors.red),
                     onPressed: () => _deleteNote(notes[index].id),
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
