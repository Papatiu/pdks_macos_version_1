import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  // Singleton Pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _initialized = false;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  /// Bildirimleri başlatır ve gerekli izinleri talep eder.
  Future<void> initNotifications() async {
    if (_initialized) return;

    // iOS ve macOS için bildirim iznini kontrol et ve iste
    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        await Permission.notification.request();
      }
    }

    // Android başlangıç ayarları
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS ve macOS için Darwin ayarları
    final DarwinInitializationSettings darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings, // iOS ve macOS için aynı ayarları kullanıyoruz
    );

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Bildirime tıklanınca yapılacak işlemler burada tanımlanabilir.
      },
    );

    // Eğer platform macOS ise, platforma özel izin talebi de yap
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final macOSImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      await macOSImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _initialized = true;
    print("✅ Bildirimler Başlatıldı");
  }

  /// Özel bildirim gösterir.
  Future<void> showNotificationCustom(String title, String body) async {
    if (!_initialized) {
      print("❌ initNotifications çağrılmamış!");
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'my_channel_id',
      'my_channel_name',
      channelDescription: 'my_channel_description',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformDetails,
    );
  }
}
