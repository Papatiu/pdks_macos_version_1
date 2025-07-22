import 'dart:io';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/attendance_screen.dart';
import 'services/notification_service.dart';
import 'screens/loading_screen.dart';

// Yeni ve tek kullanılacak olan FBG servisini import ediyoruz
import 'package:mobilperosnel/services/fbg_test_service.dart';

void main() async {
  // Flutter binding'lerinin hazır olduğundan emin ol
  WidgetsFlutterBinding.ensureInitialized();
  
  // Bildirim servisini başlat
  try {
    await NotificationService().initNotifications();
    print("Bildirim servisi başarıyla başlatıldı.");
  } catch (e) {
    print("Bildirim servisi başlatılırken hata: $e");
  }

  // Sadece FBG servisini başlat. 
  // Paket kendi içinde platformu kontrol edeceği için Platform.isIOS kontrolüne gerek yok.
  await FbgTestService.initialize();

  // Uygulamayı çalıştır
  runApp(const MyApp());
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
      initialRoute: '/splash', // Başlangıç ekranı
      routes: {
        '/splash': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/attendance': (context) => AttendanceScreen(),
        '/loading': (context) => LoadingScreen(),
      },
    );
  }
}