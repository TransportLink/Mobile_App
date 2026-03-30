import 'package:mobileapp/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobileapp/features/auth/view/pages/profile_page.dart';
import 'passenger_map_screen.dart';
import 'passenger_checkin_screen.dart';
import 'passenger_stops_page.dart';
import '../model/passenger_state.dart';
import '../viewmodel/passenger_viewmodel.dart';

class PassengerHomePage extends ConsumerStatefulWidget {
  const PassengerHomePage({super.key});

  @override
  ConsumerState<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends ConsumerState<PassengerHomePage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(passengerNotifierProvider.notifier).refreshCheckIn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final passengerState = ref.watch(passengerNotifierProvider);
    final isCheckedIn = passengerState.isCheckedIn && passengerState.checkInState != null;

    // If checked in, auto-switch to Activity tab to show tracking
    // Auto-switch to Activity/Tracking tab when checked in
    if (isCheckedIn && _selectedIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = 2);
      });
    }

    return Scaffold(
      backgroundColor: AppPalette.backgroundColor,
      appBar: AppBar(
        title: Text(
          isCheckedIn ? 'Live Tracking' : 'Find Your Trotro',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 22, color: AppPalette.textPrimary),
        ),
        backgroundColor: AppPalette.surface,
        elevation: 0,
        actions: [
          if (isCheckedIn)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppPalette.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppPalette.info.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppPalette.info,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'In Queue',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.info,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const PassengerMapScreen(),
          const PassengerStopsPage(),
          _PassengerActivityTab(
            onGoToMap: () => setState(() => _selectedIndex = 0),
          ),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        height: 65,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          const NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Stops',
          ),
          NavigationDestination(
            icon: isCheckedIn
                ? Badge(smallSize: 8, child: const Icon(Icons.directions_bus_outlined))
                : const Icon(Icons.history_outlined),
            selectedIcon: isCheckedIn
                ? Badge(smallSize: 8, child: const Icon(Icons.directions_bus))
                : const Icon(Icons.history),
            label: isCheckedIn ? 'Tracking' : 'Activity',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Activity / Tracking tab — shows tracking when checked in, history when not
class _PassengerActivityTab extends ConsumerWidget {
  final VoidCallback onGoToMap;

  const _PassengerActivityTab({required this.onGoToMap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passengerState = ref.watch(passengerNotifierProvider);

    if (passengerState.isCheckedIn && passengerState.checkInState != null) {
      return _buildTrackingView(context, ref, passengerState);
    }
    return _buildEmptyState(context);
  }

  Widget _buildTrackingView(BuildContext context, WidgetRef ref, PassengerState state) {
    final checkIn = state.checkInState!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Leave queue button
          IconButton(
            onPressed: () => _confirmCheckout(context, ref),
            icon: Icon(Icons.logout, color: Colors.red.shade400, size: 22),
            tooltip: 'Leave queue',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(passengerNotifierProvider.notifier).refreshCheckIn();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status card
            _buildStatusCard(checkIn),
            const SizedBox(height: 16),

            // Queue info
            _buildQueueCard(checkIn),
            const SizedBox(height: 20),

            // Incoming drivers
            Text('Incoming Trotros',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
            const SizedBox(height: 10),

            if (checkIn.incomingDrivers.isNotEmpty)
              ...checkIn.incomingDrivers.asMap().entries.map(
                (entry) => _buildDriverCard(entry.key + 1, entry.value),
              )
            else
              _buildNoDrivers(),

            const SizedBox(height: 20),

            // Leave queue button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmCheckout(context, ref),
                icon: Icon(Icons.close, size: 18, color: Colors.red.shade600),
                label: Text('Leave Queue', style: TextStyle(color: Colors.red.shade600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(PassengerCheckInState checkIn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppPalette.primary, AppPalette.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Checked In',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${checkIn.passengerCount} pax',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            checkIn.destination,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            checkIn.systemId.replaceAll('_', ' '),
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueCard(PassengerCheckInState checkIn) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.tag,
            value: '#${checkIn.queuePosition}',
            label: 'Your position',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.people,
            value: '${checkIn.totalWaiting}',
            label: 'Total waiting',
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.directions_bus,
            value: '${checkIn.incomingDrivers.length}',
            label: 'Trotros coming',
            color: AppPalette.primary,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDriverCard(int position, IncomingDriver driver) {
    final etaColor = (driver.eta ?? 99) <= 5
        ? Colors.green
        : (driver.eta ?? 99) <= 10
            ? Colors.orange
            : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Position badge
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppPalette.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('#$position', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: AppPalette.primaryDark)),
            ),
          ),
          const SizedBox(width: 12),
          // Driver info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (driver.busColor != null) ...[
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: _parseColor(driver.busColor!),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(driver.licensePlate ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${driver.seatsAvailable} seats available',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          // ETA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: etaColor.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 14, color: etaColor.shade700),
                const SizedBox(width: 4),
                Text(
                  driver.eta != null ? '${driver.eta} min' : 'Soon',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: etaColor.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red': return Colors.red;
      case 'blue': return Colors.blue;
      case 'green': return Colors.green;
      case 'yellow': return Colors.yellow.shade700;
      case 'white': return Colors.grey.shade300;
      case 'black': return Colors.black;
      case 'orange': return Colors.orange;
      case 'silver': case 'grey': case 'gray': return Colors.grey;
      default: return Colors.blue.shade300;
    }
  }

  Widget _buildNoDrivers() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.directions_bus_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No trotros nearby yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text("We'll notify you when one is on the way",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Future<void> _confirmCheckout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave queue?'),
        content: const Text("You'll lose your position. You can check in again anytime."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(passengerNotifierProvider.notifier).checkOut(reason: 'manual');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked out'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('No activity yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Text('Check in at a bus stop from the map to see your activity here',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: onGoToMap,
                icon: const Icon(Icons.map, size: 18),
                label: const Text('Find a bus stop'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
