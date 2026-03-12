import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/style/app_colors.dart';

class AdminPollsView extends StatefulWidget {
  const AdminPollsView({super.key});

  @override
  State<AdminPollsView> createState() => _AdminPollsViewState();
}

class _AdminPollsViewState extends State<AdminPollsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showAddPollDialog() {
    final questionC = TextEditingController();
    final List<TextEditingController> optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Yeni Anket Oluştur"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: questionC,
                  decoration:
                      const InputDecoration(labelText: "Soru"),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text("Seçenekler:",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ...optionControllers.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: entry.value,
                              decoration: InputDecoration(
                                labelText: "Seçenek ${entry.key + 1}",
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          if (optionControllers.length > 2)
                            IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red),
                              onPressed: () {
                                setDialogState(() =>
                                    optionControllers.removeAt(entry.key));
                              },
                            ),
                        ],
                      ),
                    )),
                if (optionControllers.length < 6)
                  TextButton.icon(
                    onPressed: () {
                      setDialogState(() =>
                          optionControllers.add(TextEditingController()));
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Seçenek Ekle"),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("İptal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              onPressed: () async {
                if (questionC.text.isEmpty) return;
                final options = optionControllers
                    .map((c) => c.text.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();
                if (options.length < 2) return;

                final optionData = options
                    .map((o) => {'text': o, 'votes': 0})
                    .toList();

                await _firestore.collection('polls').add({
                  'question': questionC.text,
                  'options': optionData,
                  'isActive': true,
                  'createdAt': FieldValue.serverTimestamp(),
                  'totalVotes': 0,
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Yayınla",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePollStatus(String id, bool current) async {
    await _firestore
        .collection('polls')
        .doc(id)
        .update({'isActive': !current});
  }

  void _deletePoll(String id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Anketi Sil"),
        content: const Text("Bu anket ve tüm oylar silinecek."),
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
    if (confirm == true) {
      await _firestore.collection('polls').doc(id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Anket Yönetimi", style: TextStyle(color: AppColors.textHeader)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        iconTheme: IconThemeData(color: AppColors.textHeader),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPollDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Yeni Anket"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('polls')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Text("Henüz anket oluşturulmamış.",
                    style: TextStyle(color: AppColors.textTertiary)));
          }

          final polls = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: polls.length,
            itemBuilder: (context, index) {
              var poll = polls[index].data() as Map<String, dynamic>;
              bool isActive = poll['isActive'] ?? true;
              int totalVotes = poll['totalVotes'] ?? 0;
              List options = poll['options'] ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              poll['question'] ?? '',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textHeader),
                            ),
                          ),
                          Switch(
                            value: isActive,
                            onChanged: (_) =>
                                _togglePollStatus(polls[index].id, isActive),
                            activeTrackColor: AppColors.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("Toplam Oy: $totalVotes",
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textTertiary)),
                      const SizedBox(height: 8),
                      ...options.map((opt) {
                        int votes = opt['votes'] ?? 0;
                        double percent =
                            totalVotes > 0 ? votes / totalVotes : 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(opt['text'] ?? '',
                                      style: const TextStyle(fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 8),
                                Text("$votes oy",
                                    style: TextStyle(
                                        fontSize: 12, color: AppColors.textTertiary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: percent,
                              backgroundColor: AppColors.surfaceSecondary,
                              color: AppColors.primary,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      }),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _deletePoll(polls[index].id),
                          icon: const Icon(Icons.delete,
                              color: Colors.red, size: 16),
                          label: const Text("Sil",
                              style: TextStyle(color: Colors.red)),
                        ),
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
