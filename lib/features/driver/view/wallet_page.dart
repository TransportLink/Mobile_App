import 'package:flutter/material.dart';
import 'package:mobileapp/core/model/transaction.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  String selectedPeriod = 'This Week';
  final List<String> periods = ['Today', 'This Week', 'This Month', 'All Time'];

  // Dummy data
  final double currentBalance = 2450.75;
  final double todayEarnings = 120.50;
  final double weeklyEarnings = 850.25;
  final double monthlyEarnings = 3200.80;

  final List<Transaction> transactions = [
    Transaction(
      id: '1',
      type: TransactionType.earning,
      amount: 45.00,
      description: 'Trip to Accra Mall',
      date: DateTime.now().subtract(const Duration(hours: 2)),
      status: TransactionStatus.completed,
    ),
    Transaction(
      id: '2',
      type: TransactionType.earning,
      amount: 32.50,
      description: 'Trip to East Legon',
      date: DateTime.now().subtract(const Duration(hours: 4)),
      status: TransactionStatus.completed,
    ),
    Transaction(
      id: '3',
      type: TransactionType.withdrawal,
      amount: 200.00,
      description: 'Bank Transfer - GTBank',
      date: DateTime.now().subtract(const Duration(days: 1)),
      status: TransactionStatus.completed,
    ),
    Transaction(
      id: '4',
      type: TransactionType.earning,
      amount: 28.75,
      description: 'Trip to Airport',
      date: DateTime.now().subtract(const Duration(days: 1)),
      status: TransactionStatus.completed,
    ),
    Transaction(
      id: '5',
      type: TransactionType.commission,
      amount: 15.25,
      description: 'Platform Commission',
      date: DateTime.now().subtract(const Duration(days: 2)),
      status: TransactionStatus.pending,
    ),
    Transaction(
      id: '6',
      type: TransactionType.earning,
      amount: 67.50,
      description: 'Trip to Kumasi',
      date: DateTime.now().subtract(const Duration(days: 3)),
      status: TransactionStatus.completed,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
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
                color: Colors.green.shade300,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '+₵${todayEarnings.toStringAsFixed(2)} today',
                style: TextStyle(
                  color: Colors.green.shade300,
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
              () => _showWithdrawModal(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionButton(
              'Add Money',
              Icons.arrow_downward,
              () => _showAddMoneyModal(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionButton(
              'Transfer',
              Icons.swap_horiz,
              () => _showTransferModal(),
            ),
          ),
        ],
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
                    'Today', '₵${todayEarnings.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _buildEarningsStat(
                    'This Week', '₵${weeklyEarnings.toStringAsFixed(2)}'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildEarningsStat(
                    'This Month', '₵${monthlyEarnings.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _buildEarningsStat('Trips', '47'),
              ),
            ],
          ),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
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
                  setState(() {
                    selectedPeriod = value!;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildTransactionItem(transactions[index]);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isEarning = transaction.type == TransactionType.earning;
    final isWithdrawal = transaction.type == TransactionType.withdrawal;
    final isPending = transaction.status == TransactionStatus.pending;

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
              color: isEarning
                  ? Colors.green.shade50
                  : isWithdrawal
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEarning
                  ? Icons.arrow_downward
                  : isWithdrawal
                      ? Icons.arrow_upward
                      : Icons.percent,
              color: isEarning
                  ? Colors.green.shade600
                  : isWithdrawal
                      ? Colors.red.shade600
                      : Colors.orange.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatDate(transaction.date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    if (isPending) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          'Pending',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isWithdrawal ? '-' : '+'}₵${transaction.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isEarning
                  ? Colors.green.shade700
                  : isWithdrawal
                      ? Colors.red.shade700
                      : Colors.orange.shade700,
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

  void _showWithdrawModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _buildActionModal('Withdraw Money', Icons.arrow_upward),
    );
  }

  void _showAddMoneyModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _buildActionModal('Add Money', Icons.arrow_downward),
    );
  }

  void _showTransferModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _buildActionModal('Transfer Money', Icons.swap_horiz),
    );
  }

  Widget _buildActionModal(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'This feature is coming soon!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Close',
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
    );
  }
}
