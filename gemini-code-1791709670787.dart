import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class Contact {
  final String name;
  final String number;

  Contact({required this.name, required this.number});

  Map<String, dynamic> toJson() => {'name': name, 'number': number};

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(name: json['name'], number: json['number']);
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Contact> _contacts = [];
  bool _isLiveLocationEnabled = true;
  bool _isPoliceSharingEnabled = false;
  String _selectedIncident = 'Thief'; // Default incident type
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndContacts();
  }

  Future<void> _loadSettingsAndContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? contactsJson = prefs.getString('saved_contacts');
    if (contactsJson != null) {
      final List<dynamic> decoded = jsonDecode(contactsJson);
      setState(() {
        _contacts = decoded.map((item) => Contact.fromJson(item)).toList();
      });
    }
    setState(() {
      _isLiveLocationEnabled = prefs.getBool('live_location') ?? true;
      _isPoliceSharingEnabled = prefs.getBool('police_sharing') ?? false;
    });
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_contacts.map((c) => c.toJson()).toList());
    await prefs.setString('saved_contacts', encoded);
  }

  Future<void> _saveToggles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('live_location', _isLiveLocationEnabled);
    await prefs.setBool('police_sharing', _isPoliceSharingEnabled);
  }

  // Handle location permissions and acquisition
  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Main Emergency Dispatch Function
  Future<void> _triggerSOS() async {
    if (_contacts.isEmpty && !_isPoliceSharingEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one contact in Folder 1.')),
      );
      return;
    }

    setState(() => _isSending = true);

    String locationUrl = "";
    if (_isLiveLocationEnabled) {
      Position? position = await _getCurrentLocation();
      if (position != null) {
        locationUrl = "\nMy Location: [https://maps.google.com/?q=$](https://maps.google.com/?q=$){position.latitude},${position.longitude}";
      } else {
        locationUrl = "\nLocation: Unavailable (GPS Disabled)";
      }
    }

    String messageBody = "EMERGENCY ALERT! Type: [$_selectedIncident]. I need urgent assistance!$locationUrl";

    // Collect recipient phone numbers
    List<String> recipients = _contacts.map((c) => c.number).toList();
    if (_isPoliceSharingEnabled) {
      recipients.add("911"); // Standard emergency line, customize as needed
    }

    // Launch Native SMS Dispatch
    String recipientsString = recipients.join(',');
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: recipientsString,
      queryParameters: <String, String>{'body': messageBody},
    );

    setState(() => _isSending = false);

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open messaging application.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.flash_on, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Emergency Message', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.red.shade900,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 3 FOLDERS DASHBOARD SECTION ---
            const Text("Dashboard Folders", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            
            // Folder 1: Add Contact
            _buildFolderCard(
              icon: Icons.folder_shared,
              title: "1. Add Contacts (${_contacts.length})",
              subtitle: "Manage emergency relative contacts",
              color: Colors.blue.shade800,
              onTap: () => _openContactsFolder(context),
            ),
            const SizedBox(height: 10),

            // Folder 2: Live Location Sharing Toggle
            _buildFolderCard(
              icon: Icons.location_on,
              title: "2. Live Location Sharing",
              subtitle: _isLiveLocationEnabled ? "Active: GPS link attached to SOS" : "Disabled",
              color: Colors.orange.shade900,
              trailing: Switch(
                value: _isLiveLocationEnabled,
                activeColor: Colors.amber,
                onChanged: (val) {
                  setState(() => _isLiveLocationEnabled = val);
                  _saveToggles();
                },
              ),
              onTap: () {},
            ),
            const SizedBox(height: 10),

            // Folder 3: Nearest Police Station Alert
            _buildFolderCard(
              icon: Icons.local_police,
              title: "3. Police Station Alert",
              subtitle: _isPoliceSharingEnabled ? "Active: Alerts dispatch line" : "Disabled",
              color: Colors.purple.shade900,
              trailing: Switch(
                value: _isPoliceSharingEnabled,
                activeColor: Colors.purpleAccent,
                onChanged: (val) {
                  setState(() => _isPoliceSharingEnabled = val);
                  _saveToggles();
                },
              ),
              onTap: () {},
            ),

            const SizedBox(height: 25),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),

            // --- INCIDENT SELECTOR CHIPS ---
            const Text("Select Emergency Type:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildIncidentChip("Thief", Icons.security),
                _buildIncidentChip("Accident", Icons.car_crash),
                _buildIncidentChip("Fire", Icons.local_fire_department),
              ],
            ),

            const SizedBox(height: 35),

            // --- BIG RED SOS BUTTON ---
            Center(
              child: GestureDetector(
                onTap: _isSending ? null : _triggerSOS,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isSending ? Colors.grey : Colors.red.shade600,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 25,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSending
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 55, color: Colors.white),
                              SizedBox(height: 5),
                              Text(
                                "SOS",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text("TAP TO SEND", style: TextStyle(fontSize: 10, color: Colors.white70)),
                            ],
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

  // Dashboard Folder UI Builder
  Widget _buildFolderCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }

  // Incident Selector Chip Builder
  Widget _buildIncidentChip(String label, IconData icon) {
    bool isSelected = _selectedIncident == label;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.redAccent),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: Colors.red.shade700,
      backgroundColor: const Color(0xFF2C2C2C),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedIncident = label);
        }
      },
    );
  }

  // Folder 1 Interface: Add/Remove Relative Contacts
  void _openContactsFolder(BuildContext context) {
    TextEditingController nameController = TextEditingController();
    TextEditingController numberController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Folder 1: Add Contacts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Relative Name",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: numberController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Phone Number",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Save Contact", style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      if (nameController.text.isNotEmpty && numberController.text.isNotEmpty) {
                        setState(() {
                          _contacts.add(Contact(name: nameController.text, number: numberController.text));
                        });
                        setModalState(() {});
                        _saveContacts();
                        nameController.clear();
                        numberController.clear();
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text("Saved Relatives:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 150,
                    child: _contacts.isEmpty
                        ? const Center(child: Text("No contacts added yet.", style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _contacts.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                dense: true,
                                title: Text(_contacts[index].name, style: const TextStyle(color: Colors.white)),
                                subtitle: Text(_contacts[index].number, style: const TextStyle(color: Colors.grey)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () {
                                    setState(() {
                                      _contacts.removeAt(index);
                                    });
                                    setModalState(() {});
                                    _saveContacts();
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}