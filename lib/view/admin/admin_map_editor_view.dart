import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../home/interactive_svg_map.dart';
import '../../core/style/app_colors.dart';
import '../../service/storage_service.dart';

class AdminMapEditorView extends StatefulWidget {
  const AdminMapEditorView({super.key});

  @override
  State<AdminMapEditorView> createState() => _AdminMapEditorViewState();
}

class _AdminMapEditorViewState extends State<AdminMapEditorView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'Kampüs', 'Kafe', 'Restoran', 'Market', 'Sağlık', 'Eğlence'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Harita Mekan Ekle"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Talimat: Yeni bir mekan eklemek için harita üzerinde istediğiniz noktaya dokunun.",
              style: TextStyle(color: AppColors.textBody, fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('places').snapshots(),
              builder: (context, snapshot) {
                final places = snapshot.data?.docs ?? [];
                
                // Mevcut pinleri harita üzerinde göster
                final existingMarkers = places.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return d.containsKey('mapX') && d.containsKey('mapY');
                }).map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return SvgMarker(
                    x: (d['mapX'] as num).toDouble(),
                    y: (d['mapY'] as num).toDouble(),
                    size: 24,
                    child: Icon(Icons.location_on, color: AppColors.primary.withValues(alpha: 0.6), size: 24),
                  );
                }).toList();

                return Container(
                  margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: InteractiveSvgMap(
                      svgAsset: 'assets/images/campus_map.svg',
                      markers: existingMarkers,
                      onMapTap: (offset) => _showAddPlaceSheet(offset),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPlaceSheet(Offset offset) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = _categories.first;
    File? selectedImage;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Yeni Mekan Ekle", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Image Picker
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setSheetState(() => selectedImage = File(image.path));
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(selectedImage!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 40, color: AppColors.primary),
                                const SizedBox(height: 8),
                                const Text("Fotoğraf Ekle (Opsiyonel)"),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Mekan Adı",
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: "Açıklama",
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: "Kategori",
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setSheetState(() => selectedCategory = val!),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    if (nameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir isim girin")));
                      return;
                    }

                    setSheetState(() => isUploading = true);

                    try {
                      List<String> imageUrls = [];
                      if (selectedImage != null) {
                        final url = await _storageService.uploadPlaceImage(
                          selectedImage!, 
                          "${nameController.text}_${DateTime.now().millisecondsSinceEpoch}.jpg"
                        );
                        if (url != null) imageUrls.add(url);
                      }

                      await _firestore.collection('places').add({
                        'name': nameController.text.trim(),
                        'description': descController.text.trim(),
                        'category': selectedCategory,
                        'mapX': offset.dx,
                        'mapY': offset.dy,
                        'imageUrls': imageUrls,
                        'avgRating': 0.0,
                        'ratingCount': 0,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Mekan başarıyla eklendi!"), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      setSheetState(() => isUploading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isUploading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("MEKANI KAYDET", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
