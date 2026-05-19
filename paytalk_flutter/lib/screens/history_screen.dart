import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/bento_card.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  String _balance = '...';
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final balanceResult = await _apiService.getBalance();
    final transactionsResult = await _apiService.getTransactions();

    if (mounted) {
      setState(() {
        if (balanceResult.containsKey('balance')) {
          _balance = '${balanceResult['currency']} ${balanceResult['balance']}';
        }
        _transactions = transactionsResult;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.03),
              ),
            ),
          ),
          
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 48),
                    _buildSectionTitle('Recent Activity'),
                    const SizedBox(height: 24),
                    _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : _buildTransactionList(),
                    const SizedBox(height: 48),
                    _buildSectionTitle('Dashboard Bento'),
                    const SizedBox(height: 24),
                    _buildBentoGrid(context),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Account History', style: AppTypography.displayLarge.copyWith(fontSize: 28)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('AVAILABLE BALANCE', style: AppTypography.labelSmall.copyWith(fontSize: 8, color: Colors.indigo.shade200)),
                Text(_balance, style: AppTypography.headlineLarge.copyWith(color: AppColors.primary, fontSize: 22)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Review your recent conduits and ledgers.', style: AppTypography.bodyMedium),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Text(title, style: AppTypography.headlineMedium),
      ],
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return const Center(child: Text('No transaction history found.'));
    }
    return Column(
      children: _transactions.map((tx) => _buildTransactionItem(tx)).toList(),
    );
  }

  Widget _buildTransactionItem(Transaction tx) {
    final isExpense = tx.type == TransactionType.expense;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: BentoCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 24,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isExpense ? Icons.call_made : Icons.call_received, 
                color: AppColors.primary, 
                size: 24
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.title, style: AppTypography.headlineMedium.copyWith(fontSize: 16)),
                  Text(tx.date, style: AppTypography.bodySmall.copyWith(color: Colors.indigo.shade300)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isExpense ? '-' : '+'}${tx.amount.toStringAsFixed(2)}',
                  style: AppTypography.headlineMedium.copyWith(
                    fontSize: 16,
                    color: isExpense ? AppColors.onSurface : AppColors.primary,
                  ),
                ),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(tx.status, style: AppTypography.labelSmall.copyWith(fontSize: 8)),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFFE2E8F0), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoGrid(BuildContext context) {
    return Column(
      children: [
        BentoCard(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MONTHLY TREND', style: AppTypography.labelSmall.copyWith(color: AppColors.primary)),
              const SizedBox(height: 8),
              Text('Spending Insights', style: AppTypography.headlineMedium.copyWith(fontSize: 24)),
              const SizedBox(height: 8),
              Text('You\'ve spent 12% less than last month.', style: AppTypography.bodyMedium),
              const SizedBox(height: 32),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    double height = [0.4, 0.6, 1.0, 0.75, 0.55, 0.45, 0.85][index];
                    bool isFull = index == 2;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 120 * height,
                        decoration: BoxDecoration(
                          color: isFull ? AppColors.primary : AppColors.primaryContainer,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          boxShadow: isFull ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 10)] : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: BentoCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.graphic_eq, color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text('October Summary', style: AppTypography.headlineMedium.copyWith(fontSize: 16)),
                    TextButton(
                      onPressed: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Generate Report', style: AppTypography.labelSmall.copyWith(color: AppColors.primary)),
                          const Icon(Icons.arrow_forward, size: 12, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.mic, color: AppColors.primary, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text('Ask AI', style: AppTypography.headlineMedium.copyWith(fontSize: 14)),
                    Text('AI READY', style: AppTypography.labelSmall.copyWith(fontSize: 8)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

