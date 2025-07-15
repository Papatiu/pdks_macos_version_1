// lib/services/location_service.dart

import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Cihazın o anki konumunu yüksek doğrulukla alır.
  /// Hata çıkarsa Exception fırlatır.
  static Future<Position> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
