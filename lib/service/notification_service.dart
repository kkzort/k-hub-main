import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Arka plan mesaj handler (top-level olmalı)
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka planda gelen mesajı işle
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Servisi başlat
  Future<void> initialize() async {
    // İzin iste
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    // Local notification kanalı
    const androidChannel = AndroidNotificationChannel(
      'khub_channel',
      'K-Hub Bildirimleri',
      description: 'Kırıkkale Üniversitesi bildirimleri',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Local notification init
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(initSettings);

    // Foreground mesajları dinle — her zaman göster
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title ?? 'K-Hub',
          notification.body ?? '',
          NotificationDetails(
            android: AndroidNotificationDetails(
              androidChannel.id,
              androidChannel.name,
              channelDescription: androidChannel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      }
    });

    // FCM token'ı Firestore'a kaydet
    await _saveToken();

    // Token yenilenince güncelle
    _messaging.onTokenRefresh.listen((token) => _saveToken());

    // Konulara abone ol
    await _messaging.subscribeToTopic('all_users');
    await _messaging.subscribeToTopic('announcements');
    await _messaging.subscribeToTopic('events');
  }

  /// FCM token'ı Firestore'a kaydet
  Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      final user = FirebaseAuth.instance.currentUser;
      if (token != null && user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
      }
    } catch (_) {}
  }

  /// Konuya abone ol
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Abonelikten çık
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
