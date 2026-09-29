import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/card_item.dart';
import '../../../core/models/deposit_request.dart';
import '../../../core/theme/theme.dart';
import '../viewmodels/admin_viewmodel.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  String _selectedPeriod = 'month'; // 'today', 'week', 'month', 'all'

  bool _isDateInPeriod(DateTime date) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'today':
        return date.year == now.year && date.month == now.month && date.day == now.day;
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return date.isAfter(weekAgo);
      case 'month':
        return date.year == now.year && date.month == now.month;
      case 'all':
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminVm = Provider.of<AdminViewModel>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'التقارير والإحصائيات المالية 📊',
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<CardItem>>(
          stream: adminVm.soldCards,
          builder: (context, soldSnapshot) {
            return StreamBuilder<List<DepositRequest>>(
              stream: adminVm.approvedDeposits,
              builder: (context, depositsSnapshot) {
                if (soldSnapshot.connectionState == ConnectionState.waiting &&
                    depositsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  );
                }

                final allSoldCards = soldSnapshot.data ?? [];
                final allApprovedDeposits = depositsSnapshot.data ?? [];

                // Filter by selected period
                final filteredSoldCards = allSoldCards.where((c) {
                  final dt = c.soldAt ?? c.createdAt;
                  return _isDateInPeriod(dt);
                }).toList();

                final filteredDeposits = allApprovedDeposits.where((d) {
                  final dt = d.processedAt ?? d.createdAt;
                  return _isDateInPeriod(dt);
                }).toList();

                // Calculate Metrics
                final double totalCardRevenue = filteredSoldCards.fold(
                    0.0, (sum, item) => sum + item.priceValue);

                final double totalApprovedDepositsAmount = filteredDeposits.fold(
                    0.0, (sum, item) => sum + item.amount);

                final int totalCardsSoldCount = filteredSoldCards.length;

                // Category breakdown map: profilePrice -> {count, totalAmount}
                final Map<String, Map<String, dynamic>> categoryStats = {};
                for (var card in filteredSoldCards) {
                  final cat = card.profilePrice.trim();
                  if (cat.isEmpty || cat == 'غير محدد') continue;

                  if (!categoryStats.containsKey(cat)) {
                    categoryStats[cat] = {'count': 0, 'total': 0.0};
                  }
                  categoryStats[cat]!['count'] = (categoryStats[cat]!['count'] as int) + 1;
                  categoryStats[cat]!['total'] = (categoryStats[cat]!['total'] as double) + card.priceValue;
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Period Filter Selector
                      _buildPeriodSelector(),
                      const SizedBox(height: 20),

                      // KPI Overview Cards Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildKpiCard(
                              title: 'إجمالي مبيعات الكروت',
                              value: '${totalCardRevenue.toStringAsFixed(1)} ريال',
                              icon: Icons.monetization_on_rounded,
                              color: AppTheme.successColor,
                              subtitle: '$totalCardsSoldCount كرت مباع',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'إجمالي طلبات الشحن',
                              value: '${totalApprovedDepositsAmount.toStringAsFixed(1)} ريال',
                              icon: Icons.account_balance_wallet_rounded,
                              color: AppTheme.accentGold,
                              subtitle: '${filteredDeposits.length} عملية شحن',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildKpiCard(
                              title: 'عدد الكروت المباعة',
                              value: '$totalCardsSoldCount كرت',
                              icon: Icons.credit_card_rounded,
                              color: AppTheme.primaryColor,
                              subtitle: 'مباعة بالكامل',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'مجموع الحركة المالية',
                              value: '${(totalCardRevenue + totalApprovedDepositsAmount).toStringAsFixed(1)} ريال',
                              icon: Icons.insights_rounded,
                              color: AppTheme.accentPurple,
                              subtitle: 'حركة الرصيد المالي',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Package Performance Section
                      const SectionHeader(title: '📊 مبيعات الباقات والإيرادات حسب الفئة'),
                      const SizedBox(height: 14),

                      if (categoryStats.isEmpty)
                        const AppCard(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'لا توجد مبيعات كروت في الفترة المحددة',
                                style: TextStyle(color: AppTheme.subtitleColor, fontSize: 13),
                              ),
                            ),
                          ),
                        )
                      else
                        ...categoryStats.entries.map((entry) {
                          final catName = entry.key;
                          final count = entry.value['count'] as int;
                          final catTotal = entry.value['total'] as double;
                          final percentage = totalCardRevenue > 0
                              ? (catTotal / totalCardRevenue)
                              : 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppCard(
                              color: AppTheme.surfaceColorElevated,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'فئة $catName',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textColor,
                                        ),
                                      ),
                                      Text(
                                        '${catTotal.toStringAsFixed(1)} ريال',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.accentGold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'عدد الكروت المباعة: $count كرت',
                                        style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 12),
                                      ),
                                      Text(
                                        '${(percentage * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: percentage,
                                      minHeight: 8,
                                      backgroundColor: AppTheme.surfaceColor,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 28),

                      // Recent Financial Activity Log
                      const SectionHeader(title: '🧾 سجل العمليات المكتملة حديثاً'),
                      const SizedBox(height: 14),

                      if (filteredSoldCards.isEmpty && filteredDeposits.isEmpty)
                        const AppCard(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('لا توجد عمليات سابقة في هذه الفترة',
                                  style: TextStyle(color: AppTheme.subtitleColor, fontSize: 13)),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: (filteredSoldCards.length + filteredDeposits.length) > 15
                              ? 15
                              : (filteredSoldCards.length + filteredDeposits.length),
                          itemBuilder: (context, index) {
                            if (index < filteredSoldCards.length) {
                              final card = filteredSoldCards[index];
                              return _buildCardSaleTile(card);
                            } else {
                              final depIndex = index - filteredSoldCards.length;
                              final dep = filteredDeposits[depIndex];
                              return _buildDepositTile(dep);
                            }
                          },
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          _buildPeriodTab('اليوم', 'today'),
          _buildPeriodTab('الأسبوع', 'week'),
          _buildPeriodTab('الشهر', 'month'),
          _buildPeriodTab('الكل', 'all'),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppTheme.subtitleColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return AppCard(
      color: AppTheme.surfaceColorElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: AppTheme.textColor.withValues(alpha: 0.7), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildCardSaleTile(CardItem card) {
    final dateStr = card.soldAt != null
        ? '${card.soldAt!.day}/${card.soldAt!.month}/${card.soldAt!.year}'
        : 'اليوم';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        color: AppTheme.surfaceColorElevated,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_bag_rounded, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'شراء كرت فئة ${card.profilePrice}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'العميل: ${card.soldToUserName?.isNotEmpty == true ? card.soldToUserName! : "مستخدم"} • $dateStr',
                    style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '${card.priceValue.toStringAsFixed(1)} ريال',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.successColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepositTile(DepositRequest dep) {
    final dateStr = '${dep.createdAt.day}/${dep.createdAt.month}/${dep.createdAt.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        color: AppTheme.surfaceColorElevated,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.accentGold, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'شحن رصيد مقبول • واتساب',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'العميل: ${dep.userName} • $dateStr',
                    style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '${dep.amount.toStringAsFixed(1)} ريال',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.accentGold),
            ),
          ],
        ),
      ),
    );
  }
}
