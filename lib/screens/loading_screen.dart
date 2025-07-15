import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:io'; // Platform kontrolü ve exit() için eklendi

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  // Uygulamayı platforma göre kapatan fonksiyon
  void _closeApp() {
    if (Platform.isIOS) {
      exit(0); // iOS için işlemi sonlandırır (App Store riski taşır)
    } else {
      SystemNavigator.pop(); // Android için standart kapatma yöntemi
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final reason = args?['reason'] ?? 'unknown';
    final desc = args?['desc'] ?? '';
    final link = args?['link'] ?? '';

    String title;
    String subtitle;
    String emoji = "";
    List<Widget> actions = [];
    
    // Uygulamayı Kapat butonu için ortak stil
    final closeButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.white, // Arka plan beyaz
      foregroundColor: Colors.redAccent, // Yazı rengi kırmızı
    );

    switch (reason) {
      case 'network_error':
        title = 'Bağlantı Hatası';
        subtitle = desc.isNotEmpty
            ? desc
            : 'İnternet bağlantınızı kontrol edip tekrar deneyin.';
        emoji = "🌐";
        actions.addAll([
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/splash'),
            child: const Text('Tekrar Dene'),
          ),
          const SizedBox(height: 10),
          // --- BUTON GÜNCELLENDİ ---
          ElevatedButton(
            onPressed: _closeApp,
            style: closeButtonStyle,
            child: const Text('Uygulamayı Kapat'),
          )
        ]);
        break;

      case 'timeout':
        title = 'Sunucuya Ulaşılamıyor';
        subtitle = desc.isNotEmpty ? desc : 'Lütfen daha sonra tekrar deneyin.';
        emoji = "⌛";
        actions.addAll([
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/splash'),
            child: const Text('Tekrar Dene'),
          ),
          const SizedBox(height: 10),
          // --- BUTON GÜNCELLENDİ ---
          ElevatedButton(
            onPressed: _closeApp,
            style: closeButtonStyle,
            child: const Text('Uygulamayı Kapat'),
          )
        ]);
        break;

      case 'banned':
        title = 'Hesap Askıya Alındı';
        subtitle = desc.isNotEmpty
            ? desc
            : 'Lütfen yöneticinizle iletişime geçin.';
        emoji = "🚫";
        actions.add(
          ElevatedButton(
            onPressed: _closeApp,
            child: const Text('Tamam'),
          ),
        );
        break;

      case 'holiday':
      case 'weekend':
        title = reason == 'holiday' ? 'Resmi Tatil' : 'Hafta Sonu';
        subtitle = desc.isNotEmpty ? desc : 'Sistem şu anda kapalıdır.';
        emoji = reason == 'holiday' ? "🎉" : "📅";
        actions.add(
          ElevatedButton(
            onPressed: _closeApp,
            child: const Text('Tamam'),
          ),
        );
        break;

      case 'version_update':
        title = 'Güncelleme Gerekli';
        subtitle = desc;
        emoji = "⚠️";
        actions.addAll([
          ElevatedButton(
            onPressed: () {
              if (link.isNotEmpty) {
                launchUrl(Uri.parse(link));
              }
            },
            child: const Text('Şimdi Güncelle'),
          ),
          const SizedBox(height: 10),
          // --- BUTON GÜNCELLENDİ ---
          ElevatedButton(
            onPressed: _closeApp,
            style: closeButtonStyle,
            child: const Text('Uygulamayı Kapat'),
          ),
        ]);
        break;

      default:
        title = 'Sistem Hatası';
        subtitle = desc.isNotEmpty ? desc : 'Beklenmeyen bir hata oluştu.';
        emoji = "❌";
        actions.add(
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/splash'),
            child: const Text('Tekrar Dene'),
          ),
        );
    }

    return Scaffold(
      backgroundColor: Colors.cyan,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Image.network(
                  'https://www.eyyubiye.bel.tr/images/logo.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "$emoji $title",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 30),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}