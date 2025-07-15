import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/attendance_screen.dart';
import 'services/notification_service.dart';
import 'screens/loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService().initNotifications(); // ✅ Mutlaka burada olmalı
    print("Bildirim servisi başlatıldı");
  } catch (e) {
    print("Bildirim hatası: $e");
  }


  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eyyübiye Personel Takip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routes: {
        '/login': (context) => LoginScreen(),
        '/splash': (context) => SplashScreen(),
        '/attendance': (context) => AttendanceScreen(),
        '/loading': (context) => LoadingScreen(),
      },
      initialRoute: '/splash',
    );
  }
}
