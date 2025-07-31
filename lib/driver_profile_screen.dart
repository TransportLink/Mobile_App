import 'package:flutter/material.dart';

import 'driver_profile_Setting.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  String _name = 'Not set';
  String _phone = 'Not set';
  String _seats = 'Not set';
  String _vehicle = 'Not set';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Profile'),
        backgroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DriverProfileSetting(),
                ),
              );
              if (result != null && result is Map) {
                setState(() {
                  _name = result['name'] ?? _name;
                  _phone = result['phone'] ?? _phone;
                  _seats = result['seats'] ?? _seats;
                  _vehicle = result['vehicle'] ?? _vehicle;
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: Colors.indigo,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: const Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 60, color: Colors.indigo),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Welcome, Driver!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person, color: Colors.indigo),
                        title: const Text('Full Name'),
                        subtitle: Text(_name),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.phone, color: Colors.indigo),
                        title: const Text('Phone Number'),
                        subtitle: Text(_phone),
                      ),
                      const Divider(),
                      ListTile(
                        leading:
                            const Icon(Icons.event_seat, color: Colors.indigo),
                        title: const Text('Number of Seats'),
                        subtitle: Text(_seats),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.directions_car,
                            color: Colors.indigo),
                        title: const Text('Vehicle Info'),
                        subtitle: Text(_vehicle),
                      ),
                    ],
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
