// lib/ios_background_test_service.dart

import 'dart:io';
import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- BU FONKSİYON, ARKA PLANDA ÇALIŞACAK OLAN ASIL KODDUR ---
// Sınıf dışında, en üst seviyede olmalıdır.
// lib/ios_background_test_service.dart

@pragma('vm:entry-point')
void onBackgroundFetch(String taskId) async {
   debugPrint("⚡️ [BackgroundFetch] iOS Release Mod Görevi Başladı: $taskId");

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');

  if (token == null) {
    print("[BackgroundFetch] Kullanıcı giriş yapmamış. Görev sonlandırılıyor.");
    BackgroundFetch.finish(taskId);
    return;
  }
  
  // --- YENİ EKLENEN İZİN KONTROLÜ ---
  // Konumu almadan önce, iznimizin durumunu kontrol edelim.
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission != LocationPermission.always) {
    print("❌ [BackgroundFetch] 'Her Zaman' konum izni verilmemiş (Mevcut İzin: $permission). Görev konum alamadan sonlandırılıyor.");
    BackgroundFetch.finish(taskId);
    return;
  }
  // --- KONTROL SONU ---

  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 20),
    );
    
    print("📍 [BackgroundFetch] ARKA PLAN KONUMU ALINDI:");
    print("   - Enlem: ${position.latitude}");
    print("   - Boylam: ${position.longitude}");
    print("   - Zaman: ${position.timestamp}");

  } catch (e) {
    print("❌ [BackgroundFetch] Arka planda konum alınırken hata oluştu: $e");
  }

  BackgroundFetch.finish(taskId);
}

// --- BU SINIF, SERVİSİ BAŞLATMAK İÇİN KULLANILACAK ---
class IosBackgroundTestService {
  
  /// Arka plan görevini yapılandırır ve başlatır.
  static Future<void> initialize() async {
    // Sadece iOS platformunda çalışacak
    if (!Platform.isIOS) {
      return;
    }

    print("[IosBackgroundTestService] iOS arka plan servisi başlatılıyor...");

    try {
      await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 1, // iOS için en düşük değer 15 dakikadır.
          stopOnTerminate: false,   // Uygulama kill edilse bile görevler devam etsin.
          enableHeadless: true,     // onBackgroundFetch fonksiyonunu etkinleştir.
        ),
        onBackgroundFetch, // Arka planda çalışacak olan fonksiyon.
        (String taskId) async {  // Görev zaman aşımına uğradığında çalışır.
          print("[BackgroundFetch] GÖREV ZAMAN AŞIMI: $taskId");
          BackgroundFetch.finish(taskId);
        },
      );
      print("[IosBackgroundTestService] Arka plan servisi başarıyla yapılandırıldı.");
    } catch (e) {
      print("[IosBackgroundTestService] Arka plan servisi yapılandırma hatası: $e");
    }
  }
}