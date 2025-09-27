class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String description;
  final DateTime date;
  final TransactionStatus status;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.status,
  });
}

enum TransactionType { earning, withdrawal, commission }
enum TransactionStatus { completed, pending, failed }