import 'package:flutter/material.dart';

enum TransactionType { expense, income }

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

  factory Transaction.fromJson(Map<String, dynamic> json, String currentUserId) {
    // Basic logic to determine if it's income or expense based on sender_id
    bool isExpense = json['sender_id'] == currentUserId;
    
    return Transaction(
      id: json['id'].toString(),
      title: json['recipient_name'] ?? 'Transfer',
      date: json['created_at'].toString().split('T')[0], // Simplified date
      amount: double.parse(json['amount'].toString()),
      status: json['status'].toString().toUpperCase(),
      type: isExpense ? TransactionType.expense : TransactionType.income,
      icon: isExpense ? 'call_made' : 'call_received',
    );
  }
}

