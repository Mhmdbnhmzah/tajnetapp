import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/admin_notification.dart';
import '../../../core/theme/theme.dart';
import '../viewmodels/admin_viewmodel.dart';
import 'manage_deposits_screen.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  String _selectedFilter = 'all'; // 'all', 'card_purchase', 'deposit', 'transfer'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AdminViewModel>(context, listen: false).markNotificationsAsRead();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminVm = Provider.of<AdminViewModel>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'إشعارات وتنبيهات الإدارة',
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<List<AdminNotification>>(
        stream: adminVm.adminNotifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final allNotifications = snapshot.data ?? [];

          // Apply Filter
          final filteredList = allNotifications.where((notif) {
            if (_selectedFilter == 'card_purchase' && notif.type != 'card_purchase') {
              return false;
            }
            if (_selectedFilter == 'deposit' &&
                !notif.type.startsWith('deposit')) {
              return false;
            }
            if (_selectedFilter == 'transfer' && notif.type != 'transfer') {
              return false;
            }
            return true;
          }).toList();

          return Column(
            children: [
              // Filter Chips Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppTheme.surfaceColor,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('الكل (${allNotifications.length})', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'مشتريات الكروت 🛒',
                        'card_purchase',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'طلبات الشحن 💳',
                        'deposit',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'الحوالات 💸',
                        'transfer',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Notification Count Subheader
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'عرض ${filteredList.length} إشعار',
                    style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 13),
                  ),
                ),
              ),

              // Notifications List
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_off_rounded,
                                size: 56,
                                color: AppTheme.subtitleColor.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'لا توجد إشعارات حالياً',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.subtitleColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'ستظهر عمليات شراء الكروت وطلبات الشحن والحوالات هنا فور حدوثها',
                                style: TextStyle(fontSize: 13, color: AppTheme.subtitleColor),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final notif = filteredList[index];
                          return _buildNotificationItemCard(context, notif);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColorElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppTheme.subtitleColor,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItemCard(BuildContext context, AdminNotification notif) {
    IconData icon;
    Color iconColor;
    Color bgTint;

    switch (notif.type) {
      case 'card_purchase':
        icon = Icons.shopping_bag_rounded;
        iconColor = AppTheme.primaryColor;
        bgTint = AppTheme.primaryColor.withValues(alpha: 0.1);
        break;
      case 'deposit_new':
        icon = Icons.account_balance_wallet_rounded;
        iconColor = AppTheme.accentGold;
        bgTint = AppTheme.accentGold.withValues(alpha: 0.1);
        break;
      case 'deposit_approved':
        icon = Icons.check_circle_rounded;
        iconColor = AppTheme.successColor;
        bgTint = AppTheme.successColor.withValues(alpha: 0.1);
        break;
      case 'deposit_rejected':
        icon = Icons.cancel_rounded;
        iconColor = AppTheme.errorColor;
        bgTint = AppTheme.errorColor.withValues(alpha: 0.1);
        break;
      case 'transfer':
        icon = Icons.swap_horiz_rounded;
        iconColor = AppTheme.accentPurple;
        bgTint = AppTheme.accentPurple.withValues(alpha: 0.1);
        break;
      default:
        icon = Icons.notifications_rounded;
        iconColor = AppTheme.primaryColor;
        bgTint = AppTheme.primaryColor.withValues(alpha: 0.1);
    }

    final formattedDate =
        '${notif.createdAt.day}/${notif.createdAt.month}/${notif.createdAt.year} - ${_formatTime(notif.createdAt)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        color: AppTheme.surfaceColor,
        onTap: () {
          if (notif.type == 'deposit_new') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageDepositsScreen()),
            );
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (notif.amount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${notif.amount.toStringAsFixed(1)} ريال',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentGold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notif.message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.subtitleColor),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: const TextStyle(fontSize: 11, color: AppTheme.subtitleColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
