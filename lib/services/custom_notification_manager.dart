import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class CustomNotificationManager {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // İnitialization kodu
  }

  static Future<void> showNotificationCustom({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: androidPlatformChannelSpecifics,
      ),
    );
  }
}