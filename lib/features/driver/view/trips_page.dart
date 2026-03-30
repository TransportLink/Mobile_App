import 'package:mobileapp/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobileapp/core/providers/current_user_notifier.dart';
import 'package:mobileapp/features/map/viewmodel/map_view_model.dart';
import 'package:mobileapp/features/map/repository/map_repository.dart';
import 'package:mobileapp/features/map/view/widgets/nav_with_fab.dart';

class TripsPage extends ConsumerStatefulWidget {
  const TripsPage({super.key});

  @override
  ConsumerState<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends ConsumerState<TripsPage> {
  String _selectedFilter = 'all';
  List<Map<String, dynamic>> _trips = [];
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _today = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final currentDriver = ref.read(currentUserNotifierProvider);
    final driverId = currentDriver?.driverId ?? currentDriver?.id ?? '';
    if (driverId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Please log in to view trips';
      });
      return;
    }

    setState(() => _loading = true);

    final mapRepo = ref.read(mapRepositoryProvider);
    final result = await mapRepo.getDriverTripHistory(
      driverId: driverId,
      status: _selectedFilter,
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
      }),
      (data) => setState(() {
        _loading = false;
        _error = null;
        _trips = List<Map<String, dynamic>>.from(data['trips'] ?? []);
        _summary = Map<String, dynamic>.from(data['summary'] ?? {});
        _today = Map<String, dynamic>.from(data['today'] ?? {});
      }),
    );
  }

  void _goToMap() {
    NavTabController.of(context)?.switchToTab(0);
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapViewModelProvider)?.valueOrNull;
    final hasActiveTrip = mapState?.isOnTrip ?? false;

    return Scaffold(
      backgroundColor: AppPalette.backgroundColor,
      appBar: AppBar(
        title: const Text('Trips', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 22)),
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTrips,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active trip banner — taps to map
                if (hasActiveTrip) _buildActiveTripBanner(mapState!),
                if (hasActiveTrip) const SizedBox(height: 16),

                // Today's summary
                _buildTodaySummary(),
                const SizedBox(height: 20),

                // Status filter chips
                _buildFilterChips(),
                const SizedBox(height: 12),

                // Trip history
                _buildTripHistory(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Small banner linking to the map — not a full trip control card
  Widget _buildActiveTripBanner(mapState) {
    final route = mapState.currentRoute;
    final destinations = mapState.selectedDestinations ?? [];
    final totalPax = destinations.fold(0, (sum, d) => sum + d.passengerCount);
    final destNames = destinations.map((d) => d.destination ?? '').where((n) => n.isNotEmpty).join(', ');

    return GestureDetector(
      onTap: _goToMap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppPalette.primary, AppPalette.primaryDark],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.directions_car, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip #${mapState.tripId ?? ''} in progress',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${route?.eta.toStringAsFixed(0) ?? '?'} min  \u2022  '
                    '${route?.distance.toStringAsFixed(1) ?? '?'} km  \u2022  '
                    '$totalPax pax'
                    '${destNames.isNotEmpty ? '  \u2192  $destNames' : ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySummary() {
    final trips = _today['trips']?.toString() ?? '0';
    final passengers = _today['passengers']?.toString() ?? '0';
    final earnings = _today['earnings'] != null
        ? '\u20B5${(_today['earnings'] as num).toStringAsFixed(0)}'
        : '\u20B50';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppPalette.textPrimary)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildStatItem('Trips', trips, Icons.route)),
              Expanded(child: _buildStatItem('Passengers', passengers, Icons.people)),
              Expanded(child: _buildStatItem('Earnings', earnings, Icons.payments)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppPalette.primary),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppPalette.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: AppPalette.textSecondary)),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'All', 'count': _summary['total']},
      {'key': 'pending', 'label': 'Pending', 'count': _summary['pending']},
      {'key': 'completed', 'label': 'Completed', 'count': _summary['completed']},
      {'key': 'cancelled', 'label': 'Cancelled', 'count': _summary['cancelled']},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final key = f['key'] as String;
          final label = f['label'] as String;
          final count = f['count'];
          final isSelected = _selectedFilter == key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                count != null ? '$label ($count)' : label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppPalette.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedFilter = key);
                _loadTrips();
              },
              selectedColor: AppPalette.primary,
              backgroundColor: AppPalette.surface,
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppPalette.primary : AppPalette.border,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTripHistory() {
    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }

    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadTrips, child: const Text('Retry')),
          ],
        ),
      ));
    }

    if (_trips.isEmpty) {
      return _buildNoTrips();
    }

    return Column(
      children: _trips.map((trip) => _buildTripCard(trip)).toList(),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final status = trip['status'] as String? ?? 'pending';
    final tripId = trip['trip_id'];
    final destNames = List<String>.from(trip['destination_names'] ?? []);
    final totalPax = trip['total_passengers'] ?? 0;
    final locationName = (trip['driver_location_name'] ?? trip['system_id'] ?? '').toString();
    final createdAt = trip['created_at'] as String? ?? '';

    String formattedDate = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        final now = DateTime.now();
        final diff = now.difference(dt);
        if (diff.inMinutes < 60) {
          formattedDate = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          formattedDate = '${diff.inHours}h ago';
        } else if (diff.inDays < 7) {
          formattedDate = '${diff.inDays}d ago';
        } else {
          formattedDate = '${dt.day}/${dt.month}/${dt.year}';
        }
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusLabel = 'En Route';
        break;
      case 'active':
        statusColor = Colors.blue;
        statusIcon = Icons.directions_car;
        statusLabel = 'Active';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusLabel = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusLabel = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusLabel = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status icon
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, size: 18, color: statusColor),
          ),
          const SizedBox(width: 12),
          // Trip details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        locationName.replaceAll('_', ' '),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (destNames.isNotEmpty) ...[
                      Text('  \u2192  ', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      Flexible(
                        child: Text(
                          destNames.join(', '),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalPax pax  \u2022  $formattedDate  \u2022  $statusLabel',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Trip ID
          Text('#$tripId',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildNoTrips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.route, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'all' ? 'No trips yet' : 'No $_selectedFilter trips',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text('Accept a trip from the map to get started',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _goToMap,
            icon: const Icon(Icons.map, size: 18),
            label: const Text('Go to Map'),
          ),
        ],
      ),
    );
  }
}
