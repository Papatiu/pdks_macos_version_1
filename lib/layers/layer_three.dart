import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:mobilperosnel/utils/constants.dart';
import 'package:mobilperosnel/services/notification_service.dart';

class LayerThree extends StatefulWidget {
  const LayerThree({super.key});

  @override
  _LayerThreeState createState() => _LayerThreeState();
}

class _LayerThreeState extends State<LayerThree> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String> _resolveDeviceInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? existingDeviceInfo = prefs.getString('device_info');

    if (existingDeviceInfo != null && existingDeviceInfo.isNotEmpty) {
      return existingDeviceInfo;
    } else {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      String newDeviceInfo =
          "${iosInfo.model}_${iosInfo.systemVersion}_${iosInfo.identifierForVendor}"; // DÜZELTİLDİ
      await prefs.setString('device_info', newDeviceInfo);
      return newDeviceInfo;
    }
  }

  Future<void> _loginUser() async {
    try {
      // 1. Giriş bilgilerini al
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      if (email.isEmpty || password.isEmpty) {
        throw "Lütfen e-posta ve şifre giriniz";
      }

      // 2. Cihaz bilgisini hazırla
      print("🔄 Cihaz bilgisi alınıyor...");
      final deviceInfo = await _resolveDeviceInfo();
      print("📱 Cihaz Bilgisi: $deviceInfo");

      // 3. API isteğini gönder
      print("🌐 API isteği gönderiliyor...");
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'device_info': deviceInfo,
        }),
      ).timeout(const Duration(seconds: 10));

      // 4. Yanıtı işle
      print("✅ Yanıt alındı. Status: ${response.statusCode}");
      print("📦 Response Body: ${response.body}");

      final data = jsonDecode(response.body);
      if (response.statusCode != 200 || data['success'] != true) {
        throw data['message'] ?? "Giriş başarısız";
      }

      // 5. Verileri kaydet
      print("💾 Kullanıcı verileri kaydediliyor...");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', data['access_token']);
      await prefs.setInt('user_id', data['user']['id']);
      await prefs.setString('user_name', data['user']['name']);
      await prefs.setString('device_info', data['user']['device_info']);

      // 6. Yönlendirme yap
      print("🚀 Attendance sayfasına yönlendiriliyor");
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/attendance');

    } on TimeoutException {
      _showError("Sunucu yanıt vermedi");
    } on http.ClientException catch (e) {
      _showError("Ağ hatası: ${e.message}");
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    print("❌ Hata: $message");
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _testNotification() async {
    try {
      await NotificationService().showNotificationCustom(
        'Test Bildirim',
        'Bu bir test bildirimidir! 🚀',
      );

      // Başarı mesajı göster
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bildirim gönderildi! 📨"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Hata mesajı göster
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hata: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: SizedBox(
        height: 584,
        width: MediaQuery.of(context).size.width,
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 59,
              top: 99,
              child: Text(
                'Kullanıcı Adı',
                style: TextStyle(
                  fontFamily: 'Poppins-Medium',
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Positioned(
              left: 59,
              top: 129,
              child: SizedBox(
                width: 310,
                child: TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    border: UnderlineInputBorder(),
                    hintText: 'Kullanıcı Adı',
                  ),
                ),
              ),
            ),
            Positioned(
              left: 59,
              top: 199,
              child: Text(
                'Şifre',
                style: TextStyle(
                  fontFamily: 'Poppins-Medium',
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Positioned(
              left: 59,
              top: 229,
              child: SizedBox(
                width: 310,
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    border: UnderlineInputBorder(),
                    hintText: 'Şifre Giriniz',
                  ),
                ),
              ),
            ),
            Positioned(
              top: 320,
              left: 59,
              right: 59,
              child: GestureDetector(
                onTap: _loginUser,
                child: Container(
                  width: 310,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      'Giriş Yap',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'Poppins-Medium',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 400, // Pozisyonu ihtiyaca göre ayarla
              left: 59,
              right: 59,
              child: GestureDetector(
                onTap: _testNotification,
                child: Container(
                  width: 310,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      'Bildirim Test Et',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'Poppins-Medium',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
