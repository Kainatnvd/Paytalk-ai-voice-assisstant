enum TransactionType { expense, income }

class Transaction {
  final String id;
  final String title;
  final String date;
  final double amount;
  final String status;
  final TransactionType type;
  final String? recipientAccount;
  final String? raastReferenceId;
  final String? failureReason;

  Transaction({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.status,
    required this.type,
    this.recipientAccount,
    this.raastReferenceId,
    this.failureReason,
  });

  factory Transaction.fromJson(
      Map<String, dynamic> json, String currentUserId) {
    bool isExpense = json['sender_id'] == currentUserId;

    // Parse date nicely
    String dateStr = json['created_at'].toString();
    String formattedDate = dateStr;
    try {
      final dt = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      formattedDate =
          '${months[dt.month - 1]} ${dt.day}, ${dt.year} • ${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {}

    return Transaction(
      id: json['id'].toString(),
      title: json['recipient_name'] ?? 'Transfer',
      date: formattedDate,
      amount: double.parse(json['amount'].toString()),
      status: (json['status'] ?? 'pending').toString().toUpperCase(),
      type: isExpense ? TransactionType.expense : TransactionType.income,
      recipientAccount: json['recipient_account'],
      raastReferenceId: json['raast_reference_id'],
      failureReason: json['failure_reason'],
    );
  }
}
