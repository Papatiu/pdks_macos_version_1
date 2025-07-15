import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:mobilperosnel/utils/constants.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobilperosnel/noti_service.dart'; // NotiService import edildi
import 'package:mobilperosnel/screens/location_service.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    print('🔄 Splash Screen başlatıldı');
    // Bildirim sistemi başlatılmıyor burada, çünkü senin NotiService init fonksiyonu yoksa gerek yok.
    // Eğer varsa, NotificationService().initNotifications() benzeri çağrı buraya eklenebilir.

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    print('📍 Konum izinleri kontrol ediliyor...');
    final locationAllowed = await _handleLocationPermissions();
    if (!locationAllowed) {
      print('❌ Konum izinleri reddedildi');
      NotiService().showNotification(
          title: "Hata", body: "Konum izinleri reddedildi");
      return;
    }

    // 🔔 Bildirim izinlerinin kontrolü
    print('🔔 Bildirim izinleri kontrol ediliyor...');
    final notificationAllowed = await _handleNotificationPermissions();
    if (!notificationAllowed) {
      print('❌ Bildirim izinleri reddedildi');
      NotiService().showNotification(
          title: "Hata", body: "Bildirim izinleri reddedildi");
      // Bildirim izni reddedilmiş olsa da diğer işlemlere devam edilebilir.
    }

    print('🔐 SharedPreferences verileri okunuyor...');
    NotiService().showNotification(
        title: "Info", body: "SharedPreferences verileri okunuyor...");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getInt('user_id');
    final deviceInfo = prefs.getString('device_info');

    print('''
📦 Kayıtlı Veriler:
- Token: ${token != null ? '✅ Mevcut' : '❌ YOK'}
- UserID: ${userId ?? '❌ YOK'}
- DeviceInfo: ${deviceInfo ?? '❌ YOK'}
    ''');

    if (token == null || userId == null || deviceInfo == null) {
      print('❌ Eksik kullanıcı verisi, login sayfasına yönlendiriliyor');
      NotiService().showNotification(
          title: "Hata", body: "Eksik kullanıcı verisi");
      _navigateToLogin();
      return;
    }

    print('\n📡 [CHECK-ALL API] Sistem kontrolleri başlatılıyor...');
    try {
      final checkAllResponse = await http.post(
        Uri.parse('${Constants.baseUrl}/check-all'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {'device_info': deviceInfo},
      ).timeout(const Duration(seconds: 10));

      print('🔍 [DEBUG] Check-All Raw Response: ${checkAllResponse.body}');
      NotiService().showNotification(
          title: "API Debug",
          body: "Check-All Raw Response: ${checkAllResponse.body}");

      final checkAllData = jsonDecode(checkAllResponse.body);
      final rawStatus = checkAllData['status']?.toString() ?? 'error';
      final status = rawStatus.toLowerCase().trim();
      final reason = checkAllData['reason']?.toString() ?? 'Bilinmeyen sebep';

      print('\n⚙️ [CHECK-ALL] İşlenen Durum: $status');
      NotiService()
          .showNotification(title: "CHECK-ALL", body: "İşlenen Durum: $status");

      switch (status) {
        case 'version_update':
        case 'forced_update':
          NotiService().showNotification(
            title: "Version Update",
            body: "🚨 Yeni sürüm gerekli! Sebep: $reason",
          );
          _handleVersionUpdate(checkAllData);
          return;

        case 'banned':
        case 'blocked':
          NotiService().showNotification(
            title: "Ban",
            body: "🔞 Kullanıcı banlandı! Sebep: $reason",
          );
          _navigateToLoading(
              reason: 'banned', desc: 'Hesabınız banlandı: $reason');
          return;

        case 'holiday':
        case 'tatil':
          NotiService().showNotification(
            title: "Tatil",
            body: "🎉 Tatil modu aktif! Mesaj: $reason",
          );
          _navigateToLoading(
              reason: 'holiday', desc: 'Tatil nedeniyle kapalı: $reason');
          return;

        case 'ok':
          NotiService().showNotification(
            title: "Başarılı",
            body: "✅ Tüm kontroller başarılı!",
          );
          break;

        default:
          NotiService().showNotification(
            title: "Hata",
            body: "❌ Geçersiz durum: $status",
          );
          _navigateToLoading(
              reason: 'error',
              desc: 'Sistem hatası (Kod: ${checkAllResponse.statusCode})');
          return;
      }
    } on TimeoutException {
      print('⌛ Sunucu yanıt vermedi');
      NotiService()
          .showNotification(title: "Zaman Aşımı", body: "Sunucu yanıt vermedi");
      _navigateToLoading(reason: 'timeout', desc: 'Sunucuya bağlanılamadı');
      return;
    } on SocketException {
      print('🌐 Ağ hatası');
      NotiService().showNotification(
          title: "Ağ Hatası", body: "İnternet bağlantısı yok");
      _navigateToLoading(reason: 'network_error', desc: 'İnternet yok');
      return;
    } catch (e) {
      print('❌ Kritik hata: ${e.toString()}');
      NotiService().showNotification(
          title: "Kritik Hata", body: "Hata: ${e.toString()}");
      _navigateToLoading(
          reason: 'error', desc: 'Beklenmeyen hata: ${e.toString()}');
      return;
    }

    print('\n🌐 Cihaz doğrulama isteği gönderiliyor...');
    NotiService().showNotification(
        title: "Cihaz Doğrulama",
        body: "Cihaz doğrulama isteği gönderiliyor...");
    try {
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/device/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'device_info': deviceInfo,
        }),
      ).timeout(const Duration(seconds: 10));

      print('✅ [DEVICE VERIFY] Yanıt alındı. Status: ${response.statusCode}');
      NotiService().showNotification(
          title: "DEVICE VERIFY", body: "Status: ${response.statusCode}");
      print('📦 [DEVICE VERIFY] Response Body: ${response.body}');
      NotiService().showNotification(
          title: "DEVICE VERIFY", body: "Response: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message'] == "Device verified" || data['success'] == true) {
          print(
              '🎉 Cihaz doğrulama başarılı! Attendance screen\'e yönlendiriliyor');
          try {
            print('📍 Konum alınıyor...');
            Position pos = await LocationService.getCurrentPosition();
            print('✅ Konum bulundu: Lat=${pos.latitude}, Lon=${pos.longitude}');
            // İstersen prefs veya API ile kaydedebilirsin
          } catch (e) {
            print('❌ Konum alınırken hata: $e');
          }
          NotiService().showNotification(
              title: "Cihaz Doğrulama",
              body: "Başarılı! Attendance screen'e yönlendiriliyor");
          _navigateToAttendance();
        } else {
          print('❌ Cihaz doğrulama başarısız: ${data['message']}');
          NotiService().showNotification(
              title: "Cihaz Doğrulama", body: "Başarısız: ${data['message']}");
          _clearCredentialsAndNavigate();
        }
      } else {
        print('❌ [DEVICE VERIFY] HTTP Hatası: ${response.statusCode}');
        NotiService().showNotification(
            title: "DEVICE VERIFY",
            body: "HTTP Hatası: ${response.statusCode}");
        _clearCredentialsAndNavigate();
      }
    } on TimeoutException {
      print('⌛ [DEVICE VERIFY] Zaman aşımı');
      NotiService().showNotification(
          title: "Zaman Aşımı", body: "[DEVICE VERIFY] Zaman aşımı");
      _clearCredentialsAndNavigate();
    } on SocketException {
      print('🌐 [DEVICE VERIFY] Ağ hatası');
      NotiService().showNotification(
          title: "Ağ Hatası", body: "İnternet bağlantısı yok");
      _clearCredentialsAndNavigate();
    } catch (e) {
      print('❌ [DEVICE VERIFY] Beklenmeyen hata: ${e.toString()}');
      NotiService().showNotification(
          title: "Cihaz Doğrulama Hatası", body: "${e.toString()}");
      _clearCredentialsAndNavigate();
    }
  }

  Future<bool> _handleLocationPermissions() async {
    print('📍 Konum servisleri kontrol ediliyor...');
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ Konum servisleri kapalı');
      NotiService().showNotification(
          title: "Konum Hatası", body: "Konum servisleri kapalı!");
      await _showLocationDialog('Konum servisleri kapalı!');
      return false;
    }

    print('🔑 Konum izin durumu kontrol ediliyor...');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      print('❌ Kalıcı izin reddedilmiş');
      NotiService().showNotification(
          title: "Konum Hatası", body: "Kalıcı izin reddedildi");
      await _showLocationDialog('Konum izni sürekli reddedildi!');
      return false;
    }

    if (permission == LocationPermission.denied) {
      print('🔐 Konum izni isteniyor...');
      NotiService().showNotification(
          title: "Konum İzni", body: "Konum izni isteniyor...");
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        print('❌ Konum izni reddedildi');
        NotiService().showNotification(
            title: "Konum İzni", body: "Konum izni reddedildi");
        return false;
      }
    }
    print('✅ Konum izni onaylandı');
    NotiService()
        .showNotification(title: "Konum İzni", body: "Konum izni onaylandı");
    return true;
  }

  Future<bool> _handleNotificationPermissions() async {
    print('🔔 Bildirim izin durumu kontrol ediliyor...');
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      print('🔐 Bildirim izni isteniyor...');
      NotiService().showNotification(
          title: "Bildirim İzni", body: "Bildirim izni isteniyor...");
      final result = await Permission.notification.request();
      if (!result.isGranted) {
        return false;
      }
    }
    print('✅ Bildirim izni onaylandı');
    NotiService().showNotification(
        title: "Bildirim İzni", body: "Bildirim izni onaylandı");
    return true;
  }

  void _handleVersionUpdate(Map<String, dynamic> data) {
    final versionLink = data['version_link']?.toString() ?? '';
    final versionDesc = data['version_desc']?.toString() ?? 'Yeni sürüm mevcut';

    print('''🚀 [VERSION UPDATE] 
    Link: $versionLink
    Açıklama: $versionDesc
    ''');
    NotiService().showNotification(
      title: "Version Update",
      body: "🚀 [VERSION UPDATE] Link: $versionLink, Açıklama: $versionDesc",
    );

    _navigateToLoading(
      reason: 'version_update',
      desc: versionDesc,
      link: versionLink,
    );
  }

  void _navigateToLoading({
    required String reason,
    String desc = '',
    String link = '',
  }) {
    print('''
⏳ LOADING SAYFASINA YÖNLENDİRME
├─ Sebep: $reason
├─ Açıklama: $desc
${link.isNotEmpty ? '└─ Link: $link' : ''}''');
    NotiService().showNotification(
      title: "Loading",
      body:
          "Sebep: $reason, Açıklama: $desc ${link.isNotEmpty ? 'Link: $link' : ''}",
    );
    Navigator.pushReplacementNamed(
      context,
      '/loading',
      arguments: {
        'reason': reason,
        'desc': desc,
        'link': link,
      },
    );
  }

  Future<void> _showLocationDialog(String message) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Uyarı'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCredentialsAndNavigate() async {
    print('🔓 Kullanıcı bilgileri temizleniyor...');
    NotiService().showNotification(
        title: "Temizleme", body: "Kullanıcı bilgileri temizleniyor...");
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _navigateToLogin();
  }

  void _navigateToLogin() {
    print('🔜 Login sayfasına yönlendiriliyor...');
    NotiService().showNotification(
        title: "Yönlendirme", body: "Login sayfasına yönlendiriliyor...");
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _navigateToAttendance() {
    print('🔜 Attendance sayfasına yönlendiriliyor...');
    NotiService().showNotification(
        title: "Yönlendirme", body: "Attendance sayfasına yönlendiriliyor...");
    Navigator.pushReplacementNamed(context, '/attendance');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade300, Colors.purple.shade200],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                'https://www.eyyubiye.bel.tr/images/logo.png',
                height: 180,
                width: 180,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : CircularProgressIndicator(),
              ),
              SizedBox(height: 30),
              Text(
                'Yükleniyor...',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
