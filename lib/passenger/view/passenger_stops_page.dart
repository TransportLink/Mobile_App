import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/core/model/bus_stop_location.dart';
import 'package:mobileapp/features/map/repository/map_repository.dart';
import 'passenger_checkin_screen.dart';

/// Shows nearby bus stops with passenger counts and destinations.
/// Passenger equivalent of the driver's Demand page.
class PassengerStopsPage extends ConsumerStatefulWidget {
  const PassengerStopsPage({super.key});

  @override
  ConsumerState<PassengerStopsPage> createState() => _PassengerStopsPageState();
}

class _PassengerStopsPageState extends ConsumerState<PassengerStopsPage> {
  List<BusStop> _stops = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    setState(() => _loading = true);
    try {
      final pos = await geo.Geolocator.getLastKnownPosition() ??
          await geo.Geolocator.getCurrentPosition(desiredAccuracy: geo.LocationAccuracy.medium);

      if (!mounted) return;

      final repo = ref.read(mapRepositoryProvider);
      final result = await repo.fetchBusStops(
        latitude: pos.latitude,
        longitude: pos.longitude,
        radius: 5.0,
      );

      if (!mounted) return;

      result.fold(
        (err) => setState(() {
          _error = err.message;
          _loading = false;
        }),
        (stops) => setState(() {
          _stops = stops..sort((a, b) => b.totalCount.compareTo(a.totalCount));
          _loading = false;
          _error = null;
        }),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not get location';
          _loading = false;
        });
      }
    }
  }

  void _checkIn(BusStop stop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PassengerCheckInScreen(
          busStop: BusStopLocation(
            systemId: stop.systemId,
            latitude: stop.latitude,
            longitude: stop.longitude,
            location: stop.systemId.replaceAll('_', ' '),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Stops', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadStops,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _loadStops, child: const Text('Retry')),
                    ],
                  ),
                )
              : _stops.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_off, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No bus stops nearby',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadStops,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _stops.length,
                        itemBuilder: (context, index) => _buildStopCard(_stops[index]),
                      ),
                    ),
    );
  }

  Widget _buildStopCard(BusStop stop) {
    final hasPassengers = stop.totalCount > 0;
    final dests = stop.destinations.entries.where((e) => e.value > 0).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPassengers ? Colors.green.shade200 : Colors.grey.shade200,
          width: hasPassengers ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasPassengers ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.hail_rounded, size: 22,
                    color: hasPassengers ? Colors.green.shade700 : Colors.grey.shade500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.systemId.replaceAll('_', ' '),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${stop.totalCount} people waiting',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              // Total count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: hasPassengers ? Colors.green.shade600 : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${stop.totalCount}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          // Destination breakdown
          if (dests.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: dests.map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(e.key, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        const SizedBox(width: 4),
                        Text('${e.value}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                      ],
                    ),
                  )).toList(),
            ),
          ],
          // Check in button
          if (hasPassengers) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 42,
              child: ElevatedButton.icon(
                onPressed: () => _checkIn(stop),
                icon: const Icon(Icons.how_to_reg, size: 16),
                label: const Text('Check In', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
