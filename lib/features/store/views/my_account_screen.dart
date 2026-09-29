import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/deposit_request.dart';
import '../../../core/theme/theme.dart';
import '../../admin/views/admin_dashboard_screen.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/store_viewmodel.dart';
import 'account_details_screen.dart';
import 'recharge_wallet_screen.dart';
import 'transfer_balance_screen.dart';
import 'wallet_pin_dialog.dart';

class MyAccountScreen extends StatelessWidget {
  const MyAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthViewModel, AppUser?>((vm) => vm.appUser);
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: TajNetBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user != null) _buildProfileHeaderCard(context, user),
                const SizedBox(height: 24),

                const SectionHeader(title: 'الخدمات والعمليات السريعة'),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        context,
                        icon: Icons.swap_horiz_rounded,
                        title: 'تحويل رصيد',
                        color: AppTheme.primaryColor,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferBalanceScreen())),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        icon: Icons.add_card_rounded,
                        title: 'شحن المحفظة',
                        color: AppTheme.accentGold,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RechargeWalletScreen())),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        context,
                        icon: Icons.person_pin_rounded,
                        title: 'معلومات الحساب',
                        color: AppTheme.primaryColor,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountDetailsScreen())),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        icon: Icons.shield_rounded,
                        title: 'رمز حماية المحفظة',
                        color: AppTheme.accentGold,
                        onTap: () => WalletPinDialog.show(context, isVerification: false),
                      ),
                    ),
                  ],
                ),
                if (user?.isAdmin == true) ...[
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'لوحة الإدارة',
                    color: AppTheme.accentPurple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
                  ),
                ],

                const SizedBox(height: 20),
                _buildNotificationToggleCard(context, authViewModel),

                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SectionHeader(title: 'سجل الطلبات والحوالات'),
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RechargeWalletScreen())),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.add_rounded, size: 16, color: AppTheme.primaryColor),
                            const SizedBox(width: 4),
                            const Text('طلب جديد', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDepositRequestsList(context, user?.uid ?? ''),

                const SizedBox(height: 24),
                const NeonDivider(),
                const SizedBox(height: 24),

                AppCard(
                  onTap: () async => await authViewModel.signOutAccount(),
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.errorColor.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: AppTheme.errorColor, size: 20),
                        SizedBox(width: 8),
                        Text('تسجيل الخروج', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard(BuildContext context, AppUser user) {
    return AppCard(
      gradient: AppTheme.primaryGradient,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
                  ],
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0] : '👤',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'حساب: ${user.accountNumber}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: AppTheme.accentGold, size: 28),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الرصيد المتاح', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${user.balance.toStringAsFixed(1)} ريال',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.accentGold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return AppCard(
      onTap: onTap,
      color: AppTheme.surfaceColorElevated,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 1),
              ],
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDepositRequestsList(BuildContext context, String userId) {
    return _UserDepositRequestsList(userId: userId);
  }

  Widget _buildNotificationToggleCard(BuildContext context, AuthViewModel authViewModel) {
    final bool isEnabled = authViewModel.notificationsEnabled;

    return AppCard(
      onTap: () async {
        final newValue = !isEnabled;
        await authViewModel.toggleNotifications(newValue);
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newValue
                    ? '🔔 تم تفعيل إشعارات وتنبيهات التطبيق بنجاح'
                    : '🔕 تم إيقاف وتعطيل إشعارات التطبيق',
              ),
              backgroundColor: newValue ? AppTheme.successColor : AppTheme.warningColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppTheme.primaryColor.withValues(alpha: 0.15)
                  : AppTheme.surfaceColorElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isEnabled
                    ? AppTheme.primaryColor.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.25),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: Icon(
              isEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              color: isEnabled ? AppTheme.primaryColor : AppTheme.subtitleColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'إشعارات التطبيق',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? AppTheme.successColor.withValues(alpha: 0.15)
                            : AppTheme.errorColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isEnabled
                              ? AppTheme.successColor.withValues(alpha: 0.4)
                              : AppTheme.errorColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        isEnabled ? 'مفعلة' : 'معطلة',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isEnabled ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isEnabled
                      ? 'تنبيهات فورية عند وصول الحوالات والشحن وعروض الباقات'
                      : 'تم كتم وإيقاف وصول الإشعارات الفورية',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.subtitleColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: isEnabled,
            activeThumbColor: AppTheme.primaryColor,
            activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.35),
            inactiveThumbColor: AppTheme.subtitleColor,
            inactiveTrackColor: AppTheme.surfaceColorElevated,
            onChanged: (val) async {
              await authViewModel.toggleNotifications(val);
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      val
                          ? '🔔 تم تفعيل إشعارات وتنبيهات التطبيق بنجاح'
                          : '🔕 تم إيقاف وتعطيل إشعارات التطبيق',
                    ),
                    backgroundColor: val ? AppTheme.successColor : AppTheme.warningColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _UserDepositRequestsList extends StatefulWidget {
  final String userId;
  const _UserDepositRequestsList({required this.userId});

  @override
  State<_UserDepositRequestsList> createState() => _UserDepositRequestsListState();
}

class _UserDepositRequestsListState extends State<_UserDepositRequestsList> {
  Stream<List<DepositRequest>>? _requestsStream;
  List<DepositRequest>? _cachedRequests;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(covariant _UserDepositRequestsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _initStream();
    }
  }

  void _initStream() {
    if (widget.userId.isNotEmpty) {
      final storeVm = Provider.of<StoreViewModel>(context, listen: false);
      _requestsStream = storeVm.getUserDepositRequests(widget.userId);
    } else {
      _requestsStream = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_requestsStream == null) {
      return const AppCard(
        color: AppTheme.surfaceColor,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('لا توجد طلبات شحن سابقة', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 13)),
          ),
        ),
      );
    }

    return StreamBuilder<List<DepositRequest>>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _cachedRequests = snapshot.data;
        }

        if (_cachedRequests == null && snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }

        final requests = _cachedRequests ?? [];

        if (requests.isEmpty) {
          return const AppCard(
            color: AppTheme.surfaceColor,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('لا توجد طلبات شحن سابقة', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 13)),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: requests.length > 5 ? 5 : requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            Color statusColor;
            String statusText;
            IconData statusIcon;

            if (req.isApproved) {
              statusColor = AppTheme.successColor;
              statusText = 'تم الشحن';
              statusIcon = Icons.check_circle_rounded;
            } else if (req.isRejected) {
              statusColor = AppTheme.errorColor;
              statusText = 'مرفوض';
              statusIcon = Icons.cancel_rounded;
            } else {
              statusColor = AppTheme.primaryColor;
              statusText = 'قيد المراجعة';
              statusIcon = Icons.hourglass_top_rounded;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                color: AppTheme.surfaceColorElevated,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(color: statusColor.withValues(alpha: 0.2), blurRadius: 8),
                        ],
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'شحن رصيد • ${req.amount} ريال',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textColor),
                          ),
                          const SizedBox(height: 4),
                          Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
