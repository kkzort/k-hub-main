import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_compress/video_compress.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload helper — putFile ile yükler, başarısız olursa putData dener.
  /// Büyük dosyalarda (>10MB) putData atlanır (OOM riski).
  Future<String?> _uploadWithRetry(
    Reference ref,
    File file, {
    SettableMetadata? metadata,
    int maxRetries = 3,
    bool rethrowUnauthorized = false,
  }) async {
    final exists = await file.exists();
    final size = exists ? await file.length() : 0;
    debugPrint(
      '[StorageService] Upload: path=${ref.fullPath}, size=${(size / 1024 / 1024).toStringAsFixed(2)} MB',
    );

    if (!exists || size == 0) {
      debugPrint('[StorageService] File does not exist or is empty!');
      return null;
    }

    FirebaseException? lastFirebaseError;

    // 1. putFile ile dene
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[StorageService] putFile attempt #$attempt...');
        await ref.putFile(file, metadata);
        final url = await ref.getDownloadURL();
        debugPrint('[StorageService] Upload success: $url');
        return url;
      } on FirebaseException catch (e) {
        debugPrint(
          '[StorageService] putFile #$attempt failed: ${e.code} - ${e.message}',
        );
        lastFirebaseError = e;
        if (e.code == 'unauthorized' || e.code == 'unauthenticated') break;
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      } catch (e) {
        debugPrint('[StorageService] putFile #$attempt error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }

    // unauthorized ise rethrow et
    if (lastFirebaseError != null &&
        (lastFirebaseError.code == 'unauthorized' ||
            lastFirebaseError.code == 'unauthenticated') &&
        rethrowUnauthorized) {
      throw lastFirebaseError;
    }

    // 2. putData fallback — sadece küçük dosyalar için (>10MB = OOM riski)
    if (size > 10 * 1024 * 1024) {
      debugPrint(
        '[StorageService] File too large for putData fallback (${(size / 1024 / 1024).toStringAsFixed(1)} MB), skipping',
      );
      return null;
    }

    try {
      debugPrint('[StorageService] Trying putData fallback...');
      final bytes = await file.readAsBytes();
      await ref.putData(Uint8List.fromList(bytes), metadata);
      final url = await ref.getDownloadURL();
      debugPrint('[StorageService] putData success: $url');
      return url;
    } on FirebaseException catch (e) {
      debugPrint('[StorageService] putData failed: ${e.code} - ${e.message}');
      if ((e.code == 'unauthorized' || e.code == 'unauthenticated') &&
          rethrowUnauthorized) {
        rethrow;
      }
      return null;
    } catch (e) {
      debugPrint('[StorageService] putData error: $e');
      return null;
    }
  }

  /// Video sıkıştır — Android'de büyük video dosyaları upload sorunu yaratıyor
  Future<File> compressVideo(File videoFile) async {
    try {
      final fileSize = await videoFile.length();
      debugPrint(
        '[StorageService] Video original size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      // 5MB'den küçükse sıkıştırmaya gerek yok
      if (fileSize < 5 * 1024 * 1024) return videoFile;

      final info = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (info != null && info.file != null) {
        final newSize = await info.file!.length();
        debugPrint(
          '[StorageService] Video compressed: ${(newSize / 1024 / 1024).toStringAsFixed(2)} MB',
        );
        return info.file!;
      }
    } catch (e) {
      debugPrint('[StorageService] Video compress failed: $e');
    }
    return videoFile;
  }

  /// Profil fotoğrafı yükle
  Future<String?> uploadProfilePhoto(File file, String uid) async {
    try {
      final ref = _storage.ref().child('notes/profile_${uid}_avatar.jpg');
      return await _uploadWithRetry(ref, file);
    } catch (e) {
      debugPrint('Profile photo upload error: $e');
      return null;
    }
  }

  /// Not dosyası yükle (görsel veya PDF)
  Future<String?> uploadNoteFile(File file, String fileName) async {
    try {
      final ext = fileName.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('notes/${timestamp}_$fileName');
      final metadata = SettableMetadata(
        contentType: ext == 'pdf' ? 'application/pdf' : 'image/$ext',
      );
      return await _uploadWithRetry(ref, file, metadata: metadata);
    } catch (e) {
      debugPrint('Note file upload error: $e');
      return null;
    }
  }

  /// Mekan görseli yükle
  Future<String?> uploadPlaceImage(File file, String fileName) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('notes/place_${timestamp}_$fileName');
      return await _uploadWithRetry(ref, file);
    } catch (e) {
      debugPrint('Place image upload error: $e');
      return null;
    }
  }

  /// Duyuru görseli yükle
  Future<String?> uploadAnnouncementImage(File file, String fileName) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child(
        'notes/announcement_${timestamp}_$fileName',
      );
      return await _uploadWithRetry(ref, file);
    } catch (e) {
      debugPrint('Announcement upload error: $e');
      rethrow;
    }
  }

  /// Etkinlik görseli yükle
  Future<String?> uploadEventImage(File file, String fileName) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('notes/event_${timestamp}_$fileName');
      return await _uploadWithRetry(ref, file);
    } catch (e) {
      debugPrint('Event upload error: $e');
      rethrow;
    }
  }

  /// Post medya yükle (görsel veya video)
  /// Not: Firebase Storage rules 'posts/' klasörüne izin vermediğinden
  /// doğrudan 'notes/' altına yükleniyor.
  Future<String?> uploadPostMedia(
    File file,
    String postId, {
    bool isVideo = false,
  }) async {
    final ext = isVideo ? 'mp4' : 'jpg';
    final contentType = isVideo ? 'video/mp4' : 'image/jpeg';
    final metadata = SettableMetadata(contentType: contentType);
    try {
      final ref = _storage.ref().child('notes/post_$postId.$ext');
      return await _uploadWithRetry(ref, file, metadata: metadata);
    } catch (e) {
      debugPrint('Post upload error: $e');
      return null;
    }
  }

  /// Story medya yükle (görsel veya video)
  Future<String?> uploadStoryMedia(
    File file,
    String storyId, {
    bool isVideo = false,
  }) async {
    final ext = isVideo ? 'mp4' : 'jpg';
    final contentType = isVideo ? 'video/mp4' : 'image/jpeg';
    final metadata = SettableMetadata(contentType: contentType);
    try {
      final ref = _storage.ref().child('notes/story_$storyId.$ext');
      return await _uploadWithRetry(ref, file, metadata: metadata);
    } catch (e) {
      debugPrint('Story upload error: $e');
      return null;
    }
  }

  /// Sohbet medyası yükle (DM veya genel sohbet)
  /// [storagePath] örnek: 'chat_media/dm/{convId}' veya 'chat_media/campus'
  Future<String?> uploadChatMedia(
    File file,
    String storagePath, {
    bool isVideo = false,
  }) async {
    try {
      final fileName = file.path.split('/').last;
      final ext = fileName.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      String contentTypeStr;
      if (isVideo) {
        contentTypeStr = 'video/mp4';
      } else if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
        contentTypeStr = 'image/$ext';
      } else if (ext == 'pdf') {
        contentTypeStr = 'application/pdf';
      } else {
        contentTypeStr = 'application/octet-stream';
      }

      final ref = _storage.ref().child('notes/chat_${timestamp}_$fileName');
      final metadata = SettableMetadata(contentType: contentTypeStr);
      return await _uploadWithRetry(ref, file, metadata: metadata);
    } catch (e) {
      debugPrint('Chat media upload error: $e');
      return null;
    }
  }

  /// Öğrenci belgesi yükle
  Future<String?> uploadVerificationDocument(File file, String uid) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final ref = _storage.ref().child(
        'notes/verification_${uid}_document.$ext',
      );
      final metadata = SettableMetadata(
        contentType: ext == 'pdf' ? 'application/pdf' : 'image/$ext',
      );
      final result = await _uploadWithRetry(ref, file, metadata: metadata);
      if (result == null) throw Exception('Belge yüklenemedi');
      return result;
    } catch (e) {
      debugPrint("Storage Error: $e");
      rethrow;
    }
  }
}
