import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/models/admin_notification.dart';
import '../../../core/models/card_item.dart';
import '../../../core/theme/theme.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/admin_viewmodel.dart';
import '../../store/views/main_user_dashboard.dart';
import 'admin_notifications_screen.dart';
import 'manage_bank_accounts_screen.dart';
import 'manage_deposits_screen.dart';
import 'manage_inventory_screen.dart';
import 'manage_packages_screen.dart';
import 'manage_registration_requests_screen.dart';
import 'manage_users_screen.dart';
import 'upload_cards_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_app_version_screen.dart';
import 'admin_send_notification_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DateTime? _lastNavTime;

  /// Prevents double-tap or rapid-tap navigation bugs (Fix M-04)
  void _navigateTo(Widget screen) {
    final now = DateTime.now();
    if (_lastNavTime != null && now.difference(_lastNavTime!) < const Duration(milliseconds: 600)) {
      return; // Ignore rapid consecutive taps
    }
    _lastNavTime = now;
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// Logout confirmation dialog (Fix L-05)
  Future<void> _confirmSignOut(AuthViewModel authViewModel) async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.errorColor, size: 24),
            SizedBox(width: 10),
            Text(
              'تسجيل الخروج',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppTheme.textColor,
              ),
            ),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من لوحة تحكم المسؤول؟',
          style: TextStyle(color: AppTheme.textColor, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.subtitleColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الخروج', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await authViewModel.signOutAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final adminViewModel = Provider.of<AdminViewModel>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    // Admin Profile Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.15),
                            AppTheme.surfaceColor,
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authViewModel.appUser?.name ?? 'المسؤول',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  authViewModel.appUser?.email ?? '',
                                  style: const TextStyle(
                                    color: AppTheme.subtitleColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _confirmSignOut(authViewModel),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                color: AppTheme.errorColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Section title
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'لوحة التحكم',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.subtitleColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // ─── Menu Items ──────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Notifications Menu Item
                  StreamBuilder<List<AdminNotification>>(
                    stream: adminViewModel.adminNotifications,
                    builder: (context, snapshot) {
                      final list = snapshot.data ?? [];
                      final unreadCount = adminViewModel.getUnreadNotificationCount(list);
                      return _buildMenuItem(
                        context,
                        icon: Icons.notifications_active_rounded,
                        label: 'الإشعارات والتنبيهات 🔔',
                        subtitle: 'تنبيهات فورية عند شراء الكروت وشحن الأرصدة والحوالات',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                        ),
                        badgeCount: unreadCount,
                        onTap: () => _navigateTo(const AdminNotificationsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Send Custom Notifications Menu Item
                  _buildMenuItem(
                    context,
                    icon: Icons.send_rounded,
                    label: 'إرسال إشعارات للمستخدمين 📣',
                    subtitle: 'إرسال تنبيهات وتنويهات فورية لجميع العملاء أو لعميل محدد',
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFFFF9800)],
                    ),
                    onTap: () => _navigateTo(const AdminSendNotificationScreen()),
                  ),
                  const SizedBox(height: 12),

                  // Financial Analytics & Reports
                  _buildMenuItem(
                    context,
                    icon: Icons.bar_chart_rounded,
                    label: 'التقارير والإحصائيات المالية 📊',
                    subtitle: 'تحليل المبيعات، إيرادات الباقات، وتتبع حركة الرصيد المالي',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                    ),
                    onTap: () => _navigateTo(const AdminAnalyticsScreen()),
                  ),
                  const SizedBox(height: 12),

                  // Pending Registration Requests (with badge)
                  StreamBuilder(
                    stream: adminViewModel.pendingRegistrationRequests,
                    builder: (context, snapshot) {
                      final pendingCount = (snapshot.data as List?)?.length ?? 0;
                      return _buildMenuItem(
                        context,
                        icon: Icons.how_to_reg_rounded,
                        label: 'طلبات إنشاء الحسابات 👥',
                        subtitle: 'مراجعة وتفعيل الحسابات وإرسال الأكواد للعملاء',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF0072FF)],
                        ),
                        badgeCount: pendingCount,
                        onTap: () => _navigateTo(const ManageRegistrationRequestsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Pending Deposits (with badge)
                  StreamBuilder(
                    stream: adminViewModel.pendingDepositRequests,
                    builder: (context, snapshot) {
                      final pendingCount = (snapshot.data as List?)?.length ?? 0;
                      return _buildMenuItem(
                        context,
                        icon: Icons.payments_rounded,
                        label: 'طلبات الشحن',
                        subtitle: 'مراجعة الحوالات وتأكيد شحن الأرصدة',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C896), Color(0xFF0090FF)],
                        ),
                        badgeCount: pendingCount,
                        onTap: () => _navigateTo(const ManageDepositsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildMenuItem(
                    context,
                    icon: Icons.note_add_rounded,
                    label: 'رفع كروت الشبكة',
                    subtitle: 'إضافة كروت جديدة يدوياً أو من ملفات',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
                    ),
                    onTap: () => _navigateTo(const UploadCardsScreen()),
                  ),
                  const SizedBox(height: 12),

                  // Card Inventory Menu Item
                  StreamBuilder<List<CardItem>>(
                    stream: adminViewModel.allCards,
                    builder: (context, snapshot) {
                      final availableCount = (snapshot.data ?? []).where((c) => c.isAvailable).length;
                      return _buildMenuItem(
                        context,
                        icon: Icons.inventory_2_rounded,
                        label: 'مخزون الكروت المتوفرة',
                        subtitle: 'عرض كميات الكروت المتوفرة والمباعة لكل فئة',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0088FF), Color(0xFF00C6FF)],
                        ),
                        badgeCount: availableCount,
                        onTap: () => _navigateTo(const ManageInventoryScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildMenuItem(
                    context,
                    icon: Icons.wifi_protected_setup_rounded,
                    label: 'إدارة باقات الكروت',
                    subtitle: 'إضافة وتعديل أسعار الكروت وسعتها ديناميكياً',
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFFFF4081)],
                    ),
                    onTap: () => _navigateTo(const ManagePackagesScreen()),
                  ),
                  const SizedBox(height: 12),

                  _buildMenuItem(
                    context,
                    icon: Icons.account_balance_rounded,
                    label: 'الحسابات المصرفية',
                    subtitle: 'إضافة وتحديث حسابات تحويل الأموال',
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
                    ),
                    onTap: () => _navigateTo(const ManageBankAccountsScreen()),
                  ),
                  const SizedBox(height: 12),

                  _buildMenuItem(
                    context,
                    icon: Icons.people_alt_rounded,
                    label: 'إدارة العملاء',
                    subtitle: 'عرض الحسابات وأرصدتها وطلباتها',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00BCD4), Color(0xFF0088CC)],
                    ),
                    onTap: () => _navigateTo(const ManageUsersScreen()),
                  ),
                  const SizedBox(height: 12),

                  _buildMenuItem(
                    context,
                    icon: Icons.system_update_rounded,
                    label: 'إدارة إصدارات التطبيق 🚀',
                    subtitle: 'تحكم في التحديث الإلزامي والاختياري للمستخدمين',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFF00C6FF)],
                    ),
                    onTap: () => _navigateTo(const AdminAppVersionScreen()),
                  ),
                  const SizedBox(height: 12),

                  _buildMenuItem(
                    context,
                    icon: Icons.storefront_rounded,
                    label: 'واجهة المتجر والشبكة',
                    subtitle: 'الانتقال للوحة المستخدم والمتجر والبوابة',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3FB950), Color(0xFF00C896)],
                    ),
                    onTap: () => _navigateTo(const MainUserDashboard()),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required LinearGradient gradient,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppTheme.subtitleColor, size: 22),
          ],
        ),
      ),
    );
  }
}
