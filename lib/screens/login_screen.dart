import 'package:flutter/material.dart';
import 'package:mobilperosnel/layers/layer_one.dart';
import 'package:mobilperosnel/layers/layer_two.dart';
import 'package:mobilperosnel/layers/layer_three.dart';
import 'package:geolocator/geolocator.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _getLocation(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Konum servislerinin etkin olup olmadığını kontrol et
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konum servisleri devre dışı.')),
      );
      return;
    }

    // Konum izinlerini kontrol et
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konum izinleri reddedildi.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konum izinleri kalıcı olarak reddedildi.')),
      );
      return;
    }

    // Konumu al
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Konumu ekrana yazdır
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Konum: ${position.latitude}, ${position.longitude}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/primaryBg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Image.network(
                  'https://www.eyyubiye.bel.tr/images/logo.png',
                  height: 120,
                  width: 120,
                ),
              ),
            ),
            Positioned(
              top: 230,
              left: 0,
              right: 0,
              child: AnimatedText(),
            ),
            Positioned(top: 290, right: 0, bottom: 0, child: LayerOne()),
            Positioned(top: 318, right: 0, bottom: 28, child: LayerTwo()),
            Positioned(top: 320, right: 0, bottom: 48, child: LayerThree()),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  onPressed: () => _getLocation(context),
                  child: Text('Konumu Al'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedText extends StatefulWidget {
  const AnimatedText({super.key});

  @override
  _AnimatedTextState createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<AnimatedText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Text(
        'Eyyübiye Belediyesi',
        textAlign: TextAlign.center, // Yazıyı yatayda ortalar
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}