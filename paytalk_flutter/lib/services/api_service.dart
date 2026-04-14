import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000'; // Update with actual host

  Future<Map<String, dynamic>> login(String phone, String password) async {
    // Stub for demonstration
    await Future.delayed(const Duration(seconds: 1));
    if (phone == '1234567890' && password == 'password') {
      return {'status': 'success', 'token': 'fake_token_123'};
    }
    
    // Actual implementation (commented out until server is ready)
    /*
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      body: json.encode({'phone': phone, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );
    return json.decode(response.body);
    */
    
    return {'status': 'error', 'message': 'Invalid credentials'};
  }

  Future<double> getBalance() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 24500.00;
  }

  Future<List<Transaction>> getTransactions() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
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
  }
}
