import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/style/app_colors.dart';
import '../../service/storage_service.dart';
import 'admin_event_preregistrations_view.dart';

class AdminEventsView extends StatefulWidget {
  const AdminEventsView({super.key});

  @override
  State<AdminEventsView> createState() => _AdminEventsViewState();
}

class _AdminEventsViewState extends State<AdminEventsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Tarih belirtilmemiş';
    return DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate());
  }

  String _defaultDiscountNote() {
    return 'Ön kayıt yaptıran öğrenciler etkinlik girişinde öğrenci indirimi ve öncelikli bilgilendirme avantajından yararlanır.';
  }

  String _storageErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'unauthorized':
        return 'Storage yetkisi yok. Firebase Storage kurallarını kontrol et.';
      case 'object-not-found':
        return 'Yüklenecek görsel bulunamadı.';
      case 'bucket-not-found':
        return 'Storage bucket bulunamadı.';
      case 'quota-exceeded':
        return 'Storage kotası aşıldı.';
      case 'network-request-failed':
        return 'İnternet bağlantısı nedeniyle yükleme başarısız oldu.';
      default:
        return e.message ?? 'Görsel yüklenemedi.';
    }
  }

  Future<File?> _pickEventImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Etkinlik Görseli',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.primary,
          cropStyle: CropStyle.rectangle,
          initAspectRatio: CropAspectRatioPreset.ratio16x9,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Etkinlik Görseli'),
      ],
    );
    if (cropped == null) return null;
    return File(cropped.path);
  }

  Future<void> _showAddEventDialog([DocumentSnapshot? doc]) async {
    final existing = doc?.data() as Map<String, dynamic>? ?? {};
    final titleController = TextEditingController(
      text: existing['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: existing['description']?.toString() ?? '',
    );
    final locationController = TextEditingController(
      text: existing['location']?.toString() ?? '',
    );
    final discountController = TextEditingController(
      text:
          existing['preRegistrationDiscountNote']?.toString() ??
          _defaultDiscountNote(),
    );

    var selectedDate = existing['eventDate'] is Timestamp
        ? (existing['eventDate'] as Timestamp).toDate()
        : DateTime.now().add(const Duration(days: 1));
    var preRegistrationEnabled = existing['preRegistrationEnabled'] != false;
    String? existingImageUrl = existing['imageUrl']?.toString();
    if (existingImageUrl != null && existingImageUrl.trim().isEmpty) {
      existingImageUrl = null;
    }
    File? selectedImageFile;
    bool isUploading = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              doc == null ? 'Yeni Etkinlik Ekle' : 'Etkinliği Düzenle',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final file = await _pickEventImage();
                      if (file == null) return;
                      setDialogState(() {
                        selectedImageFile = file;
                      });
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(14),
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
                                  Icons.add_photo_alternate_outlined,
                                  size: 42,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Etkinlik görseli seç',
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Etkinlik Adı',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Açıklama'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Konum (Örn: A Blok)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.calendar_today,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Etkinlik Tarihi'),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate == null) return;
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (pickedTime == null) return;
                      setDialogState(() {
                        selectedDate = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    value: preRegistrationEnabled,
                    activeThumbColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ön kayıt aktif olsun'),
                    subtitle: const Text(
                      'Detay ekranında ön kayıt ve öğrenci indirimi gösterilir.',
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        preRegistrationEnabled = value;
                      });
                    },
                  ),
                  if (preRegistrationEnabled) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: discountController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'İndirim ve bilgilendirme notu',
                      ),
                    ),
                  ],
                  if (isUploading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        if (titleController.text.trim().isEmpty) return;

                        String? finalImageUrl = existingImageUrl;
                        if (selectedImageFile != null) {
                          try {
                            setDialogState(() => isUploading = true);
                            finalImageUrl = await _storageService
                                .uploadEventImage(
                                  selectedImageFile!,
                                  '${DateTime.now().millisecondsSinceEpoch}.jpg',
                                );
                          } on FirebaseException catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_storageErrorMessage(e))),
                            );
                            return;
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Görsel yükleme hatası: $e'),
                              ),
                            );
                            return;
                          } finally {
                            if (mounted) {
                              setDialogState(() => isUploading = false);
                            }
                          }
                        }

                        final data = {
                          'title': titleController.text.trim(),
                          'description': descriptionController.text.trim(),
                          'location': locationController.text.trim(),
                          'imageUrl': finalImageUrl ?? '',
                          'eventDate': Timestamp.fromDate(selectedDate),
                          'preRegistrationEnabled': preRegistrationEnabled,
                          'preRegistrationDiscountNote': preRegistrationEnabled
                              ? discountController.text.trim()
                              : '',
                          'updatedAt': FieldValue.serverTimestamp(),
                        };

                        if (doc == null) {
                          await _firestore.collection('events').add({
                            ...data,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        } else {
                          await _firestore
                              .collection('events')
                              .doc(doc.id)
                              .update(data);
                        }

                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text(
                  'Kaydet',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Etkinliği Sil'),
        content: const Text(
          'Bu etkinliği ve ona ait ön kayıtları silmek istediğine emin misin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
                child: const Text('Hayır'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final batch = _firestore.batch();
    final registrations = await _firestore
        .collection('event_preregistrations')
        .where('eventId', isEqualTo: eventId)
        .get();

    for (final doc in registrations.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_firestore.collection('events').doc(eventId));
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Etkinlik Yönetimi',
          style: TextStyle(color: AppColors.textHeader),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        iconTheme: IconThemeData(color: AppColors.textHeader),
        actions: [
          IconButton(
            tooltip: 'Ön kayıtlar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminEventPreRegistrationsView(),
                ),
              );
            },
            icon: Icon(Icons.how_to_reg_rounded, color: AppColors.primary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEventDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Etkinlik'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('events')
            .orderBy('eventDate', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Henüz etkinlik eklenmemiş.',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            );
          }

          final events = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final data = event.data() as Map<String, dynamic>;
              final eventDate = data['eventDate'] as Timestamp?;
              final date = _formatDate(eventDate);
              final isPast =
                  eventDate != null &&
                  eventDate.toDate().isBefore(DateTime.now());
              final preRegistrationEnabled =
                  data['preRegistrationEnabled'] != false;
              final imageUrl = data['imageUrl']?.toString() ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showAddEventDialog(event),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 92,
                            height: 92,
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: AppColors.surfaceSecondary,
                                        child: const Icon(Icons.broken_image),
                                      );
                                    },
                                  )
                                : Container(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    child: Icon(
                                      Icons.event,
                                      color: AppColors.primary,
                                      size: 34,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['title']?.toString() ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isPast
                                      ? AppColors.textTertiary
                                      : AppColors.textHeader,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                date,
                                style: TextStyle(
                                  color: AppColors.textBody,
                                  fontSize: 12.5,
                                ),
                              ),
                              if ((data['location']?.toString() ?? '')
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    data['location'].toString(),
                                    style: TextStyle(
                                      color: Colors.orange[800],
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (preRegistrationEnabled)
                                    Chip(
                                      label: const Text(
                                        'Ön kayıt açık',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: AppColors.primaryLight,
                                      padding: EdgeInsets.zero,
                                    ),
                                  if (!isPast)
                                    Chip(
                                      label: const Text(
                                        'Görselli kart',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: Colors.orange.withValues(
                                        alpha: 0.12,
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: AppColors.primary),
                              onPressed: () => _showAddEventDialog(event),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteEvent(event.id),
                            ),
                          ],
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
