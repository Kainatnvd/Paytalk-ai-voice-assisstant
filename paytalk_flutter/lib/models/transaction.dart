class Transaction {
  final String id;
  final String title;
  final String date;
  final double amount;
  final String status;
  final TransactionType type;
  final String icon;

  Transaction({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.status,
    required this.type,
    required this.icon,
  });
}

enum TransactionType { expense, income }
