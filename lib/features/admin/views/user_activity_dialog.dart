import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/card_item.dart';
import '../../../core/models/deposit_request.dart';
import '../../../core/theme/theme.dart';
import '../../store/viewmodels/store_viewmodel.dart';

class UserActivityDialog extends StatelessWidget {
  final AppUser user;
  const UserActivityDialog({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final storeViewModel = Provider.of<StoreViewModel>(context, listen: false);

    return DefaultTabController(
      length: 2,
      child: Dialog(
        backgroundColor: AppTheme.backgroundColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            children: [
              // Header User Profile Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppTheme.secondaryBackgroundColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: user.isBlocked ? AppTheme.errorColor : AppTheme.primaryColor,
                      radius: 22,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0] : 'U',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                          ),
                          Text(
                            '${user.email} | ${user.phone}',
                            style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.accentGold),
                      ),
                      child: Text(
                        '${user.balance.toStringAsFixed(1)} ريال',
                        style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                color: AppTheme.secondaryBackgroundColor,
                child: const TabBar(
                  indicatorColor: AppTheme.primaryColor,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.subtitleColor,
                  tabs: [
                    Tab(icon: Icon(Icons.style, size: 20), text: 'الكروت المشترات'),
                    Tab(icon: Icon(Icons.receipt_long, size: 20), text: 'طلبات وحوالات الشحن'),
                  ],
                ),
              ),

              // Tab Bar View
              Expanded(
                child: TabBarView(
                  children: [
                    // TAB 1: Purchased Cards History
                    Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: StreamBuilder<List<CardItem>>(
                        stream: storeViewModel.getUserPurchasedCards(user.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final cards = snapshot.data ?? [];
                          if (cards.isEmpty) {
                            return const Center(
                              child: Text('لم يقم العميل بشراء أي كروت حتى الآن.', style: TextStyle(color: AppTheme.subtitleColor)),
                            );
                          }

                          return ListView.builder(
                            itemCount: cards.length,
                            itemBuilder: (context, index) {
                              final card = cards[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryBackgroundColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('كارت فئة ${card.profilePrice}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                        Text('${card.priceValue} ريال', style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    SelectableText('رمز (PIN): ${card.pin}', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
                                    if (card.serialNumber.isNotEmpty)
                                      Text('الرقم التسلسلي: ${card.serialNumber}', style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 11)),
                                    if (card.soldAt != null)
                                      Text(
                                        'التاريخ: ${card.soldAt!.day}/${card.soldAt!.month}/${card.soldAt!.year} - ${card.soldAt!.hour}:${card.soldAt!.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 11),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // TAB 2: Deposit Requests History
                    Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: StreamBuilder<List<DepositRequest>>(
                        stream: storeViewModel.getUserDepositRequests(user.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final requests = snapshot.data ?? [];
                          if (requests.isEmpty) {
                            return const Center(
                              child: Text('لا توجد طلبات إيداع سابقة لهذا العميل.', style: TextStyle(color: AppTheme.subtitleColor)),
                            );
                          }

                          return ListView.builder(
                            itemCount: requests.length,
                            itemBuilder: (context, index) {
                              final req = requests[index];
                              Color statusColor = Colors.orange;
                              String statusText = 'قيد المراجعة';
                              if (req.isApproved) {
                                statusColor = AppTheme.primaryColor;
                                statusText = 'مقبول وتم الشحن';
                              } else if (req.isRejected) {
                                statusColor = AppTheme.errorColor;
                                statusText = 'مرفوض';
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryBackgroundColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.31)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('مبلغ ${req.amount} ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor, fontSize: 15)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: statusColor),
                                          ),
                                          child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('طلب شحن رصيد عبر واتساب', style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
                                    Text(
                                      'التاريخ: ${req.createdAt.day}/${req.createdAt.month}/${req.createdAt.year} - ${req.createdAt.hour}:${req.createdAt.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 11),
                                    ),
                                    if (req.adminNote.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text('ملاحظة: ${req.adminNote}', style: TextStyle(color: statusColor, fontSize: 12)),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Close Button
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 42)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق التفاصيل'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
