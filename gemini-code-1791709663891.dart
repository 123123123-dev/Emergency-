import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EmergencyApp());
}

class EmergencyApp extends StatelessWidget {
  const EmergencyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emergency Message',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: const Color(0xFF121212),
        brightness: Brightness.dark,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // App State Variables
  List<Map<String, String>> contacts = [];
  bool isLiveLocationEnabled = true;
  bool isPoliceStationEnabled = false;
  String policeNumber = "911"; // Default emergency number
  String selectedIncident = "General Emergency";
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndContacts();
    _requestPermissions();
  }

  // Request Runtime Permissions
  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.sms.request();
  }

  // Load Saved Data from Local Storage
  Future<void> _loadSettingsAndContacts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isLiveLocationEnabled = prefs.getBool('live_location') ?? true;
      isPoliceStationEnabled = prefs.getBool('police_alert') ?? false;
      policeNumber = prefs.getString('police_number') ?? "911";
      String? savedContacts = prefs.getString('contacts_list');
      if (savedContacts != null) {
        contacts = List<Map<String, String>>.from(
          (jsonDecode(savedContacts) as List).map(
            (item) => Map<String, String>.from(item),
          ),
        );
      }
    });
  }

  // Save Data to Local Storage
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('live_location', isLiveLocationEnabled);
    await prefs.setBool('police_alert', isPoliceStationEnabled);
    await prefs.setString('police_number', policeNumber);
    await prefs.setString('contacts_list', jsonEncode(contacts));
  }

  // Execute SOS Trigger
  Future<void> _triggerSOS() async {
    if (contacts.isEmpty && !isPoliceStationEnabled) {
      _showSnackBar("Please add at least one contact or enable Police alert!");
      return;
    }

    setState(() => isSending = true);

    try {
      String locationUrl = "";
      if (isLiveLocationEnabled) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        locationUrl =
            "\nMy Location: https://maps.google.com/?q=${position.latitude},${position.longitude}";
      }

      // Build Dispatch Message
      String message =
          "🚨 EMERGENCY ALERT: [$selectedIncident]! I need immediate help! $locationUrl";

      // Collect Recipient Phone Numbers
      List<String> recipients = contacts.map((c) => c['phone']!).toList();
      if (isPoliceStationEnabled && policeNumber.isNotEmpty) {
        recipients.add(policeNumber);
      }

      // Send via System SMS Client
      String uri = 'sms:${recipients.join(',')}?body=${Uri.encodeComponent(message)}';
      if (await canLaunchUrl(Uri.parse(uri))) {
        await launchUrl(Uri.parse(uri));
      } else {
        _showSnackBar("Failed to open SMS app.");
      }
    } catch (e) {
      _showSnackBar("Error fetching location or dispatching message: $e");
    } finally {
      setState(() => isSending = false);
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.flash_on, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text(
              "EMERGENCY MESSAGE",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.stretch,
          children: [
            // Folder 1: Add Contacts
To build a fully functional cross-platform app (**Emergency Message**), use **Flutter**. Below is the complete app architecture, including the full `main.dart` source code, configuration files, and permissions required to run it.

---

### 1. Project Dependencies (`pubspec.yaml`)

Add these required dependencies to your `pubspec.yaml` file:

```yaml
name: emergency_message
description: "Emergency SOS app with direct messaging, location, and alert management."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  geolocator: ^10.1.0
  url_launcher: ^6.2.5
  shared_preferences: ^2.2.2
  flutter_local_notifications: ^17.0.0
  cupertino_icons: ^1.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true