import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui' as ui;

import '../../service/storage_service.dart';
import '../../service/story_service.dart';
import 'video_trimmer_view.dart';
// video_compress imported via StorageService

class CreateStoryView extends StatefulWidget {
  const CreateStoryView({super.key});

  @override
  State<CreateStoryView> createState() => _CreateStoryViewState();
}

class _CreateStoryViewState extends State<CreateStoryView> {
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final StoryService _storyService = StoryService();
  final TextEditingController _textController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  File? _selectedFile;
  bool _isVideo = false;
  bool _isUploading = false;
  bool _applyBWFilter = false;
  VideoPlayerController? _videoController;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 100);
    if (picked != null) {
      setState(() {
        _selectedFile = File(picked.path);
        _isVideo = false;
      });
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picked = await _picker.pickVideo(
      source: source,
    );
    if (picked != null) {
      File file = File(picked.path);

      // Video trimmer aç — kullanıcı istediği bölümü seçsin
      if (!mounted) return;
      final trimmedFile = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (_) => VideoTrimmerView(videoFile: file),
        ),
      );
      if (trimmedFile != null) file = trimmedFile;

      _videoController?.dispose();
      final controller = VideoPlayerController.file(file);
      await controller.initialize();

      setState(() {
        _selectedFile = file;
        _isVideo = true;
        _videoController = controller;
        _videoController!.setLooping(true);
        _videoController!.play();
      });
    }
  }

  Future<void> _cropImage() async {
    if (_selectedFile == null || _isVideo) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: _selectedFile!.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Kırp',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
        ),
        IOSUiSettings(title: 'Kırp'),
      ],
    );
    if (cropped != null) {
      setState(() => _selectedFile = File(cropped.path));
    }
  }

  Future<void> _publishStory() async {
    if (_selectedFile == null || currentUser == null) return;

    setState(() => _isUploading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      final userData = userDoc.data() ?? {};

      final storyId = DateTime.now().millisecondsSinceEpoch.toString();

      File uploadFile = _selectedFile!;

      // Apply B&W filter for images
      if (_applyBWFilter && !_isVideo) {
        uploadFile = await _applyGrayscale(_selectedFile!);
      }

      // Video sıkıştır
      if (_isVideo) {
        try {
          uploadFile = await _storageService.compressVideo(uploadFile);
        } catch (e) {
          debugPrint('[CreateStory] Video compress failed, using original: $e');
        }
      }

      final uploadSize = (await uploadFile.length()) / 1024 / 1024;
      debugPrint('[CreateStory] Uploading ${_isVideo ? "video" : "image"}, size: ${uploadSize.toStringAsFixed(2)} MB');
      debugPrint('[CreateStory] File path: ${uploadFile.path}');
      debugPrint('[CreateStory] File exists: ${await uploadFile.exists()}');
      final mediaUrl = await _storageService.uploadStoryMedia(
        uploadFile,
        storyId,
        isVideo: _isVideo,
      );

      if (mediaUrl == null) throw 'Medya yüklenemedi (${uploadSize.toStringAsFixed(1)} MB)';

      await _storyService.createStory({
        'authorId': currentUser!.uid,
        'authorName': userData['name'] ?? 'Kullanıcı',
        'authorPhoto': userData['photoUrl'],
        'imageUrl': mediaUrl,
        'isVideo': _isVideo,
        'text': _textController.text.trim().isEmpty
            ? null
            : _textController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24)),
        ),
        'viewedBy': [],
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<File> _applyGrayscale(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()
      ..colorFilter = const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ]);

    canvas.drawImage(image, Offset.zero, paint);
    final picture = recorder.endRecording();
    final filteredImage = await picture.toImage(image.width, image.height);
    final byteData = await filteredImage.toByteData(format: ui.ImageByteFormat.png);

    final tempFile = File('${imageFile.parent.path}/bw_${DateTime.now().millisecondsSinceEpoch}.png');
    await tempFile.writeAsBytes(byteData!.buffer.asUint8List());
    return tempFile;
  }

  @override
  void dispose() {
    _textController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Hikaye Oluştur'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedFile != null)
            TextButton(
              onPressed: _isUploading ? null : _publishStory,
              child: _isUploading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Paylaş', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: _selectedFile == null ? _buildMediaPicker() : _buildPreview(),
    );
  }

  Widget _buildMediaPicker() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_rounded, size: 80, color: Colors.white24),
          const SizedBox(height: 32),
          _buildPickerButton(
            icon: Icons.photo_library_rounded,
            label: 'Galeriden Fotoğraf',
            onTap: () => _pickImage(ImageSource.gallery),
          ),
          const SizedBox(height: 12),
          _buildPickerButton(
            icon: Icons.videocam_rounded,
            label: 'Galeriden Video',
            onTap: () => _pickVideo(ImageSource.gallery),
          ),
          const SizedBox(height: 12),
          _buildPickerButton(
            icon: Icons.camera_alt_rounded,
            label: 'Kamera',
            onTap: () => _pickImage(ImageSource.camera),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: 260,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white12,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.black,
            child: Center(
              child: _isVideo
                  ? (_videoController != null && _videoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : const CircularProgressIndicator())
                  : ColorFiltered(
                      colorFilter: _applyBWFilter
                          ? const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ])
                          : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                      child: Image.file(
                        _selectedFile!,
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
          ),
        ),

        // Bottom tools
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Filter & crop buttons
              if (!_isVideo)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildToolButton(
                      icon: Icons.crop_rounded,
                      label: 'Kırp',
                      onTap: _cropImage,
                    ),
                    const SizedBox(width: 24),
                    _buildToolButton(
                      icon: Icons.filter_b_and_w_rounded,
                      label: _applyBWFilter ? 'Renkli' : 'S/B',
                      active: _applyBWFilter,
                      onTap: () => setState(() => _applyBWFilter = !_applyBWFilter),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Metin ekle (isteğe bağlı)...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 1,
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolButton({required IconData icon, required String label, bool active = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white12,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: active ? Colors.black : Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: active ? Colors.white : Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}
