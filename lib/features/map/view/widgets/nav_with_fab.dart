import 'package:flutter/material.dart';
import 'package:mobileapp/features/auth/view/pages/profile_page.dart';
import 'package:mobileapp/features/driver/view/trips_page.dart';
import 'package:mobileapp/features/map/view/pages/demand_list_page.dart';
import 'package:mobileapp/features/map/view/pages/map_page.dart';
import 'package:mobileapp/features/map/view/widgets/custom_bottom_nav.dart';

/// Provides a way for child pages to switch the active tab.
class NavTabController extends InheritedWidget {
  final void Function(int index) switchToTab;

  const NavTabController({
    super.key,
    required this.switchToTab,
    required super.child,
  });

  static NavTabController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NavTabController>();
  }

  @override
  bool updateShouldNotify(NavTabController oldWidget) => false;
}

class NavWithFab extends StatefulWidget {
  const NavWithFab({super.key});

  @override
  State<NavWithFab> createState() => _NavWithFabState();
}

class _NavWithFabState extends State<NavWithFab> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const MapScreen(),
    const TripsPage(),
    const DemandListPage(),
    const ProfilePage(),
  ];

  void _switchToTab(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavTabController(
      switchToTab: _switchToTab,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: CustomBottomNav(
          selectedIndex: _selectedIndex,
          onItemTapped: _switchToTab,
        ),
      ),
    );
  }
}
