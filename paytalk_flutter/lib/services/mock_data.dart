import '../models/transaction.dart';
import '../models/chat_message.dart';

/// Fallback mock data used when backend is unavailable.
class MockData {
  static List<Transaction> get transactions => [
        Transaction(
          id: '1',
          title: 'Electricity Bill',
          date: 'Oct 24, 2023 • 02:15 PM',
          amount: 12500.00,
          status: 'COMPLETED',
          type: TransactionType.expense,
        ),
        Transaction(
          id: '2',
          title: 'Water Bill',
          date: 'Oct 23, 2023 • 09:00 AM',
          amount: 1200.00,
          status: 'COMPLETED',
          type: TransactionType.expense,
        ),
        Transaction(
          id: '3',
          title: 'Gas Bill',
          date: 'Oct 22, 2023 • 11:30 AM',
          amount: 3500.00,
          status: 'COMPLETED',
          type: TransactionType.expense,
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
