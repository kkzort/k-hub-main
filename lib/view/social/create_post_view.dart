import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';

import '../../core/style/app_colors.dart';
import '../../service/storage_service.dart';
import '../../service/post_service.dart';
import 'video_trimmer_view.dart';

class CreatePostView extends StatefulWidget {
  const CreatePostView({super.key});

  @override
  State<CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<CreatePostView> {
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final PostService _postService = PostService();
  final TextEditingController _captionController = TextEditingController();
  final PageController _pageController = PageController();
  final currentUser = FirebaseAuth.instance.currentUser;

  final List<File> _selectedFiles = [];
  final List<bool> _isVideoList = [];
  final Map<int, VideoPlayerController> _videoControllers = {};
  bool _isUploading = false;
  bool _applyBWFilter = false;
  int _currentPage = 0;

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 100);
    if (picked.isNotEmpty) {
      setState(() {
        for (final xfile in picked) {
          _selectedFiles.add(File(xfile.path));
          _isVideoList.add(false);
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
      );
      if (picked == null) return;

      File file = File(picked.path);
      final fileSize = await file.length();
      debugPrint('[CreatePost] Video picked: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Video trimmer aç — kullanıcı istediği bölümü seçsin
      if (!mounted) return;
      final trimmedFile = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (_) => VideoTrimmerView(videoFile: file),
        ),
      );
      if (trimmedFile != null) file = trimmedFile;

      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      controller.setLooping(true);
      controller.play();

      setState(() {
        final idx = _selectedFiles.length;
        _selectedFiles.add(file);
        _isVideoList.add(true);
        _videoControllers[idx] = controller;
      });
    } catch (e) {
      debugPrint('[CreatePost] Video pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video seçilemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cropCurrentImage({CropAspectRatio? aspectRatio, String? title}) async {
    if (_selectedFiles.isEmpty || _isVideoList[_currentPage]) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: _selectedFiles[_currentPage].path,
      aspectRatio: aspectRatio,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title ?? 'Kırp',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: aspectRatio != null,
        ),
        IOSUiSettings(
          title: title ?? 'Kırp',
          aspectRatioLockEnabled: aspectRatio != null,
          resetAspectRatioEnabled: aspectRatio == null,
        ),
      ],
    );
    if (cropped != null) {
      setState(() => _selectedFiles[_currentPage] = File(cropped.path));
    }
  }

  void _showCropRatioSheet() {
    if (_selectedFiles.isEmpty || _isVideoList[_currentPage]) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text('Kırpma Oranı Seç', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textHeader)),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.crop_16_9, color: AppColors.primary),
                title: Text('16:9 (Yatay)', style: TextStyle(color: AppColors.textHeader)),
                subtitle: Text('Geniş ekran formatı', style: TextStyle(color: AppColors.textBody, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _cropCurrentImage(aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9), title: '16:9 Kırp');
                },
              ),
              ListTile(
                leading: Icon(Icons.crop_3_2, color: AppColors.primary),
                title: Text('4:3 (Klasik)', style: TextStyle(color: AppColors.textHeader)),
                subtitle: Text('Standart fotoğraf formatı', style: TextStyle(color: AppColors.textBody, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _cropCurrentImage(aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 3), title: '4:3 Kırp');
                },
              ),
              ListTile(
                leading: Icon(Icons.crop_square, color: AppColors.primary),
                title: Text('1:1 (Kare)', style: TextStyle(color: AppColors.textHeader)),
                subtitle: Text('Instagram formatı', style: TextStyle(color: AppColors.textBody, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _cropCurrentImage(aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), title: '1:1 Kırp');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeCurrentMedia() {
    if (_selectedFiles.isEmpty) return;
    _videoControllers[_currentPage]?.dispose();
    _videoControllers.remove(_currentPage);
    setState(() {
      _selectedFiles.removeAt(_currentPage);
      _isVideoList.removeAt(_currentPage);
      // Re-index video controllers
      final newMap = <int, VideoPlayerController>{};
      _videoControllers.forEach((key, value) {
        if (key > _currentPage) {
          newMap[key - 1] = value;
        } else {
          newMap[key] = value;
        }
      });
      _videoControllers.clear();
      _videoControllers.addAll(newMap);
      if (_currentPage >= _selectedFiles.length && _currentPage > 0) {
        _currentPage--;
      }
    });
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
        0, 0, 0, 1, 0,
      ]);
    canvas.drawImage(image, Offset.zero, paint);
    final picture = recorder.endRecording();
    final filteredImage = await picture.toImage(image.width, image.height);
    final byteData = await filteredImage.toByteData(format: ui.ImageByteFormat.png);

    final tempFile = File('${imageFile.parent.path}/bw_${DateTime.now().millisecondsSinceEpoch}.png');
    await tempFile.writeAsBytes(byteData!.buffer.asUint8List());
    return tempFile;
  }

  Future<void> _publishPost() async {
    if (_selectedFiles.isEmpty || currentUser == null) return;
    setState(() => _isUploading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final postId = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload all media
      final List<String> mediaUrls = [];
      final List<bool> mediaIsVideo = [];

      for (int i = 0; i < _selectedFiles.length; i++) {
        File uploadFile = _selectedFiles[i];
        final isVid = _isVideoList[i];

        if (_applyBWFilter && !isVid) {
          uploadFile = await _applyGrayscale(uploadFile);
        }

        // Video sıkıştır
        if (isVid) {
          try {
            uploadFile = await _storageService.compressVideo(uploadFile);
          } catch (e) {
            debugPrint('[CreatePost] Video compress failed, using original: $e');
          }
        }

        final uploadSize = (await uploadFile.length()) / 1024 / 1024;
        debugPrint('[CreatePost] Uploading ${isVid ? "video" : "image"} #$i, size: ${uploadSize.toStringAsFixed(2)} MB');
        debugPrint('[CreatePost] File path: ${uploadFile.path}');
        debugPrint('[CreatePost] File exists: ${await uploadFile.exists()}');
        final url = await _storageService.uploadPostMedia(
          uploadFile,
          '${postId}_$i',
          isVideo: isVid,
        );
        if (url == null) throw 'Medya yüklenemedi (${i + 1}. dosya, ${uploadSize.toStringAsFixed(1)} MB)';
        debugPrint('[CreatePost] Upload success: $url');
        mediaUrls.add(url);
        mediaIsVideo.add(isVid);
      }

      await _postService.createPost({
        'authorId': currentUser!.uid,
        'authorName': userData['name'] ?? 'Kullanıcı',
        'authorPhoto': userData['photoUrl'],
        'imageUrl': mediaUrls.first, // backward compat
        'mediaUrls': mediaUrls,
        'mediaIsVideo': mediaIsVideo,
        'isVideo': mediaIsVideo.first,
        'caption': _captionController.text.trim(),
        'likeCount': 0,
        'commentCount': 0,
        'likedBy': [],
        'savedBy': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _pageController.dispose();
    for (final c in _videoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yeni Gönderi'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textHeader,
        elevation: 0,
        actions: [
          if (_selectedFiles.isNotEmpty)
            TextButton(
              onPressed: _isUploading ? null : _publishPost,
              child: _isUploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Paylaş', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: _selectedFiles.isEmpty ? _buildMediaPicker() : _buildEditor(),
    );
  }

  Widget _buildMediaPicker() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 80, color: AppColors.border),
          const SizedBox(height: 32),
          _buildPickerBtn(Icons.photo_library_rounded, 'Fotoğraf Seç (çoklu)', _pickImages),
          const SizedBox(height: 12),
          _buildPickerBtn(Icons.videocam_rounded, 'Video Seç', _pickVideo),
          const SizedBox(height: 12),
          _buildPickerBtn(Icons.camera_alt_rounded, 'Kameradan Çek', () async {
            final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 100);
            if (picked != null) {
              setState(() {
                _selectedFiles.add(File(picked.path));
                _isVideoList.add(false);
              });
            }
          }),
        ],
      ),
    );
  }

  Widget _buildPickerBtn(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      width: 260,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Media preview with PageView
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.width,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _selectedFiles.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, index) {
                    if (_isVideoList[index]) {
                      final vc = _videoControllers[index];
                      if (vc != null && vc.value.isInitialized) {
                        return Container(
                          color: Colors.black,
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: vc.value.aspectRatio,
                              child: VideoPlayer(vc),
                            ),
                          ),
                        );
                      }
                      return Container(color: Colors.black, child: const Center(child: CircularProgressIndicator()));
                    }
                    return ColorFiltered(
                      colorFilter: _applyBWFilter
                          ? const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ])
                          : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                      child: Image.file(_selectedFiles[index], fit: BoxFit.contain),
                    );
                  },
                ),
              ),

              // Page indicators
              if (_selectedFiles.length > 1)
                Positioned(
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_selectedFiles.length, (i) {
                      return Container(
                        width: 7, height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _currentPage ? AppColors.primary : Colors.grey.shade400,
                        ),
                      );
                    }),
                  ),
                ),

              // Counter badge
              if (_selectedFiles.length > 1)
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: Text('${_currentPage + 1}/${_selectedFiles.length}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),

          // Tools row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolBtn(Icons.add_photo_alternate, 'Ekle', () async {
                  final picked = await _picker.pickMultiImage(imageQuality: 100);
                  if (picked.isNotEmpty) {
                    setState(() {
                      for (final xfile in picked) {
                        _selectedFiles.add(File(xfile.path));
                        _isVideoList.add(false);
                      }
                    });
                  }
                }),
                if (!_isVideoList[_currentPage])
                  _buildToolBtn(Icons.crop_rounded, 'Kırp', _showCropRatioSheet),
                if (!_isVideoList[_currentPage])
                  _buildToolBtn(
                    Icons.filter_b_and_w,
                    _applyBWFilter ? 'Renkli' : 'S/B',
                    () => setState(() => _applyBWFilter = !_applyBWFilter),
                    active: _applyBWFilter,
                  ),
                _buildToolBtn(Icons.delete_outline, 'Kaldır', _removeCurrentMedia),
              ],
            ),
          ),

          // Caption
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _captionController,
              decoration: InputDecoration(
                hintText: 'Açıklama yaz...',
                hintStyle: TextStyle(color: AppColors.textBody),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                filled: true,
                fillColor: AppColors.surface,
              ),
              maxLines: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolBtn(IconData icon, String label, VoidCallback onTap, {bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: active ? AppColors.primary : AppColors.textBody, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: active ? AppColors.primary : AppColors.textBody)),
        ],
      ),
    );
  }
}
