import 'package:geolocator/geolocator.dart';

class FakeLocationService {
  Position? _lastPosition;
  DateTime? _lastPositionTime;

  Future<bool> isFakeLocation(Position currentPosition) async {
    // Basit mantık: Anormal hız veya kısa sürede büyük mesafe kontrolü.
    if (_lastPosition == null) {
      _lastPosition = currentPosition;
      _lastPositionTime = DateTime.now();
      return false;
    }

    double distance = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );

    Duration timeDiff = DateTime.now().difference(_lastPositionTime!);

    if (timeDiff.inSeconds < 1 && distance > 500) {
      return true;
    }

    double speed = timeDiff.inSeconds == 0 ? 0 : distance / timeDiff.inSeconds;
    if (speed > 200) { // 720 km/h
      return true;
    }

    _lastPosition = currentPosition;
    _lastPositionTime = DateTime.now();
    return false;
  }
}
