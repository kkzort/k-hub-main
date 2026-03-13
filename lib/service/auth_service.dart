import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Ban durumunu kontrol et
  Future<bool> isUserBanned(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists || userDoc.data() == null) return false;
      final data = userDoc.data() as Map<String, dynamic>;
      return data['isBanned'] == true;
    } catch (_) {
      return false;
    }
  }

  // Ban bilgilerini getir (neden dahil)
  Future<Map<String, dynamic>?> getBanInfo(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists || userDoc.data() == null) return null;
      final data = userDoc.data() as Map<String, dynamic>;
      if (data['isBanned'] != true) return null;
      return {
        'isBanned': true,
        'banReason': data['banReason'] ?? '',
        'bannedAt': data['bannedAt'],
      };
    } catch (_) {
      return null;
    }
  }

  // Ban durumunu stream olarak takip et
  Stream<Map<String, dynamic>?> banStatusStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      final data = snapshot.data() as Map<String, dynamic>;
      if (data['isBanned'] != true) return null;
      return {'isBanned': true, 'banReason': data['banReason'] ?? ''};
    });
  }

  // Onay durumunu kontrol et
  Future<bool> checkApprovalStatus(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data['isBanned'] == true) return false;
        if (data['role'] == 'admin') return true;
        return data['isApproved'] ?? false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Onay durumunu anlik takip et (stream)
  Stream<bool> approvalStatusStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data['isBanned'] == true) return false;
        if (data['role'] == 'admin') return true;
        return data['isApproved'] ?? false;
      }
      return false;
    });
  }

  // Kullanici rolunu getir
  Future<String> getUserRole(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        return (userDoc.data() as Map<String, dynamic>)['role'] ?? 'student';
      }
      return 'student';
    } catch (_) {
      return 'student';
    }
  }

  // Giris yap
  Future<Map<String, dynamic>> signInUser({
    required String email,
    required String password,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[Auth] signIn attempt: $email');
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        debugPrint('[Auth] signIn success uid=${userCredential.user?.uid}');
      }

      final uid = userCredential.user!.uid;
      final banInfo = await getBanInfo(uid);
      if (banInfo != null) {
        await _auth.signOut();
        return {
          'status': 'banned',
          'message': 'Hesabınız yönetici tarafından askıya alınmıştır.',
          'banReason': banInfo['banReason'] ?? '',
        };
      }

      final role = await getUserRole(uid);
      return {'status': 'success', 'role': role};
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Auth] FirebaseAuthException: code=${e.code} message=${e.message}',
        );
      }
      String turkceHata;
      switch (e.code) {
        case 'user-not-found':
          turkceHata = 'Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı.';
          break;
        case 'wrong-password':
          turkceHata = 'Şifre yanlış. Lütfen tekrar deneyin.';
          break;
        case 'invalid-email':
          turkceHata = 'Geçersiz e-posta adresi.';
          break;
        case 'user-disabled':
          turkceHata = 'Bu hesap devre dışı bırakılmış.';
          break;
        case 'too-many-requests':
          turkceHata =
              'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';
          break;
        case 'invalid-credential':
          turkceHata =
              'Geçersiz kimlik bilgileri. E-posta ve şifrenizi kontrol edin.';
          break;
        default:
          turkceHata = e.message ?? 'Giriş sırasında bir hata oluştu.';
      }
      return {'status': 'error', 'message': turkceHata};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Auth] Unexpected error: $e');
      }
      return {'status': 'error', 'message': 'Beklenmeyen bir hata oluştu: $e'};
    }
  }

  // Kayit ol
  Future<String?> registerUser({
    required String email,
    required String password,
    required String name,
    required String nick,
    required dynamic storageService,
    required dynamic selectedFile,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[Auth] register attempt: $email');
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        debugPrint('[Auth] register success uid=${userCredential.user?.uid}');
      }

      final uid = userCredential.user!.uid;
      final docUrl = await storageService.uploadVerificationDocument(
        selectedFile,
        uid,
      );

      if (docUrl == null) {
        throw 'Belge yükleme aşamasında bir sorun oluştu.';
      }

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'name': name,
        'nick': nick,
        'role': 'student',
        'isApproved': false,
        'isBanned': false,
        'studentDocumentUrl': docUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return 'success';
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Auth] Register FirebaseAuthException: code=${e.code} message=${e.message}',
        );
      }
      String turkceHata;
      switch (e.code) {
        case 'email-already-in-use':
          turkceHata = 'Bu e-posta adresi zaten kullanılıyor.';
          break;
        case 'weak-password':
          turkceHata = 'Şifre çok zayıf. En az 6 karakter kullanın.';
          break;
        case 'invalid-email':
          turkceHata = 'Geçersiz e-posta adresi.';
          break;
        default:
          turkceHata = e.message ?? 'Kayıt sırasında bir hata oluştu.';
      }
      return turkceHata;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Auth] Register unexpected error: $e');
      }
      return e.toString();
    }
  }

  // Cikis yap
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
