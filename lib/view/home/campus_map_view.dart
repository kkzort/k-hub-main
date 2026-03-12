import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/style/app_colors.dart';

class CampusMapView extends StatefulWidget {
  final Color kPrimaryColor;
  const CampusMapView({super.key, required this.kPrimaryColor});

  @override
  State<CampusMapView> createState() => _CampusMapViewState();
}

class _CampusMapViewState extends State<CampusMapView> {
  final _fs = FirebaseFirestore.instance;
  final _mapController = MapController();
  String _selectedCategory = 'Hepsi';

  static final _bounds = LatLngBounds(
    const LatLng(39.8100, 33.4100),
    const LatLng(39.9050, 33.5850),
  );
  static const _center = LatLng(39.8450, 33.5000);

  final _categories = const ['Hepsi', 'Kampüs', 'Kafe', 'Restoran', 'Market', 'Sağlık', 'Eğlence'];

  Color _catColor(String c) {
    switch (c) {
      case 'Kampüs':
        return const Color(0xFF4A90D9);
      case 'Kafe':
        return const Color(0xFFD4A574);
      case 'Restoran':
        return const Color(0xFFFF6B6B);
      case 'Market':
        return const Color(0xFF51CF66);
      case 'Sağlık':
        return const Color(0xFFFF8787);
      case 'Eğlence':
        return const Color(0xFFCC5DE8);
      default:
        return Colors.grey;
    }
  }

  String _catEmoji(String c) {
    switch (c) {
      case 'Kampüs':
        return '🏫';
      case 'Kafe':
        return '☕';
      case 'Restoran':
        return '🍽️';
      case 'Market':
        return '🛒';
      case 'Sağlık':
        return '🏥';
      case 'Eğlence':
        return '🎮';
      default:
        return '📍';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: _fs.collection('places').snapshots(),
        builder: (context, snap) {
          final all = snap.data?.docs ?? [];
          final geocoded = all.where((d) {
            final m = d.data() as Map<String, dynamic>;
            return m['lat'] is num && m['lng'] is num;
          }).toList();
          final filtered = _selectedCategory == 'Hepsi'
              ? geocoded
              : geocoded.where((d) => (d.data() as Map<String, dynamic>)['category'] == _selectedCategory).toList();

          final markers = filtered.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final cat = (d['category'] ?? '').toString();
            final lat = (d['lat'] as num).toDouble();
            final lng = (d['lng'] as num).toDouble();
            final color = _catColor(cat);
            return Marker(
              point: LatLng(lat, lng),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () {
                  _mapController.move(LatLng(lat, lng), 16.0);
                  _showDetail(doc.id, d);
                },
                child: Container(
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  alignment: Alignment.center,
                  child: Text(_catEmoji(cat), style: const TextStyle(fontSize: 17)),
                ),
              ),
            );
          }).toList();

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 12.6,
                  minZoom: 12.2,
                  maxZoom: 18.5,
                  cameraConstraint: CameraConstraint.contain(bounds: _bounds),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.k_hub',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
                              child: Text('Kampüs Haritası • ${filtered.length} mekan', style: TextStyle(color: AppColors.textHeader, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _categories.map((c) {
                            final sel = _selectedCategory == c;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedCategory = c),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: sel ? widget.kPrimaryColor : AppColors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(c, style: TextStyle(fontSize: 12, color: sel ? Colors.white : AppColors.textHeader)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDetail(String placeId, Map<String, dynamic> place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaceDetail(placeId: placeId, data: place, kPrimaryColor: widget.kPrimaryColor),
    );
  }
}

class _PlaceDetail extends StatefulWidget {
  final String placeId;
  final Map<String, dynamic> data;
  final Color kPrimaryColor;
  const _PlaceDetail({required this.placeId, required this.data, required this.kPrimaryColor});

  @override
  State<_PlaceDetail> createState() => _PlaceDetailState();
}

class _PlaceDetailState extends State<_PlaceDetail> {
  final _fs = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;
  final _comment = TextEditingController();
  int _myRating = 0;

  Future<void> _rate(int r) async {
    if (_user == null) return;
    setState(() => _myRating = r);
    await _fs.collection('places').doc(widget.placeId).collection('ratings').doc(_user.uid).set({'rating': r, 'updatedAt': FieldValue.serverTimestamp()});
    final snap = await _fs.collection('places').doc(widget.placeId).collection('ratings').get();
    double total = 0;
    for (final d in snap.docs) {
      total += (d.data()['rating'] as num).toDouble();
    }
    await _fs.collection('places').doc(widget.placeId).update({'avgRating': snap.docs.isEmpty ? 0.0 : total / snap.docs.length, 'ratingCount': snap.docs.length});
  }

  Future<void> _sendComment() async {
    if (_comment.text.trim().isEmpty || _user == null) return;
    await _fs.collection('places').doc(widget.placeId).collection('comments').add({
      'text': _comment.text.trim(),
      'userId': _user.uid,
      'userEmail': _user.email,
      'userName': _user.email?.split('@')[0] ?? 'Anonim',
      'createdAt': FieldValue.serverTimestamp(),
    });
    _comment.clear();
  }

  @override
  Widget build(BuildContext context) {
    final avg = (widget.data['avgRating'] as num?)?.toDouble() ?? 0;
    final rc = (widget.data['ratingCount'] as num?)?.toInt() ?? 0;
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Text(widget.data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 6),
            Text(widget.data['description'] ?? '', style: TextStyle(color: AppColors.textBody)),
            const SizedBox(height: 8),
            Row(children: [const Icon(Icons.star, size: 16, color: Colors.amber), Text(' ${avg.toStringAsFixed(1)} ($rc)')]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: List.generate(5, (i) {
                final n = i + 1;
                return IconButton(
                  onPressed: () => _rate(n),
                  icon: Icon(_myRating >= n ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber),
                );
              }),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _comment,
                    decoration: const InputDecoration(hintText: 'Yorum yaz...', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _sendComment, icon: const Icon(Icons.send_rounded)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
