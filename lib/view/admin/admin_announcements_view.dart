import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/style/app_colors.dart';
import '../../service/storage_service.dart';

class AdminAnnouncementsView extends StatefulWidget {
  const AdminAnnouncementsView({super.key});

  @override
  State<AdminAnnouncementsView> createState() => _AdminAnnouncementsViewState();
}

class _AdminAnnouncementsViewState extends State<AdminAnnouncementsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  String _storageErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'unauthorized':
        return 'Storage yetkisi yok (unauthorized). Firebase Storage kurallarini kontrol edin.';
      case 'object-not-found':
        return 'Yuklenecek dosya bulunamadi.';
      case 'bucket-not-found':
        return 'Storage bucket bulunamadi. Firebase config kontrol edilmeli.';
      case 'project-not-found':
        return 'Firebase projesi bulunamadi veya baglanti sorunu var.';
      case 'quota-exceeded':
        return 'Storage kotasi asildi.';
      case 'retry-limit-exceeded':
        return 'Baglanti sorunu nedeniyle yukleme zaman asimina ugradi.';
      case 'network-request-failed':
        return 'Internet baglantisi nedeniyle yukleme basarisiz oldu.';
      default:
        return e.message ?? 'Gorsel yuklenemedi.';
    }
  }

  void _showAddAnnouncementDialog([DocumentSnapshot? document]) {
    final existingData = document?.data() as Map<String, dynamic>? ?? {};
    final titleController = TextEditingController(
      text: existingData['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: existingData['description']?.toString() ?? '',
    );
    final fullContentController = TextEditingController(
      text: existingData['fullContent']?.toString() ?? '',
    );

    String selectedType = existingData['type']?.toString() ?? 'slider';
    String? existingImageUrl = existingData['imageUrl']?.toString();
    if (existingImageUrl != null && existingImageUrl.trim().isEmpty) {
      existingImageUrl = null;
    }
    File? selectedImageFile;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(document == null ? "Yeni Ekle" : "Duzenle"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: "Gosterim Yeri",
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "slider",
                          child: Text("Ana Sayfa Slider (Ust Kisim)"),
                        ),
                        DropdownMenuItem(
                          value: "opportunity",
                          child: Text("Firsatlar Listesi (Alt Kisim)"),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setDialogState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: "Baslik"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Kisa Aciklama (Listede gorunur)",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: fullContentController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: "Detayli Bilgi (Tiklayinca acilir)",
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () async {
                        final picked = await _imagePicker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (picked == null) return;

                        final cropped = await ImageCropper().cropImage(
                          sourcePath: picked.path,
                          uiSettings: [
                            AndroidUiSettings(
                              toolbarTitle: 'Gorseli Duzenle',
                              toolbarColor: AppColors.primary,
                              toolbarWidgetColor: Colors.white,
                              activeControlsWidgetColor: AppColors.primary,
                              cropStyle: CropStyle.rectangle,
                              initAspectRatio: CropAspectRatioPreset.ratio16x9,
                              lockAspectRatio: false,
                            ),
                            IOSUiSettings(title: 'Gorseli Duzenle'),
                          ],
                        );
                        if (cropped == null) return;

                        setDialogState(() {
                          selectedImageFile = File(cropped.path);
                        });
                      },
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                          image: selectedImageFile != null
                              ? DecorationImage(
                                  image: FileImage(selectedImageFile!),
                                  fit: BoxFit.cover,
                                )
                              : (existingImageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(existingImageUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null),
                        ),
                        child:
                            (selectedImageFile == null &&
                                existingImageUrl == null)
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Cihazdan Gorsel Sec",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              )
                            : Align(
                                alignment: Alignment.bottomRight,
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    if (isUploading)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Iptal"),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Baslik zorunludur!"),
                              ),
                            );
                            return;
                          }

                          if (selectedImageFile == null &&
                              existingImageUrl == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Lutfen bir gorsel secin!"),
                              ),
                            );
                            return;
                          }

                          String? finalImageUrl = existingImageUrl;
                          if (selectedImageFile != null) {
                            try {
                              setDialogState(() => isUploading = true);
                              final uploaded = await _storageService
                                  .uploadAnnouncementImage(
                                    selectedImageFile!,
                                    '${DateTime.now().millisecondsSinceEpoch}.jpg',
                                  );
                              finalImageUrl = uploaded;
                            } on FirebaseException catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_storageErrorMessage(e)),
                                ),
                              );
                              return;
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gorsel yukleme hatasi: $e'),
                                ),
                              );
                              return;
                            } finally {
                              if (mounted) {
                                setDialogState(() => isUploading = false);
                              }
                            }
                          }

                          if (finalImageUrl == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Gorsel bulunamadi."),
                              ),
                            );
                            return;
                          }

                          if (document == null) {
                            await _firestore.collection('announcements').add({
                              'title': titleController.text.trim(),
                              'description': descriptionController.text.trim(),
                              'fullContent': fullContentController.text.trim(),
                              'imageUrl': finalImageUrl,
                              'type': selectedType,
                              'isActive': true,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            await _firestore
                                .collection('announcements')
                                .doc(document.id)
                                .update({
                                  'title': titleController.text.trim(),
                                  'description': descriptionController.text
                                      .trim(),
                                  'fullContent': fullContentController.text
                                      .trim(),
                                  'imageUrl': finalImageUrl,
                                  'type': selectedType,
                                });
                          }

                          if (mounted) Navigator.pop(context);
                        },
                  child: const Text("Kaydet"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteAnnouncement(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Silmeyi Onayla"),
        content: const Text("Bunu silmek istediginizden emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hayir"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Evet, Sil"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('announcements').doc(docId).delete();
    }
  }

  void _toggleStatus(String docId, bool currentStatus) async {
    await _firestore.collection('announcements').doc(docId).update({
      'isActive': !currentStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Duyuru & Firsat Yonetimi", style: TextStyle(color: AppColors.textHeader)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        iconTheme: IconThemeData(color: AppColors.textHeader),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAnnouncementDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Yeni Ekle"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Henuz hic duyuru eklenmemis."));
          }

          final items = snapshot.data!.docs;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index].data() as Map<String, dynamic>;
              final isActive = item['isActive'] ?? true;
              final typeStr = item['type'] == 'slider'
                  ? "Slider (Ust)"
                  : "Firsat (Alt)";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: AppColors.surface,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: item['imageUrl'] != null
                        ? NetworkImage(item['imageUrl'])
                        : null,
                    backgroundColor: AppColors.surfaceSecondary,
                    child: item['imageUrl'] == null
                        ? const Icon(Icons.image)
                        : null,
                  ),
                  title: Text(item['title'] ?? 'Isimsiz', style: TextStyle(color: AppColors.textHeader)),
                  subtitle: Text(
                    "Tur: $typeStr\nDurum: ${isActive ? 'Yayinda' : 'Gizli'}",
                    style: TextStyle(color: AppColors.textBody),
                  ),
                  isThreeLine: true,
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
                                _toggleStatus(items[index].id, isActive),
                            activeTrackColor: AppColors.primary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit, color: AppColors.primary, size: 20),
                          onPressed: () =>
                              _showAddAnnouncementDialog(items[index]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _deleteAnnouncement(items[index].id),
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
