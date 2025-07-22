// lib/services/network_security_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class NetworkSecurityService {
  
  /// Bir GPS konumu ile cihazın genel IP adresinin konumunu karşılaştırır.
  /// Arada büyük bir tutarsızlık varsa `false` (güvenilmez), yoksa `true` (güvenilir) döner.
  static Future<bool> isNetworkLocationConsistent(Position gpsPosition) async {
    try {
      // 1. Cihazın genel IP adresini al.
      final publicIp = await _getPublicIpAddress();
      if (publicIp == null) {
        debugPrint("⚠️ [NetworkSecurity] IP adresi alınamadı. Kontrol atlanıyor.");
        return true; // IP alınamazsa, kullanıcıyı mağdur etmemek için güvenli kabul et.
      }
      debugPrint("ℹ️ [NetworkSecurity] Cihazın IP Adresi: $publicIp");

      // 2. IP adresinin coğrafi konumunu bul.
      final ipLocationData = await _getGeoLocationFromIp(publicIp);
      if (ipLocationData == null || ipLocationData['status'] != 'success') {
        debugPrint("⚠️ [NetworkSecurity] IP adresinin konumu bulunamadı. Kontrol atlanıyor.");
        return true;
      }
      
      final double ipLat = ipLocationData['lat'];
      final double ipLon = ipLocationData['lon'];
      final String ipCity = ipLocationData['city'] ?? 'Bilinmiyor';
      debugPrint("ℹ️ [NetworkSecurity] IP Konumu: $ipCity ($ipLat, $ipLon)");

      // 3. İki konum arasındaki mesafeyi hesapla.
      final double distanceInMeters = Geolocator.distanceBetween(
        gpsPosition.latitude,
        gpsPosition.longitude,
        ipLat,
        ipLon,
      );
      
      final double distanceInKm = distanceInMeters / 1000;
      debugPrint("↔️ [NetworkSecurity] GPS konumu ile IP konumu arasındaki mesafe: ${distanceInKm.toStringAsFixed(2)} km");

      // 4. Karar ver: Mesafe 100 km'den fazlaysa, bu büyük bir tutarsızlıktır.
      // Bu eşik değeri, projenin ihtiyacına göre ayarlanabilir.
      if (distanceInKm > 100) {
        debugPrint("🚨 AĞ İHLALİ: GPS ve IP konumları arasında >100km fark var!");
        return false;
      }

    } catch (e) {
      debugPrint("❌ [NetworkSecurity] Ağ analizi sırasında hata: $e");
      return true; // Hata durumunda güvenli kabul etmek en iyisidir.
    }
    
    // Tüm kontrollerden geçti.
    return true;
  }

  /// Cihazın genel (public) IP adresini döndürür.
  static Future<String?> _getPublicIpAddress() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org?format=json'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['ip'];
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Bir IP adresinin coğrafi konum bilgilerini döndürür.
  static Future<Map<String, dynamic>?> _getGeoLocationFromIp(String ipAddress) async {
    try {
      final response = await http.get(Uri.parse('http://ip-api.com/json/$ipAddress'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}