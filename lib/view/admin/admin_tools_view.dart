import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/style/app_colors.dart';

class AdminToolsView extends StatefulWidget {
  const AdminToolsView({super.key});

  @override
  State<AdminToolsView> createState() => _AdminToolsViewState();
}

class _AdminToolsViewState extends State<AdminToolsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<Map<String, dynamic>> _defaultTools = [
    {'title': 'Liderlik Tablosu', 'iconName': 'emoji_events', 'order': 1},
    {'title': 'Yemekhane', 'iconName': 'restaurant_menu', 'order': 2},
    {'title': 'Interaktif Harita', 'iconName': 'map', 'order': 3},
    {'title': 'Etkinlik Takvimi', 'iconName': 'calendar_month', 'order': 4},
    {'title': 'Oy Ver', 'iconName': 'how_to_vote', 'order': 5},
    {'title': 'Yapay Zeka', 'iconName': 'smart_toy', 'order': 6},
    {'title': 'K-Bot', 'iconName': 'auto_awesome', 'order': 7},
    {'title': 'Akademik Takvim', 'iconName': 'event_note', 'order': 8},
    {'title': 'Etkinlikler', 'iconName': 'event_available', 'order': 9},
  ];

  @override
  void initState() {
    super.initState();
    _seedDefaultTools();
  }

  Future<void> _seedDefaultTools() async {
    final versionDoc = await _firestore
        .collection('tools_meta')
        .doc('version')
        .get();
    final currentVersion = versionDoc.exists ? versionDoc['v'] : null;
    if (currentVersion == 'v3') return;

    final existing = await _firestore.collection('tools').get();
    final existingByTitle = <String, DocumentSnapshot>{};
    for (final doc in existing.docs) {
      final data = doc.data();
      final title = data['title']?.toString();
      if (title != null && title.isNotEmpty) {
        existingByTitle[title] = doc;
      }
    }

    for (final tool in _defaultTools) {
      final title = tool['title'] as String;
      final existingDoc = existingByTitle[title];
      if (existingDoc == null) {
        await _firestore.collection('tools').add({
          'title': tool['title'],
          'iconName': tool['iconName'],
          'isActive': true,
          'order': tool['order'],
        });
      } else {
        await _firestore.collection('tools').doc(existingDoc.id).set({
          'title': tool['title'],
          'iconName': tool['iconName'],
          'order': tool['order'],
        }, SetOptions(merge: true));
      }
    }

    await _firestore.collection('tools_meta').doc('version').set({
      'v': 'v3',
    }, SetOptions(merge: true));
  }

  void _showAddToolDialog([DocumentSnapshot? document]) {
    final titleController = TextEditingController(
      text: document != null ? document['title'] : '',
    );
    final iconController = TextEditingController(
      text: document != null ? document['iconName'] : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(document == null ? 'Yeni Arac Ekle' : 'Araci Duzenle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Arac Adi'),
              ),
              TextField(
                controller: iconController,
                decoration: const InputDecoration(labelText: 'Ikon Adi'),
              ),
              const SizedBox(height: 10),
              Text(
                'Ikon adlari icin Material Icons listesini kullanabilirsiniz.',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty ||
                    iconController.text.isEmpty) {
                  return;
                }

                if (document == null) {
                  await _firestore.collection('tools').add({
                    'title': titleController.text,
                    'iconName': iconController.text,
                    'isActive': true,
                    'order': 0,
                  });
                } else {
                  await _firestore.collection('tools').doc(document.id).update({
                    'title': titleController.text,
                    'iconName': iconController.text,
                  });
                }

                if (mounted) Navigator.pop(context);
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTool(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silmeyi Onayla'),
        content: const Text('Bu araci silmek istediginizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hayir'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('tools').doc(docId).delete();
    }
  }

  Future<void> _toggleToolStatus(String docId, bool currentStatus) async {
    await _firestore.collection('tools').doc(docId).update({
      'isActive': !currentStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Araclari Yonet',
          style: TextStyle(color: AppColors.textHeader),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        iconTheme: IconThemeData(color: AppColors.textHeader),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddToolDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('tools').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Henuz hic arac eklenmemis.'));
          }

          final tools = snapshot.data!.docs;
          return ListView(
            children: [
              ...tools.map((tool) {
                final bool isActive = tool['isActive'] ?? true;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  color: AppColors.surface,
                  child: ListTile(
                    leading: Icon(Icons.build_circle, color: AppColors.primary),
                    title: Text(
                      tool['title'],
                      style: TextStyle(color: AppColors.textHeader),
                    ),
                    subtitle: Text(
                      'Ikon: ${tool['iconName']}',
                      style: TextStyle(color: AppColors.textBody),
                    ),
                    trailing: SizedBox(
                      width: 140,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 44,
                            child: Switch(
                              value: isActive,
                              onChanged: (val) =>
                                  _toggleToolStatus(tool.id, isActive),
                              activeTrackColor: AppColors.primary,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            onPressed: () => _showAddToolDialog(tool),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () => _deleteTool(tool.id),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
