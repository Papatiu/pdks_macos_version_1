import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobilperosnel/utils/constants.dart';

class FbgTestService {
  
  static Future<void> initialize() async {
    // Olay Dinleyicilerini Ayarla
    bg.BackgroundGeolocation.onLocation(_onLocation);
    bg.BackgroundGeolocation.onMotionChange(_onMotionChange);
    bg.BackgroundGeolocation.onGeofence(_onGeofence); // YENİ: Geofence dinleyicisi

    // Servisi Yapılandır
    await bg.BackgroundGeolocation.ready(bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 50.0, // Hareket halindeyken 50 metrede bir konum al
        stopOnTerminate: false,
        startOnBoot: true,
        logLevel: bg.Config.LOG_LEVEL_VERBOSE,
        debug: true,
        showsBackgroundLocationIndicator: true,
        preventSuspend: true,
    ));
    debugPrint('[FBG] Servis başarıyla yapılandırıldı.');
    
    await startServiceIfLoggedIn();
  }

  /// Kullanıcı giriş yapmışsa servisi başlatır ve mevcut Geofence'leri kurar.
  static Future<void> startServiceIfLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token != null) {
      bg.State state = await bg.BackgroundGeolocation.state;
      if (!state.enabled) {
        await bg.BackgroundGeolocation.start();
        debugPrint('[FBG] Servis başlatıldı.');
      }
      // Servis başladıktan sonra mevcut kaydedilmiş konumlarla geofence'leri kur.
      await updateGeofences();
    }
  }

  /// YENİ FONKSİYON: Mevcut geofence'leri temizler ve yenilerini kurar.
 // lib/services/fbg_test_service.dart

  /// YENİ VE DAHA SAĞLAM GEOFENCE GÜNCELLEME FONKSİYONU
  static Future<void> updateGeofences({String? checkInLocation, String? checkOutLocation}) async {
    await bg.BackgroundGeolocation.removeGeofences();
    debugPrint("[FBG] Mevcut geofence'ler temizlendi.");

    final prefs = await SharedPreferences.getInstance();
    final String inLocStr = checkInLocation ?? prefs.getString('oldCheckInLoc') ?? '';
    final String outLocStr = checkOutLocation ?? prefs.getString('oldCheckOutLoc') ?? '';

    // -- GİRİŞ ÇİTİ KURULUMU (DOĞRULAMA İLE) --
    try {
      if (inLocStr.isNotEmpty) {
        List<String> parts = inLocStr.split(',');
        if (parts.length == 2) {
          double lat = double.parse(parts[0]);
          double lng = double.parse(parts[1]);

          // --- YENİ EKLENEN KONTROL ---
          // Enlem -90 ile +90, boylam -180 ile +180 arasında olmalıdır.
          if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
            await bg.BackgroundGeolocation.addGeofence(bg.Geofence(
              identifier: 'CHECK_IN_AREA',
              radius: 200,
              latitude: lat,
              longitude: lng,
              notifyOnEntry: true,
              notifyOnExit: true,
              extras: {'type': 'check-in'}
            ));
            debugPrint("[FBG] ✅ GİRİŞ geofence'i başarıyla eklendi: $inLocStr");
          } else {
            debugPrint("❌ [FBG] GİRİŞ geofence'i kurulamadı: GEÇERSİZ KOORDİNAT ($inLocStr)");
          }
        }
      }
    } catch(e) {
      debugPrint("❌ [FBG] GİRİŞ geofence'i eklenirken kritik hata: $e");
    }

    // -- ÇIKIŞ ÇİTİ KURULUMU (DOĞRULAMA İLE) --
    try {
      if (outLocStr.isNotEmpty) {
        List<String> parts = outLocStr.split(',');
        if (parts.length == 2) {
          double lat = double.parse(parts[0]);
          double lng = double.parse(parts[1]);
          
          if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
            await bg.BackgroundGeolocation.addGeofence(bg.Geofence(
              identifier: 'CHECK_OUT_AREA',
              radius: 200,
              latitude: lat,
              longitude: lng,
              notifyOnEntry: true,
              notifyOnExit: true,
              extras: {'type': 'check-out'}
            ));
            debugPrint("[FBG] ✅ ÇIKIŞ geofence'i başarıyla eklendi: $outLocStr");
          } else {
            debugPrint("❌ [FBG] ÇIKIŞ geofence'i kurulamadı: GEÇERSİZ KOORDİNAT ($outLocStr)");
          }
        }
      }
    } catch (e) {
      debugPrint("❌ [FBG] ÇIKIŞ geofence'i eklenirken kritik hata: $e");
    }
  }

  // YENİ FONKSİYON: Geofence olayı tetiklendiğinde çalışır.
  static void _onGeofence(bg.GeofenceEvent event) async {
    debugPrint("🔔 [FBG] Geofence Olayı: $event");
    
    // Örnek: "Kullanıcı CHECK_IN_AREA alanından ÇIKTI (EXIT)"
    String areaType = event.extras?['type'] ?? 'bilinmeyen';
    String action = event.action; // 'ENTER' veya 'EXIT'

    String description = "Kullanıcı $areaType alanına ${action == 'ENTER' ? 'girdi' : 'çıktı'}.";
    debugPrint(description);

    // Sunucuya bu olayı raporla
    await _reportGeofenceEvent(description);
  }

  // YENİ FONKSİYON: Geofence olayını sunucuya kaydeden API isteği.
  static Future<void> _reportGeofenceEvent(String description) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getInt('user_id');

    if (token == null || userId == null) return;
    
    // Kendi API endpoint'ini buraya yazmalısın.
    final url = Uri.parse('${Constants.baseUrl}/geofence-log'); 
    try {
      await http.post(
        url,
        headers: { 'Authorization': 'Bearer $token', 'Content-Type': 'application/json' },
        body: jsonEncode({ 'user_id': userId, 'description': description }),
      );
      debugPrint("✅ Geofence olayı sunucuya raporlandı.");
    } catch(e) {
      debugPrint("❌ Geofence olayı raporlanırken hata: $e");
    }
  }

  // Mevcut diğer fonksiyonlar
  static void _onLocation(bg.Location location) { /* ... */ }
  static void _onMotionChange(bg.Location location) { /* ... */ }
  static Future<void> stop() async { /* ... */ }
}