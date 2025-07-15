import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotiService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Bildirim sistemini başlatır.
  Future<void> initNotification() async {
    if (_isInitialized) return; // Çift initialize'ı önlemek için

    // Android için başlangıç ayarları
    const AndroidInitializationSettings initSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS için başlangıç ayarları
    const DarwinInitializationSettings initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Genel initialize ayarları
    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    await _notificationsPlugin.initialize(initSettings);
    _isInitialized = true;
    print("✅ NotiService initialized");
  }

  /// Bildirim detaylarını tanımlar.
  NotificationDetails notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_channel_id',
        'Daily Notifications',
        channelDescription: 'Daily Notification Channel',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  /// Bildirim gönderir.
  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
  }) async {
    return _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails(),
    );
  }
}
