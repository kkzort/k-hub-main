import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/style/app_colors.dart';
import '../home/home_view.dart';

class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _formatDate(Timestamp? t) {
    if (t == null) return "Bilinmeyen Tarih";
    return DateFormat('dd.MM.yyyy HH:mm').format(t.toDate());
  }

  void _deleteReport(String reportId) async {
    await _firestore.collection('reports').doc(reportId).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Şikayet kapatıldı.")),
      );
    }
  }

  void _deleteNoteAndReport(String reportId, String noteId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Notu Sil"),
        content: const Text(
            "Bu not ve ilgili şikayet kalıcı olarak silinecek. Emin misiniz?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("İptal")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (noteId.isNotEmpty) {
      await _firestore.collection('notes').doc(noteId).delete();
    }
    await _firestore.collection('reports').doc(reportId).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Not ve şikayet silindi."),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Şikayet Yönetimi", style: TextStyle(color: AppColors.textHeader)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        iconTheme: IconThemeData(color: AppColors.textHeader),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: AppColors.success),
                  const SizedBox(height: 16),
                  Text("Hiç şikayet yok!",
                      style:
                          TextStyle(fontSize: 18, color: AppColors.textTertiary)),
                ],
              ),
            );
          }

          final reports = snapshot.data!.docs;

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              var report =
                  reports[index].data() as Map<String, dynamic>;
              String noteId = report['noteId'] ?? '';
              String reporter = report['reporterEmail'] ?? 'Bilinmiyor';
              String reason =
                  report['reason'] ?? 'Sebep belirtilmemiş';
              String date = _formatDate(report['createdAt'] as Timestamp?);

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flag, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textHeader),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text("Şikayet Eden: $reporter",
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textTertiary)),
                      Text("Tarih: $date",
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textTertiary)),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              if (noteId.isEmpty) return;
                              final noteDoc = await _firestore.collection('notes').doc(noteId).get();
                              if (noteDoc.exists && mounted) {
                                final data = noteDoc.data() as Map<String, dynamic>;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => NoteDetailView(
                                      noteId: noteId,
                                      data: data,
                                      currentUserEmail: 'admin@k-hub.com',
                                    ),
                                  ),
                                );
                              } else if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Not bulunamadı (silinmiş olabilir).")));
                              }
                            },
                            icon: const Icon(Icons.visibility_rounded, size: 16),
                            label: const Text("İncele"),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _deleteReport(reports[index].id),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text("Kapat"),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _deleteNoteAndReport(
                                reports[index].id, noteId),
                            icon: const Icon(Icons.delete, size: 16),
                            label: const Text("Notu Sil"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
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
