import 'package:flutter/material.dart';
import 'noti_service.dart';

class NotiTrialScreen extends StatefulWidget {
  const NotiTrialScreen({Key? key}) : super(key: key);

  @override
  _NotiTrialScreenState createState() => _NotiTrialScreenState();
}

class _NotiTrialScreenState extends State<NotiTrialScreen> {
  @override
  void initState() {
    super.initState();
    // NotiService initialize ediliyor.
    NotiService().initNotification().then((_) {
      print("NotiService successfully initialized.");
    }).catchError((error) {
      print("Initialization error: $error");
    });
  }

  void _sendTestNotification() async {
    try {
      await NotiService().showNotification(
        title: "Test Notification",
        body: "This is a test notification from iOS integration.",
      );
      print("Notification sent successfully");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notification sent successfully")),
      );
    } catch (e) {
      print("Error sending notification: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending notification: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Noti Trial Screen"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _sendTestNotification,
          child: const Text("Send Notification"),
        ),
      ),
    );
  }
}
