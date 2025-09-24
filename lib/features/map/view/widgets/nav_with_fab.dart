import 'package:flutter/material.dart';
import 'package:mobileapp/features/auth/view/pages/profile_page.dart';
import 'package:mobileapp/features/driver/view/driver_documents_page.dart';
import 'package:mobileapp/features/driver/view/vehicle_page.dart';
import 'package:mobileapp/features/driver/view/wallet_page.dart';
import 'package:mobileapp/features/map/view/pages/map_page.dart';
import 'package:mobileapp/features/map/view/widgets/custom_bottom_nav.dart';

class NavWithFab extends StatefulWidget {
  const NavWithFab({super.key});

  @override
  State<NavWithFab> createState() => _NavWithFabState();
}

class _NavWithFabState extends State<NavWithFab> {
  int _selectedIndex = 2;

  final List<Widget> _pages = [
    WalletPage(),
    VehiclesPage(),
    MapPage(),
    DriverDocumentsPage(),
    ProfilePage()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
