import '../models/transaction.dart';
import '../models/chat_message.dart';

class MockData {
  static List<Transaction> get transactions => [
        Transaction(
          id: '1',
          title: 'Apple Store',
          date: 'Oct 24, 2023 • 02:15 PM',
          amount: 1299.00,
          status: 'COMPLETED',
          type: TransactionType.expense,
          icon: 'shopping_bag',
        ),
        Transaction(
          id: '2',
          title: 'Salary Deposit',
          date: 'Oct 23, 2023 • 09:00 AM',
          amount: 8450.00,
          status: 'COMPLETED',
          type: TransactionType.income,
          icon: 'call_received',
        ),
      ];

  static List<ChatMessage> get chatMessages => [
        ChatMessage(
          text: 'How can I help you manage your funds today, Alex?',
          sender: MessageSender.assistant,
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        ChatMessage(
          text: "What's my spending limit for this week?",
          sender: MessageSender.user,
          timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      ];
}
