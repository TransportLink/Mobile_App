import 'package:flutter/material.dart';
import 'package:mobileapp/core/model/demand.dart';
import 'package:mobileapp/features/driver/viewmodel/demand_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Demand List Page - Task 2.5
///
/// Shows ranked bus stop opportunities for drivers.
/// Replaces map-first approach with glanceable list view.
///
/// Design principle: Drivers can't interpret a map while driving.
/// A ranked list is glanceable and actionable.
class DemandListPage extends ConsumerStatefulWidget {
  const DemandListPage({super.key});

  @override
  ConsumerState<DemandListPage> createState() => _DemandListPageState();
}

class _DemandListPageState extends ConsumerState<DemandListPage> {
  @override
  void initState() {
    super.initState();
    // Load demand data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(demandViewmodelProvider.notifier).loadDemand();
    });
  }

  @override
  Widget build(BuildContext context) {
    final demandState = ref.watch(demandViewmodelProvider);

    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(demandState),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Padding(
        padding: EdgeInsets.all(0),
        child: Text(
          'Nearby Opportunities',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () =>
              ref.read(demandViewmodelProvider.notifier).loadDemand(),
          icon: const Icon(Icons.refresh, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildBody(DemandState state) {
    if (state.isLoading && state.demand == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error: ${state.error}', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(demandViewmodelProvider.notifier).loadDemand(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final demand = state.demand;
    if (demand == null || demand.busStops.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No opportunities found nearby',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Try moving to a different location',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(demandViewmodelProvider.notifier).loadDemand(),
      child: Column(
        children: [
          _buildSummary(demand),
          Expanded(child: _buildOpportunitiesList(demand.busStops)),
        ],
      ),
    );
  }

  Widget _buildSummary(DemandData demand) {
    final summary = demand.summary;
    final bestOpp = summary.bestOpportunity;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Opportunities',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${summary.busStopsFound} stops',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (bestOpp != null) ...[
            const Text(
              'Best Opportunity',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bestOpp.location ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSummaryChip(
                  icon: Icons.access_time,
                  label:
                      '${bestOpp.etaMinutes?.toStringAsFixed(1) ?? '--'} min',
                ),
                const SizedBox(width: 8),
                _buildSummaryChip(
                  icon: Icons.trending_up,
                  label:
                      'Score ${(bestOpp.revenueScore ?? 0).toStringAsFixed(2)}',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunitiesList(List<BusStopOpportunity> opportunities) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: opportunities.length,
      itemBuilder: (context, index) {
        final opp = opportunities[index];
        return _buildOpportunityCard(opp, index + 1);
      },
    );
  }

  Widget _buildOpportunityCard(BusStopOpportunity opp, int rank) {
    final isHighDemand = opp.demandLevel == 'high';
    final hasCompetition = (opp.driversEnRoute ?? 0) > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighDemand ? Colors.green.withOpacity(0.3) : Colors.black12,
          width: isHighDemand ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showOpportunityDetails(opp),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: rank <= 3 ? Colors.black : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            color: rank <= 3 ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Location info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opp.location ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.directions_walk,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${opp.distanceKm?.toStringAsFixed(1) ?? '--'} km',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.access_time,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${opp.etaMinutes?.toStringAsFixed(1) ?? '--'} min',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Revenue score
                    _buildScoreBadge(opp.revenueScore ?? 0),
                  ],
                ),
                const SizedBox(height: 16),
                // Demand info
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${opp.totalPassengers ?? 0} passengers waiting',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (opp.destinations.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: opp.destinations.take(3).map((dest) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    dest,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                    // Competition indicator
                    if (hasCompetition)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.people,
                                size: 16, color: Colors.orange[700]),
                            const SizedBox(height: 2),
                            Text(
                              '${opp.driversEnRoute} coming',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBadge(double score) {
    Color badgeColor;
    String label;

    if (score >= 0.7) {
      badgeColor = Colors.green;
      label = 'Excellent';
    } else if (score >= 0.5) {
      badgeColor = Colors.orange;
      label = 'Good';
    } else {
      badgeColor = Colors.grey;
      label = 'Fair';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            score.toStringAsFixed(2),
            style: TextStyle(
              color: badgeColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showOpportunityDetails(BusStopOpportunity opp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                opp.location ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.directions_walk,
                label: 'Distance',
                value: '${opp.distanceKm?.toStringAsFixed(2) ?? '--'} km',
              ),
              _buildDetailRow(
                icon: Icons.access_time,
                label: 'ETA',
                value: '${opp.etaMinutes?.toStringAsFixed(1) ?? '--'} min',
              ),
              _buildDetailRow(
                icon: Icons.people,
                label: 'Passengers',
                value: '${opp.totalPassengers ?? 0}',
              ),
              _buildDetailRow(
                icon: Icons.trending_up,
                label: 'Revenue Score',
                value: (opp.revenueScore ?? 0).toStringAsFixed(2),
              ),
              const SizedBox(height: 24),
              const Text(
                'Destinations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...opp.destinations.map((dest) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(dest, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  )),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // TODO: Navigate to navigation/route guidance
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Navigate Here',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey[700]),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
