import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart' as perm_handler;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:mobilperosnel/utils/constants.dart';
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;
import 'package:mobilperosnel/noti_service.dart'; // NotiService import edildi
import 'package:mobilperosnel/screens/location_service.dart';

import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with WidgetsBindingObserver {

  bool _isResumingFromSettings = false;
  StreamSubscription? _locationPermissionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Yaşam döngüsü dinleyicisini başlat
    _listenForPermissionChanges(); // İzin dinleyicisini başlat

    print('🔄 Splash Screen başlatıldı');
    // Bildirim sistemi başlatılmıyor burada, çünkü senin NotiService init fonksiyonu yoksa gerek yok.
    // Eğer varsa, NotificationService().initNotifications() benzeri çağrı buraya eklenebilir.
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Sayfa kapandığında dinleyiciyi kaldır
    _locationPermissionSubscription?.cancel(); // Sayfa kapandığında dinleyiciyi sonlandır

    super.dispose();
  }

 /* @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _isResumingFromSettings) {
      print("Ayarlardan geri dönüldü, kontroller yeniden başlatılıyor.");
      _isResumingFromSettings = false;
      _initializeApp(); // Tüm kontrol akışını yeniden başlat
    }
  }*/

    /// Geolocator'ın konum izni durumu değişikliklerini dinler.
  void _listenForPermissionChanges() {
    // Mevcut bir dinleyici varsa, önce onu iptal et.
    _locationPermissionSubscription?.cancel();

    _locationPermissionSubscription = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      print("🔄 Konum servis durumu değişti: $status");
      // Konum servisi açıldığında veya bir değişiklik olduğunda,
      // tüm kontrol akışını yeniden başlatmak en güvenli yoldur.
      _initializeApp();
    });
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

    }on TimeoutException {
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
     // splash_screen.dart içindeki eski _handleLocationPermissions fonksiyonunu silip bunu yapıştır.

  Future<bool> _handleLocationPermissions() async {
    // 1. Konum servisleri (GPS) açık mı?
    print('📍 Konum servisleri kontrol ediliyor...');
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ Konum servisleri kapalı.');
     await _showLocationDialog(
        'Uygulamanın çalışması için lütfen cihazınızın konum servislerini (GPS) açın.',
        isGpsError: true,
      );
      // Kullanıcıyı ayarlara yönlendirerek daha iyi bir deneyim sunabiliriz.
     // await Geolocator.openLocationSettings();
      return false; // Servis kapalıysa devam etme
    }

    // 2. Mevcut izin durumunu kontrol et
    LocationPermission permission = await Geolocator.checkPermission();
    print('🔑 Mevcut konum izni: $permission');

    if (Platform.isIOS && permission != LocationPermission.always) {
      permission = await Geolocator.requestPermission();
      LocationPermission finalPermission = await Geolocator.checkPermission();
      if (finalPermission != LocationPermission.always) {
        await _showLocationDialog(
          'Uygulamanın arka planda düzgün çalışabilmesi için konum iznini "Ayarlar"dan "Her Zaman" olarak değiştirmeniz gerekmektedir.',
          showSettingsButton: true,
        );
        return false;
      }
    } 

    // 3. Arka plan takibi için 'always' izni gerekli mi? Kontrol et.
    // iOS'ta arka plan görevi için bu şarttır.
    if (Platform.isIOS) {
      if (permission != LocationPermission.always) {
        print("🔐 iOS için 'Her Zaman' izni gerekli. İzin isteniyor...");
        
        // Önce 'whileInUse' izni istenir (iOS'un zorunlu adımı)
        permission = await Geolocator.requestPermission();
        
        // 'whileInUse' iznini aldıktan sonra, sistem 'always' için tekrar sorabilir.
        // Bu yüzden son durumu tekrar kontrol ediyoruz.
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          LocationPermission finalPermission = await Geolocator.checkPermission();
          if (finalPermission != LocationPermission.always) {
             print("❌ 'Her Zaman' izni alınamadı. Kullanıcı ayarlara yönlendiriliyor.");
             await _showLocationDialog('Uygulamanın arka planda düzgün çalışabilmesi için konum iznini "Ayarlar"dan "Her Zaman" olarak değiştirmeniz gerekmektedir.');
             await Geolocator.openAppSettings();
             return false;
          }
        } else {
          // Kullanıcı 'whileInUse' iznini bile vermediyse
          await _showLocationDialog('Konum izni uygulamanın düzgün çalışması için gereklidir.');
          return false;
        }
      }
    } else if (Platform.isAndroid) {
        // Android için arka plan iznini de kontrol et
        var backgroundPermissionStatus = await perm_handler.Permission.locationAlways.status;
        if (!backgroundPermissionStatus.isGranted) {
           print("🔐 Android için 'Her Zaman' arka plan izni isteniyor...");
           await perm_handler.Permission.locationAlways.request();
        }
    }
    
    // Her iki platform için de son kontrol
    LocationPermission finalStatus = await Geolocator.checkPermission();
    if (finalStatus == LocationPermission.deniedForever) {
      await _showLocationDialog('Konum izni kalıcı olarak reddedildi. Lütfen uygulama ayarlarından manuel olarak izin verin.');
      await Geolocator.openAppSettings();
      return false;
    }

    if (finalStatus != LocationPermission.always && finalStatus != LocationPermission.whileInUse) {
        return false;
    }

     // iOS için 'always' şartını, Android için en azından 'whileInUse' şartını kontrol et
    if (Platform.isIOS && finalStatus != LocationPermission.always) return false;
    if (Platform.isAndroid && (finalStatus != LocationPermission.whileInUse && finalStatus != LocationPermission.always)) return false;

    print('✅ Gerekli konum izinleri mevcut.');
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

  Future<void> _showLocationDialog(String message, {bool showSettingsButton = false, bool isGpsError = false}) async {
    if (!mounted) return;
    
    List<Widget> actions = [];

    if (isGpsError) {
      actions.add(
        TextButton(
          child: const Text('Konum Ayarları\'na Git'),
          onPressed: () async {
            Navigator.of(context).pop();
            await Geolocator.openLocationSettings(); // Cihazın genel konum ayarlarını açar
          },
        ),
      );
    }
    
    if (showSettingsButton) {
      actions.add(
        TextButton(
          child: const Text('Uygulama Ayarları\'na Git'),
          onPressed: () async {
            Navigator.of(context).pop();
            _isResumingFromSettings = true; // Ayarlara gitmeden önce bayrağı true yap
            await Geolocator.openAppSettings(); // Uygulamanın kendi ayarlarına gider
          },
        ),
      );
    }
    
    // Her zaman bir "Tamam" veya "Kapat" butonu olsun
    if (actions.isEmpty) {
        actions.add(
             TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tamam'),
            ),
        );
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Uyarı'),
        content: Text(message),
        actions: actions,
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
