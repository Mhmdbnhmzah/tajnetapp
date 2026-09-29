import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/deposit_request.dart';
import '../../../core/theme/theme.dart';
import '../../admin/views/admin_dashboard_screen.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../auth/views/login_screen.dart';
import '../../auth/views/status_screen.dart';
import '../viewmodels/store_viewmodel.dart';
import 'buy_cards_screen.dart';
import 'my_account_screen.dart';
import 'my_cards_screen.dart';
import 'recharge_wallet_screen.dart';
import 'user_notifications_screen.dart';

class MainUserDashboard extends StatefulWidget {
  final int initialTab;
  const MainUserDashboard({super.key, this.initialTab = 0});

  @override
  State<MainUserDashboard> createState() => _MainUserDashboardState();
}

class _MainUserDashboardState extends State<MainUserDashboard> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthViewModel, AppUser?>((vm) => vm.appUser);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    final List<Widget> pages = [
      const BuyCardsScreen(),
      const HotspotContainerView(),
      const MyCardsScreen(),
      const MyAccountScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(context, user, authViewModel),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, AppUser? user, AuthViewModel authViewModel) {
    return AppBar(
      backgroundColor: AppTheme.surfaceColor,
      elevation: 0,
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            boxShadow: AppTheme.primaryGlow,
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset('assets/img/logo.jpeg', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(
              Rect.fromLTWH(0, 0, bounds.width, bounds.height),
            ),
            child: const Text(
              'تاج نت',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Colors.white,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Balance Chip
        if (user != null)
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RechargeWalletScreen()),
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentGold.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: AppTheme.accentGold, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    '${user.balance.toStringAsFixed(1)} ريال',
                    style: const TextStyle(
                      color: AppTheme.accentGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // User Notifications Bell Icon with Unread Badge
        if (user != null)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('user_notifications')
                .where('userId', isEqualTo: user.uid)
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.docs.length ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      unreadCount > 0
                          ? Icons.notifications_rounded
                          : Icons.notifications_none_rounded,
                      color: unreadCount > 0
                          ? AppTheme.primaryColor
                          : AppTheme.primaryColor,
                      size: 24,
                    ),
                    tooltip: 'الإشعارات والتنويهات',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UserNotificationsScreen()),
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: IgnorePointer(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.surfaceColor, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.errorColor.withValues(alpha: 0.5),
                                blurRadius: 6,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

        // Admin Icon
        if (authViewModel.isAdmin)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  color: AppTheme.primaryColor, size: 18),
            ),
            tooltip: 'لوحة الإدارة',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
            ),
          ),

        // Profile menu
        PopupMenuButton<String>(
          icon: Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            alignment: Alignment.center,
            child: Text(
              user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          color: AppTheme.surfaceColorElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
          ),
          onSelected: (val) async {
            if (val == 'logout') await authViewModel.signOutAccount();
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor)),
                  const SizedBox(height: 2),
                  Text(user?.email ?? '',
                      style: const TextStyle(fontSize: 12, color: AppTheme.subtitleColor)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: AppTheme.errorColor, size: 18),
                  SizedBox(width: 10),
                  Text('تسجيل الخروج',
                      style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBottomNav() {
    const items = [
      {'icon': Icons.storefront_outlined, 'activeIcon': Icons.storefront_rounded, 'label': 'المتجر'},
      {'icon': Icons.wifi_outlined, 'activeIcon': Icons.wifi_rounded, 'label': 'الشبكة'},
      {'icon': Icons.credit_card_outlined, 'activeIcon': Icons.credit_card, 'label': 'كروتي'},
      {'icon': Icons.person_outline_rounded, 'activeIcon': Icons.person_rounded, 'label': 'حسابي'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = _currentIndex == i;
              return GestureDetector(
                onTap: () {
                  setState(() => _currentIndex = i);
                  if (i == 1) {
                    Provider.of<AuthViewModel>(context, listen: false)
                        .checkStatus(isPolling: true);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isActive ? AppTheme.primaryGlow : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? item['activeIcon'] as IconData : item['icon'] as IconData,
                        color: isActive ? AppTheme.primaryColor : AppTheme.subtitleColor,
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: isActive ? AppTheme.primaryColor : AppTheme.subtitleColor,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Hotspot Container Widget
class HotspotContainerView extends StatelessWidget {
  const HotspotContainerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        if (authViewModel.isLoggedIn) {
          return const StatusScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

/// My Deposit Requests View
class MyDepositRequestsView extends StatefulWidget {
  const MyDepositRequestsView({super.key});

  @override
  State<MyDepositRequestsView> createState() => _MyDepositRequestsViewState();
}

class _MyDepositRequestsViewState extends State<MyDepositRequestsView> {
  Stream<List<DepositRequest>>? _requestsStream;
  List<DepositRequest>? _cachedRequests;
  String? _currentUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthViewModel>().appUser?.uid ?? '';
    if (userId != _currentUserId) {
      _currentUserId = userId;
      if (userId.isNotEmpty) {
        final storeVm = Provider.of<StoreViewModel>(context, listen: false);
        _requestsStream = storeVm.getUserDepositRequests(userId);
      } else {
        _requestsStream = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'سجل الطلبات',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RechargeWalletScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Color(0x3300C6FF), blurRadius: 10, spreadRadius: 0)
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add_circle_outline, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('شحن جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // List
            Expanded(
              child: _requestsStream == null
                  ? _buildEmpty(context)
                  : StreamBuilder<List<DepositRequest>>(
                      stream: _requestsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          _cachedRequests = snapshot.data;
                        }

                        if (_cachedRequests == null &&
                            snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryColor),
                          );
                        }

                        final requests = _cachedRequests ?? [];

                        if (requests.isEmpty) {
                          return _buildEmpty(context);
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            return _buildRequestCard(requests[index]);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 36, color: AppTheme.subtitleColor),
            ),
            const SizedBox(height: 20),
            const Text(
              'لا توجد طلبات شحن',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
            ),
            const SizedBox(height: 8),
            const Text(
              'اشحن محفظتك الآن لتتمكن من شراء كروت الإنترنت',
              style: TextStyle(color: AppTheme.subtitleColor, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RechargeWalletScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Color(0x3300C6FF), blurRadius: 10, spreadRadius: 0)
                  ],
                ),
                child: const Text(
                  'شحن المحفظة الآن',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(dynamic req) {
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
      statusColor = AppTheme.warningColor;
      statusText = 'قيد المراجعة';
      statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${req.amount} ريال',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textColor),
              ),
              AppStatusBadge(label: statusText, color: statusColor, icon: statusIcon),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.account_balance_outlined, size: 14, color: AppTheme.subtitleColor),
              const SizedBox(width: 6),
              Text(
                'طلب شحن رصيد عبر واتساب',
                style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.subtitleColor),
              const SizedBox(width: 6),
              Text(
                '${req.createdAt.day}/${req.createdAt.month}/${req.createdAt.year}  ${req.createdAt.hour}:${req.createdAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 12),
              ),
            ],
          ),
          if (req.adminNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ملاحظة: ${req.adminNote}',
                      style: TextStyle(color: statusColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
