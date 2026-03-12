import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web platform is not supported.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB3Z-PkVTWpE-mQGe76pwZ3G--5sDyUKC4',
    appId: '1:504074477837:android:32c2f0781e17db69bc5044',
    messagingSenderId: '504074477837',
    projectId: 'k-hub-7a8a2',
    storageBucket: 'k-hub-7a8a2.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD6ELXIKdeliop3qDy5k-hZUgS4ByY_KXM',
    appId: '1:504074477837:ios:4966e759449c6116bc5044',
    messagingSenderId: '504074477837',
    projectId: 'k-hub-7a8a2',
    storageBucket: 'k-hub-7a8a2.firebasestorage.app',
    iosBundleId: 'com.khub.app',
  );
}
