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
          _balance = balanceResult['balance'];
          _currency = balanceResult['currency'] ?? 'PKR';
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
            child: RefreshIndicator(
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

  /// Bento grid matching wireframe: large spending insights card + 2 smaller cards
  Widget _buildBentoGrid() {
    return Column(
      children: [
        // ── Large Spending Insights Card ──
        BentoCard(
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
                "You've spent 12% less than last month. Keep it up for your savings goal.",
                style: AppTypography.bodyMedium
                    .copyWith(color: Colors.indigo.shade300),
              ),
              const SizedBox(height: 28),
              // Bar chart
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final heights = [0.4, 0.6, 1.0, 0.75, 0.55, 0.45, 0.85];
                    bool isHighlight = index == 2;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 120 * heights[index],
                        decoration: BoxDecoration(
                          color: isHighlight
                              ? AppColors.primary
                              : AppColors.primaryContainer,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          boxShadow: isHighlight
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withOpacity(0.2),
                                    blurRadius: 20,
                                  )
                                ]
                              : null,
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

        // ── Two smaller cards ──
        Row(
          children: [
            // Smart Assistant card
            Expanded(
              child: BentoCard(
                padding: const EdgeInsets.all(24),
                borderRadius: 32,
                color: AppColors.surfaceContainer,
                glassBorder: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SMART ASSISTANT',
                                style:
                                    AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  letterSpacing: 3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'October\nSummary',
                                style: AppTypography.headlineMedium
                                    .copyWith(
                                        fontSize: 18, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryContainer,
                          ),
                          child: const Icon(Icons.graphic_eq,
                              color: AppColors.primary, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Generate Voice Report',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward,
                            size: 14, color: AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // AI Ready mic card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Gradient ring mic icon
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                      ),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Icon(Icons.mic,
                            color: AppColors.primary, size: 28),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ask "How much for coffee?"',
                      style: AppTypography.headlineSmall
                          .copyWith(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI READY',
                      style: AppTypography.caption.copyWith(
                        color: Colors.indigo.shade300,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
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
}
