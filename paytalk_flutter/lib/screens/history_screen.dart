import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/bento_card.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

/// History Screen — exact replication of account_history_refined_bento wireframe.
/// Header with balance, recent activity list, and dashboard bento grid.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  String _balance = '...';
  String _currency = 'PKR';
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _apiService.addListener(_onGlobalRefresh);
    _fetchData();
  }

  @override
  void dispose() {
    _apiService.removeListener(_onGlobalRefresh);
    _apiService.dispose();
    super.dispose();
  }

  void _onGlobalRefresh() {
    // Only refresh if we aren't currently fetching to avoid loops
    if (!_isFetching) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (_isFetching) return;
    
    setState(() {
      _isFetching = true;
      _isLoading = true;
    });

    try {
      final balanceResult = await _apiService.getBalance();
      final transactionsResult = await _apiService.getTransactions();

      if (mounted) {
        setState(() {
          if (balanceResult.containsKey('balance')) {
            _balance = balanceResult['balance'];
            _currency = balanceResult['currency'] ?? 'PKR';
          }
          _transactions = transactionsResult;
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Ambient blur glow (top right) ──
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
            child: ValueListenableBuilder<int>(
              valueListenable: ApiService.refreshNotifier,
              builder: (context, refreshCount, _) {
                // Trigger fetch if the notifier changes
                // Note: initState/didChangeDependencies already handle initial load
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _fetchData,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ── Sticky Header ──
                      SliverToBoxAdapter(child: _buildHeader()),
                      // ── Content ──
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 24),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const SizedBox(height: 16),
                            _buildSectionTitle('Recent Activity'),
                            const SizedBox(height: 16),
                            _isLoading
                                ? const Center(
                                    child: Padding(
                                    padding: EdgeInsets.all(48),
                                    child: CircularProgressIndicator(
                                        color: AppColors.primary),
                                  ))
                                : _buildTransactionList(),
                            const SizedBox(height: 40),
                            _buildSectionTitle('Dashboard Bento'),
                            const SizedBox(height: 16),
                            _buildBentoGrid(),
                            const SizedBox(height: 40),
                            _buildFooter(),
                            const SizedBox(height: 120),
                          ]),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Header matching wireframe: "Account History" title + balance + notification bell
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        border: Border(
            bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account History',
                    style: AppTypography.displayMedium
                        .copyWith(fontSize: 24)),
                const SizedBox(height: 4),
                Text('Review your recent conduits and ledgers.',
                    style: AppTypography.bodyMedium
                        .copyWith(color: Colors.indigo.shade300)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'AVAILABLE BALANCE',
                style: AppTypography.caption.copyWith(
                  color: Colors.indigo.shade200,
                  fontSize: 8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$_currency $_balance',
                style: AppTypography.headlineLarge.copyWith(
                  color: AppColors.primary,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer,
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.1)),
            ),
            child: const Icon(Icons.notifications,
                color: AppColors.primary, size: 22),
          ),
        ],
      ),
    );
  }

  /// Section title with vertical accent bar
  Widget _buildSectionTitle(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(title,
                style: AppTypography.headlineMedium
                    .copyWith(fontSize: 20)),
          ],
        ),
        if (title == 'Recent Activity')
          Row(
            children: [
              _buildFilterButton(Icons.filter_list),
              const SizedBox(width: 8),
              _buildFilterButton(Icons.calendar_today),
            ],
          ),
      ],
    );
  }

  Widget _buildFilterButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline),
      ),
      child: Icon(icon, size: 16, color: AppColors.primary),
    );
  }

  /// Transaction list items matching wireframe glass-panel style
  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Text(
            'No transaction history found.',
            style: AppTypography.bodyMedium,
          ),
        ),
      );
    }
    return Column(
      children: _transactions.map((tx) => _buildTransactionItem(tx)).toList(),
    );
  }

  Widget _buildTransactionItem(Transaction tx) {
    final isExpense = tx.type == TransactionType.expense;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 24,
        child: Row(
          children: [
            // Icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.1)),
              ),
              child: Icon(
                isExpense ? Icons.shopping_bag : Icons.call_received,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            // Title + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.title,
                      style: AppTypography.headlineSmall
                          .copyWith(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    tx.date,
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.indigo.shade300,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Amount + status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isExpense ? "-" : "+"}${tx.amount.toStringAsFixed(2)}',
                  style: AppTypography.headlineSmall.copyWith(
                    fontSize: 16,
                    color: isExpense
                        ? AppColors.onSurface
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tx.status,
                      style: AppTypography.caption.copyWith(
                        color: Colors.indigo.shade300,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                color: Colors.indigo.shade200, size: 24),
          ],
        ),
      ),
    );
  }

  /// Bento grid: spending insights card with dynamic chart
  Widget _buildBentoGrid() {
    return BentoCard(
      padding: const EdgeInsets.all(28),
      borderRadius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MONTHLY TREND',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text('Spending Insights',
              style: AppTypography.headlineLarge
                  .copyWith(fontSize: 26)),
          const SizedBox(height: 8),
          Text(
            _getInsightText(),
            style: AppTypography.bodyMedium
                .copyWith(color: Colors.indigo.shade300),
          ),
          const SizedBox(height: 28),
          // Dynamic bar chart from actual transactions
          SizedBox(
            height: 140,
            child: _transactions.isEmpty
                ? Center(
                    child: Text('No transactions yet',
                        style: AppTypography.bodySmall
                            .copyWith(color: Colors.indigo.shade300)))
                : _buildDynamicChart(),
          ),
        ],
      ),
    );
  }

  /// Footer matching wireframe
  Widget _buildFooter() {
    return Column(
      children: [
        Container(
            height: 1, color: AppColors.outline),
        const SizedBox(height: 24),
        Text(
          '© 2024 PayTalk Digital Ledger. All rights reserved.',
          style: AppTypography.bodySmall.copyWith(
            color: Colors.indigo.shade200,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterLink('Privacy Protocol'),
            const SizedBox(width: 24),
            _buildFooterLink('Terms of Conduit'),
            const SizedBox(width: 24),
            _buildFooterLink('Contact Intelligence'),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterLink(String text) {
    return Text(
      text,
      style: AppTypography.bodySmall.copyWith(
        color: Colors.indigo.shade200,
        fontSize: 11,
      ),
    );
  }

  String _getInsightText() {
    if (_transactions.isEmpty) return 'No transactions recorded yet.';
    final expenses = _transactions.where((t) => t.type == TransactionType.expense);
    final totalSpent = expenses.fold<double>(0.0, (sum, t) => sum + t.amount);
    final income = _transactions.where((t) => t.type == TransactionType.income);
    final totalReceived = income.fold<double>(0.0, (sum, t) => sum + t.amount);
    return 'Total spent: $_currency ${totalSpent.toStringAsFixed(0)} · Received: $_currency ${totalReceived.toStringAsFixed(0)} across ${_transactions.length} transactions.';
  }

  Widget _buildDynamicChart() {
    final recentTx = _transactions.take(7).toList();
    final maxAmount = recentTx.map((t) => t.amount).reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(recentTx.length, (index) {
        final tx = recentTx[index];
        final normalizedHeight = maxAmount > 0 ? (tx.amount / maxAmount) : 0.5;
        final isMax = tx.amount == maxAmount;
        final isExpense = tx.type == TransactionType.expense;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${(tx.amount / 1000).toStringAsFixed(1)}k',
                  style: AppTypography.caption.copyWith(
                    fontSize: 8,
                    color: isMax ? AppColors.primary : Colors.indigo.shade300,
                    fontWeight: isMax ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 100 * normalizedHeight.clamp(0.08, 1.0),
                  decoration: BoxDecoration(
                    color: isMax
                        ? AppColors.primary
                        : isExpense
                            ? AppColors.primaryContainer
                            : AppColors.primary.withOpacity(0.3),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8)),
                    boxShadow: isMax
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 12,
                            )
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tx.title.length > 5 ? tx.title.substring(0, 5) : tx.title,
                  style: AppTypography.caption.copyWith(
                    fontSize: 7,
                    color: Colors.indigo.shade300,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
