import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../core/style/app_colors.dart';
import '../../service/storage_service.dart';

class AdminMapView extends StatefulWidget {
  const AdminMapView({super.key});

  @override
  State<AdminMapView> createState() => _AdminMapViewState();
}

class _AdminMapViewState extends State<AdminMapView>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  final List<String> _categories = [
    'Kampüs',
    'Kafe',
    'Restoran',
    'Market',
    'Sağlık',
    'Eğlence',
    'Diğer',
  ];

  final List<Map<String, String>> _iconOptions = [
    {'name': 'engineering', 'label': 'Mühendislik'},
    {'name': 'library', 'label': 'Kütüphane'},
    {'name': 'restaurant', 'label': 'Restoran'},
    {'name': 'fitness', 'label': 'Spor'},
    {'name': 'corporate', 'label': 'Kurumsal'},
    {'name': 'groups', 'label': 'Topluluk'},
    {'name': 'coffee', 'label': 'Kafe'},
    {'name': 'food', 'label': 'Yemek'},
    {'name': 'shop', 'label': 'Market'},
    {'name': 'hospital', 'label': 'Hastane'},
    {'name': 'pharmacy', 'label': 'Eczane'},
    {'name': 'cinema', 'label': 'Sinema'},
    {'name': 'bowling', 'label': 'Bowling'},
    {'name': 'place', 'label': 'Mekan'},
  ];
  static final LatLngBounds _mapBounds = LatLngBounds(
    const LatLng(39.8100, 33.4100),
    const LatLng(39.9050, 33.5850),
  );
  static const LatLng _defaultMapCenter = LatLng(39.8450, 33.5000);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _placeIcon(String iconName) {
    switch (iconName) {
      case 'engineering':
        return Icons.engineering;
      case 'library':
        return Icons.local_library;
      case 'restaurant':
        return Icons.restaurant;
      case 'fitness':
        return Icons.fitness_center;
      case 'corporate':
        return Icons.corporate_fare;
      case 'groups':
        return Icons.groups;
      case 'coffee':
        return Icons.coffee;
      case 'food':
        return Icons.fastfood;
      case 'shop':
        return Icons.shopping_bag;
      case 'hospital':
        return Icons.local_hospital;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'cinema':
        return Icons.movie;
      case 'bowling':
        return Icons.sports;
      default:
        return Icons.place;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Kampüs':
        return Colors.indigo;
      case 'Kafe':
        return Colors.brown;
      case 'Restoran':
        return Colors.red;
      case 'Market':
        return Colors.green;
      case 'Sağlık':
        return Colors.pink;
      case 'Eğlence':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // ─── MEKAN EKLE / DÜZENLE DİALOG ───
  void _showPlaceDialog([DocumentSnapshot? document]) {
    final nameC = TextEditingController();
    final descC = TextEditingController();
    final addressC = TextEditingController();
    final phoneC = TextEditingController();
    final hoursC = TextEditingController();
    String selectedCategory = _categories[0];
    String selectedIcon = 'place';
    LatLng? selectedLatLng;
    List<String> imageUrls = [];
    bool isUploading = false;

    if (document != null) {
      final data = document.data() as Map<String, dynamic>;
      nameC.text = data['name'] ?? '';
      descC.text = data['description'] ?? '';
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        selectedLatLng = LatLng(lat, lng);
      }
      addressC.text = data['address'] ?? '';
      phoneC.text = data['phone'] ?? '';
      hoursC.text = data['hours'] ?? '';
      selectedCategory = data['category'] ?? _categories[0];
      selectedIcon = data['iconName'] ?? 'place';
      imageUrls = List<String>.from(data['imageUrls'] ?? []);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                document == null ? "Yeni Mekan Ekle" : "Mekanı Düzenle",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kategori
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: "Kategori",
                        ),
                        items: _categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: _categoryColor(c),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(c),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => selectedCategory = val!),
                      ),
                      const SizedBox(height: 10),

                      // Ad
                      TextField(
                        controller: nameC,
                        decoration: const InputDecoration(
                          labelText: "Mekan Adı *",
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Açıklama
                      TextField(
                        controller: descC,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: "Açıklama *",
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Koordinatlar
                      const Text(
                        "Konum *",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          height: 220,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter:
                                  selectedLatLng ?? _defaultMapCenter,
                              initialZoom: selectedLatLng == null ? 12.6 : 15,
                              minZoom: 12.2,
                              maxZoom: 18.5,
                              cameraConstraint: CameraConstraint.contain(
                                bounds: _mapBounds,
                              ),
                              onTap: (_, latLng) {
                                setDialogState(() => selectedLatLng = latLng);
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.k_hub',
                              ),
                              MarkerLayer(
                                markers: selectedLatLng == null
                                    ? []
                                    : [
                                        Marker(
                                          point: selectedLatLng!,
                                          width: 44,
                                          height: 44,
                                          child: const Icon(
                                            Icons.location_on,
                                            color: Colors.red,
                                            size: 36,
                                          ),
                                        ),
                                      ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "İpucu: Google Maps'ten koordinatları kopyalayabilirsiniz",
                        style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: 10),

                      // Adres
                      TextField(
                        controller: addressC,
                        decoration: const InputDecoration(labelText: "Adres"),
                      ),
                      const SizedBox(height: 10),

                      // Telefon ve Çalışma Saatleri
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: phoneC,
                              decoration: const InputDecoration(
                                labelText: "Telefon",
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: hoursC,
                              decoration: const InputDecoration(
                                labelText: "Çalışma Saatleri",
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // İkon seçimi
                      const Text(
                        "İkon Seçin:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _iconOptions.map((opt) {
                          final isSelected = selectedIcon == opt['name'];
                          return GestureDetector(
                            onTap: () => setDialogState(
                              () => selectedIcon = opt['name']!,
                            ),
                            child: Tooltip(
                              message: opt['label']!,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _categoryColor(
                                          selectedCategory,
                                        ).withValues(alpha: 0.15)
                                      : AppColors.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? _categoryColor(selectedCategory)
                                        : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Icon(
                                  _placeIcon(opt['name']!),
                                  size: 22,
                                  color: isSelected
                                      ? _categoryColor(selectedCategory)
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Görseller
                      const Text(
                        "Görseller:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (imageUrls.isNotEmpty)
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: imageUrls.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      image: DecorationImage(
                                        image: NetworkImage(imageUrls[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 10,
                                    child: GestureDetector(
                                      onTap: () {
                                        setDialogState(() {
                                          imageUrls.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: isUploading
                            ? null
                            : () async {
                                setDialogState(() => isUploading = true);
                                final picker = ImagePicker();
                                final image = await picker.pickImage(
                                  source: ImageSource.gallery,
                                );
                                if (image != null) {
                                  final file = File(image.path);
                                  final storageService = StorageService();
                                  final url = await storageService
                                      .uploadPlaceImage(file, image.name);
                                  if (url != null) {
                                    setDialogState(() {
                                      imageUrls.add(url);
                                      isUploading = false;
                                    });
                                  } else {
                                    setDialogState(() => isUploading = false);
                                  }
                                } else {
                                  setDialogState(() => isUploading = false);
                                }
                              },
                        icon: isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_photo_alternate),
                        label: Text(
                          isUploading ? "Yükleniyor..." : "Görsel Ekle",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("İptal"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (nameC.text.isEmpty ||
                        descC.text.isEmpty ||
                        selectedLatLng == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Ad, açıklama ve koordinatlar zorunludur!",
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final lat = selectedLatLng?.latitude;
                    final lng = selectedLatLng?.longitude;
                    if (lat == null || lng == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Geçerli koordinat girin! (örn: 36.8121)",
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final placeData = {
                      'name': nameC.text.trim(),
                      'description': descC.text.trim(),
                      'category': selectedCategory,
                      'lat': selectedLatLng!.latitude,
                      'lng': selectedLatLng!.longitude,
                      'iconName': selectedIcon,
                      'imageUrls': imageUrls,
                      'address': addressC.text.trim().isEmpty
                          ? null
                          : addressC.text.trim(),
                      'phone': phoneC.text.trim().isEmpty
                          ? null
                          : phoneC.text.trim(),
                      'hours': hoursC.text.trim().isEmpty
                          ? null
                          : hoursC.text.trim(),
                    };

                    if (document == null) {
                      placeData['avgRating'] = 0.0;
                      placeData['ratingCount'] = 0;
                      placeData['createdAt'] = FieldValue.serverTimestamp();
                      await _firestore.collection('places').add(placeData);
                    } else {
                      await _firestore
                          .collection('places')
                          .doc(document.id)
                          .update(placeData);
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            document == null
                                ? "Mekan eklendi! ✅"
                                : "Mekan güncellendi! ✅",
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: Text(document == null ? "Ekle" : "Güncelle"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Mekan silme
  void _deletePlace(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mekanı Sil"),
        content: const Text(
          "Bu mekan, tüm puanları ve yorumlarıyla birlikte silinecek. Emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Alt koleksiyonları da sil
      final ratings = await _firestore
          .collection('places')
          .doc(docId)
          .collection('ratings')
          .get();
      for (var doc in ratings.docs) {
        await doc.reference.delete();
      }
      final comments = await _firestore
          .collection('places')
          .doc(docId)
          .collection('comments')
          .get();
      for (var doc in comments.docs) {
        await doc.reference.delete();
      }
      await _firestore.collection('places').doc(docId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mekan ve tüm verileri silindi."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Harita Yönetimi", style: TextStyle(color: AppColors.textHeader)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        iconTheme: IconThemeData(color: AppColors.textHeader),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          tabs: const [
            Tab(icon: Icon(Icons.map, size: 18), text: "Mekanlar"),
            Tab(icon: Icon(Icons.comment, size: 18), text: "Yorumlar"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPlaceDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt),
        label: const Text("Mekan Ekle"),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPlacesTab(), _buildCommentsTab()],
      ),
    );
  }

  // ─── MEKANLAR SEKMESİ ───
  Widget _buildPlacesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('places').orderBy('category').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text(
                  "Henüz mekan eklenmemiş.",
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sağ alttaki butona tıklayarak mekan ekleyin.",
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          );
        }

        // Kategoriye göre grupla
        final Map<String, List<QueryDocumentSnapshot>> grouped = {};
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final category = data['category'] ?? 'Diğer';
          grouped.putIfAbsent(category, () => []).add(doc);
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Üst özet kartı
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pin_drop, color: Colors.white, size: 32),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${docs.length} Mekan",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${grouped.length} kategori",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.add_location_alt,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Yeni haritaya mekan ekleme paneli",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showPlaceDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Mekan Ekle"),
                  ),
                ],
              ),
            ),
            // Kategoriler ve mekanlar
            ...grouped.entries.map((entry) {
              final category = entry.key;
              final places = entry.value;
              final color = _categoryColor(category);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "$category (${places.length})",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...places.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final avgRating =
                        (data['avgRating'] as num?)?.toDouble() ?? 0;
                    final ratingCount =
                        (data['ratingCount'] as num?)?.toInt() ?? 0;
                    final imageCount =
                        (data['imageUrls'] as List?)?.length ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _placeIcon(data['iconName'] ?? ''),
                            color: color,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          data['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['description'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Colors.amber[700],
                                ),
                                Text(
                                  " ${avgRating.toStringAsFixed(1)} ($ratingCount)",
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.image,
                                  size: 14,
                                  color: Colors.grey[400],
                                ),
                                Text(
                                  " $imageCount görsel",
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey[400],
                                ),
                                Flexible(
                                  child: Text(
                                    " ${(data['lat'] as num?)?.toStringAsFixed(4)}, ${(data['lng'] as num?)?.toStringAsFixed(4)}",
                                    style: const TextStyle(fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showPlaceDialog(doc);
                            } else if (val == 'delete') {
                              _deletePlace(doc.id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 8),
                                  Text("Düzenle"),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Sil",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
            const SizedBox(height: 80), // FAB için boşluk
          ],
        );
      },
    );
  }

  // ─── YORUMLAR SEKMESİ (Moderasyon) ───
  Widget _buildCommentsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('places').snapshots(),
      builder: (context, placesSnapshot) {
        if (placesSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final places = placesSnapshot.data?.docs ?? [];
        if (places.isEmpty) {
          return Center(
            child: Text(
              "Henüz mekan eklenmemiş.",
              style: TextStyle(color: AppColors.textTertiary),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFFF9800)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.rate_review, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Yorum Moderasyonu",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Uygunsuz yorumları silebilirsiniz",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ...places.map((placeDoc) {
              final placeData = placeDoc.data() as Map<String, dynamic>;
              return _buildPlaceCommentsSection(placeDoc.id, placeData);
            }),
          ],
        );
      },
    );
  }

  Widget _buildPlaceCommentsSection(
    String placeId,
    Map<String, dynamic> placeData,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('places')
          .doc(placeId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }

        final comments = snapshot.data?.docs ?? [];
        if (comments.isEmpty) return const SizedBox();

        final color = _categoryColor(placeData['category'] ?? '');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    _placeIcon(placeData['iconName'] ?? ''),
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${placeData['name']} (${comments.length} yorum)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...comments.map((commentDoc) {
              final c = commentDoc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.surfaceSecondary,
                    child: Text(
                      (c['userName'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    c['text'] ?? '',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    "${c['userName'] ?? 'Anonim'} • ${c['userEmail'] ?? ''}",
                    style: const TextStyle(fontSize: 10),
                  ),
                  trailing: IconButton(
                    tooltip: "Yorumu sil",
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Yorumu Sil"),
                          content: const Text(
                            "Bu yorumu kalıcı olarak silmek istiyor musunuz?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("İptal"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                "Sil",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _firestore
                            .collection('places')
                            .doc(placeId)
                            .collection('comments')
                            .doc(commentDoc.id)
                            .delete();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Yorum silindi."),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            }),
            const Divider(height: 20),
          ],
        );
      },
    );
  }
}
