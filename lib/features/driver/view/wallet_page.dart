import 'package:mobileapp/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:mobileapp/core/model/transaction.dart';
import 'package:mobileapp/core/model/driver_earnings.dart';
import 'package:mobileapp/features/driver/repository/earnings_repository.dart';
import 'package:mobileapp/core/providers/current_user_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  String selectedPeriod = 'This Week';
  final List<String> periods = ['Today', 'This Week', 'This Month', 'All Time'];

  // Real data from API
  DriverStats? _driverStats;
  EarningsHistory? _earningsHistory;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEarningsData();
  }

  Future<void> _loadEarningsData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final driver = ref.read(currentUserNotifierProvider);
      if (driver == null) {
        setState(() {
          _error = 'Driver not logged in';
          _isLoading = false;
        });
        return;
      }

      final driverId = driver.driverId ?? driver.id;
      if (driverId.isEmpty) {
        setState(() {
          _error = 'Please log in again to view your wallet.';
          _isLoading = false;
        });
        return;
      }

      final earningsRepo = ref.read(earningsRepositoryProvider);
      final periodParam = selectedPeriod.toLowerCase().replaceAll(' ', '');

      // Load stats and earnings in PARALLEL (cuts load time in half)
      final results = await Future.wait([
        earningsRepo.getDriverStats(driverId: driverId),
        earningsRepo.getEarningsHistory(
          driverId: driverId,
          period: periodParam == 'thisweek'
              ? 'week'
              : periodParam == 'thismonth'
                  ? 'month'
                  : periodParam,
        ),
      ]);

      final statsResult = results[0];
      final historyResult = results[1];

      statsResult.fold(
        (failure) => _error = failure.message,
        (stats) => _driverStats = stats as DriverStats,
      );

      historyResult.fold(
        (failure) => _error ??= failure.message,
        (history) => _earningsHistory = history as EarningsHistory,
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(String newPeriod) {
    setState(() {
      selectedPeriod = newPeriod;
    });
    _loadEarningsData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('Error: $_error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadEarningsData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadEarningsData,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildBalanceCard(),
                          _buildQuickActions(),
                          _buildEarningsOverview(),
                          _buildTransactionHistory(),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: const EdgeInsets.all(0),
        child: const Text(
          'Wallet',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.history, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    // Calculate current balance as sum of all earnings
    final currentBalance = _driverStats?.allTime.earnings ?? 0.0;
    final todayEarnings = _driverStats?.today.earnings ?? 0.0;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Current Balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
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
                child: const Text(
                  'GHS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₵${currentBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: todayEarnings > 0 ? AppPalette.primary.withOpacity(0.35) : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                todayEarnings > 0
                    ? '+₵${todayEarnings.toStringAsFixed(2)} today'
                    : 'No earnings today',
                style: TextStyle(
                  color:
                      todayEarnings > 0 ? AppPalette.primary.withOpacity(0.35) : Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              'Withdraw',
              Icons.arrow_upward,
              () => _showComingSoon('Withdraw'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionButton(
              'Add Money',
              Icons.arrow_downward,
              () => _showComingSoon('Add Money'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionButton(
              'Transfer',
              Icons.swap_horiz,
              () => _showComingSoon('Transfer'),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsOverview() {
    final todayStats = _driverStats?.today ??
        PeriodStats(trips: 0, passengers: 0, earnings: 0, hoursActive: 0);
    final weekStats = _driverStats?.thisWeek ??
        PeriodStats(trips: 0, passengers: 0, earnings: 0, hoursActive: 0);
    final monthStats = _driverStats?.thisMonth ??
        PeriodStats(trips: 0, passengers: 0, earnings: 0, hoursActive: 0);

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earnings Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildEarningsStat(
                    'Today', '₵${todayStats.earnings.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _buildEarningsStat(
                    'This Week', '₵${weekStats.earnings.toStringAsFixed(2)}'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildEarningsStat(
                    'This Month', '₵${monthStats.earnings.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _buildEarningsStat('Trips', '${todayStats.trips}'),
              ),
            ],
          ),
          // Show hours active if available
          if (todayStats.hoursActive > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildEarningsStat('Hours Active',
                      '${todayStats.hoursActive.toStringAsFixed(1)}h'),
                ),
                Expanded(
                  child: _buildEarningsStat(
                      'Passengers', '${todayStats.passengers}'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEarningsStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionHistory() {
    final earningsList = _earningsHistory?.earnings ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Trips',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              DropdownButton<String>(
                value: selectedPeriod,
                underline: const SizedBox(),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
                items: periods.map((period) {
                  return DropdownMenuItem(
                    value: period,
                    child: Text(period),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _onPeriodChanged(value);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          earningsList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No trips yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      earningsList.length > 10 ? 10 : earningsList.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final earning = earningsList[index];
                    return _buildEarningsItem(earning);
                  },
                ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEarningsItem(DriverEarnings earning) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppPalette.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.local_taxi,
              color: AppPalette.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  earning.routeSummary,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(earning.tripCompletedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  '${earning.passengerCount} passenger${earning.passengerCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+₵${earning.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppPalette.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
