import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/passenger_state.dart';
import '../viewmodel/passenger_viewmodel.dart';
import '../repository/passenger_repository.dart';
import '../widgets/destination_card.dart';
import '../widgets/driver_eta_card.dart';
import '../../../core/model/bus_stop_location.dart';

/// Passenger Check-In Screen
///
/// Shows destination selection when passenger arrives at bus stop.
class PassengerCheckInScreen extends ConsumerStatefulWidget {
  final BusStopLocation? busStop;

  const PassengerCheckInScreen({
    Key? key,
    this.busStop,
  }) : super(key: key);

  @override
  ConsumerState<PassengerCheckInScreen> createState() =>
      _PassengerCheckInScreenState();
}

class _PassengerCheckInScreenState
    extends ConsumerState<PassengerCheckInScreen> {
  List<String> _destinations = [];
  bool _loadingDestinations = true;

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  Future<void> _loadDestinations() async {
    final systemId = widget.busStop?.systemId;
    if (systemId == null) {
      setState(() => _loadingDestinations = false);
      return;
    }
    final result = await passengerRepository.getStopInfo(systemId: systemId);
    if (mounted) {
      setState(() {
        _loadingDestinations = false;
        if (result.isSuccess && result.data != null) {
          _destinations = result.data!.demand.keys.toList();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final passengerState = ref.watch(passengerNotifierProvider);
    final notifier = ref.read(passengerNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Check In at ${widget.busStop?.location ?? "Bus Stop"}'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: (_loadingDestinations || passengerState.isLoading)
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bus stop info
                  _buildBusStopInfo(),
                  const SizedBox(height: 24),

                  // Error message
                  if (passengerState.error != null) ...[
                    _buildErrorMessage(passengerState.error!),
                    const SizedBox(height: 16),
                  ],

                  // Destination selection
                  Text(
                    'Select Destination',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Destination cards
                  ..._destinations.map((destination) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DestinationCard(
                          destination: destination,
                          passengerCount: passengerState.passengerCount,
                          isSelected:
                              passengerState.selectedDestination == destination,
                          onSelect: () =>
                              notifier.selectDestination(destination),
                          onPassengerCountChanged:
                              notifier.setPassengerCount,
                        ),
                      )),

                  const SizedBox(height: 24),

                  // Check-in button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: passengerState.selectedDestination != null
                          ? () => _handleCheckIn(notifier)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Check In',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBusStopInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.blue,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.busStop?.location ?? 'Bus Stop',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.busStop?.systemId ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckIn(PassengerNotifier notifier) async {
    final passengerState = ref.read(passengerNotifierProvider);
    final destination = passengerState.selectedDestination;
    if (destination == null) return;

    final success = await notifier.checkIn(
      systemId: widget.busStop?.systemId ?? 'unknown',
      destination: destination,
      latitude: widget.busStop?.latitude,
      longitude: widget.busStop?.longitude,
    );

    if (success && mounted) {
      // Navigate to tracking screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const PassengerTrackingScreen(),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(passengerState.error ?? 'Check-in failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Passenger Tracking Screen
///
/// Shows queue position, incoming drivers, and live updates after check-in.
/// Listens for auto-checkout (geofence exit) and pops back with a message.
class PassengerTrackingScreen extends ConsumerStatefulWidget {
  const PassengerTrackingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PassengerTrackingScreen> createState() =>
      _PassengerTrackingScreenState();
}

class _PassengerTrackingScreenState
    extends ConsumerState<PassengerTrackingScreen> {
  @override
  void initState() {
    super.initState();
    // Listen for auto-checkout triggered by the geofence service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(passengerNotifierProvider, (previous, next) {
        if ((previous?.isCheckedIn ?? true) && !next.isCheckedIn && mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'You left the bus stop — checked out automatically.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final passengerState = ref.watch(passengerNotifierProvider);
    final notifier = ref.read(passengerNotifierProvider.notifier);
    final checkInState = passengerState.checkInState;

    if (checkInState == null) {
      return const Scaffold(
        body: Center(child: Text('Not checked in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Queue Position'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _showCheckOutDialog(context, notifier),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Queue position card
            _buildQueuePositionCard(checkInState, context),
            const SizedBox(height: 24),

            // Incoming drivers
            Text(
              'Incoming Trotros',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            if (checkInState.incomingDrivers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No incoming trotros yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              ...checkInState.incomingDrivers
                  .asMap()
                  .entries
                  .map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DriverEtaCard(
                          driver: entry.value,
                          position: entry.key + 1,
                        ),
                      )),

            const SizedBox(height: 24),

            // Live updates indicator
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Live updates',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueuePositionCard(PassengerCheckInState state, BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text(
              'Your Position',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Center(
                    child: Text(
                      '#${state.queuePosition}',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${state.totalWaiting} people',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'waiting for ${state.destination}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckOutDialog(BuildContext context, PassengerNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Queue?'),
        content: const Text(
          'Are you sure you want to leave the queue? You will need to check in again when you return.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await notifier.checkOut(reason: 'manual');
              if (context.mounted) {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to previous screen
              }
            },
            child: const Text(
              'Leave',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
