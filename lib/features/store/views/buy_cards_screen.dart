import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_user.dart';
import '../../../core/theme/theme.dart';
import '../../../main.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../auth/views/account_auth_screen.dart';
import '../viewmodels/store_viewmodel.dart';
import 'recharge_wallet_screen.dart';
import 'wallet_pin_dialog.dart';

class BuyCardsScreen extends StatefulWidget {
  const BuyCardsScreen({super.key});

  @override
  State<BuyCardsScreen> createState() => _BuyCardsScreenState();
}

class _BuyCardsScreenState extends State<BuyCardsScreen> {
  Timer? _messageDismissTimer;
  Timer? _snackBarTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<StoreViewModel>(context, listen: false).clearMessages();
      }
    });
  }

  @override
  void dispose() {
    _messageDismissTimer?.cancel();
    _snackBarTimer?.cancel();
    super.dispose();
  }



  void _confirmAndBuyCard({
    required String profilePrice,
    required double priceValue,
  }) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final storeViewModel = Provider.of<StoreViewModel>(context, listen: false);

    if (authViewModel.appUser == null) return;
    final userBalance = authViewModel.appUser!.balance;

    if (userBalance < priceValue) {
      _showInsufficientDialog(userBalance, priceValue);
      return;
    }

    _showConfirmDialog(
      profilePrice: profilePrice,
      priceValue: priceValue,
      authViewModel: authViewModel,
      storeViewModel: storeViewModel,
    );
  }

  void _showInsufficientDialog(double balance, double price) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: AppTheme.errorColor),
            SizedBox(width: 10),
            Text('رصيد غير كافٍ', style: TextStyle(color: AppTheme.errorColor)),
          ],
        ),
        content: Text(
          'رصيدك الحالي: $balance ريال\nسعر الكرت: $price ريال\n\nيرجى شحن المحفظة أولاً.',
          style: const TextStyle(color: AppTheme.textColor, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.subtitleColor)),
          ),
          TajNetButton(
            fullWidth: false,
            height: 42,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RechargeWalletScreen()));
            },
            child: const Text('شحن المحفظة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog({
    required String profilePrice,
    required double priceValue,
    required AuthViewModel authViewModel,
    required StoreViewModel storeViewModel,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.shopping_cart_checkout_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 10),
            Text('تأكيد الشراء', style: TextStyle(color: AppTheme.primaryColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppCard(
              color: AppTheme.surfaceColorElevated,
              radius: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الباقة:', style: TextStyle(color: AppTheme.subtitleColor)),
                  Text(profilePrice, style: const TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AppCard(
              color: AppTheme.surfaceColorElevated,
              radius: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('السعر:', style: TextStyle(color: AppTheme.subtitleColor)),
                  Text('$priceValue ريال',
                      style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.subtitleColor)),
          ),
          TajNetButton(
            fullWidth: false,
            height: 42,
            onPressed: () async {
              Navigator.pop(dialogCtx);

              final verified = await WalletPinDialog.show(
                context,
                title: 'رمز حماية المحفظة 🔒',
                subtitle: 'أدخل رمز حماية المحفظة لتأكيد شراء كرت فئة "$profilePrice"',
              );
              if (verified != true || !mounted) return;

              final card = await storeViewModel.buyCard(
                userId: authViewModel.appUser!.uid,
                userName: authViewModel.appUser!.name,
                profilePrice: profilePrice,
                priceValue: priceValue,
              );

              if (!mounted) return;

              if (card != null) {
                _showPurchaseSuccessNotification(
                  profilePrice: profilePrice,
                  priceValue: priceValue,
                  pin: card.pin,
                );
              } else {
                final errStr = storeViewModel.errorMessage ?? 'عفواً، لا توجد كروت متاحة حالياً لـ "$profilePrice"';
                _showErrorDialog(context, errStr, storeViewModel);
              }
            },
            child: const Text('تأكيد الشراء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPurchaseSuccessNotification({
    required String profilePrice,
    required double priceValue,
    required String pin,
  }) {
    HapticFeedback.mediumImpact();

    // Clear any messages in ViewModel so no in-tree banner appears
    _messageDismissTimer?.cancel();
    Provider.of<StoreViewModel>(context, listen: false).clearMessages();

    // Enforce programmatic dismissal of SnackBar after exactly 3.5 seconds
    // (Overrides Android accessibility settings that otherwise prevent SnackBars from auto-hiding)
    _snackBarTimer?.cancel();
    _snackBarTimer = Timer(const Duration(milliseconds: 3500), () {
      try {
        rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
      } catch (_) {}
    });

    // Global Root ScaffoldMessenger SnackBar (Guaranteed to show across MaterialApp)
    try {
      rootScaffoldMessengerKey.currentState?.clearSnackBars();
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تم شراء كرت فئة "$profilePrice" بنجاح! 🎉',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'رمز الكرت: $pin',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00C853),
          behavior: SnackBarBehavior.floating,
          dismissDirection: DismissDirection.down,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(milliseconds: 3500),
          action: SnackBarAction(
            label: 'نسخ',
            textColor: Colors.white,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: pin));
              HapticFeedback.selectionClick();
              try {
                rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
              } catch (_) {}
            },
          ),
        ),
      );
    } catch (_) {}
  }

  void _showErrorDialog(BuildContext context, String errorMessage, StoreViewModel storeViewModel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.4)),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: 24),
            SizedBox(width: 10),
            Text('تعذر شراء الكرت', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          errorMessage,
          style: const TextStyle(color: AppTheme.textColor, height: 1.5, fontSize: 14),
        ),
        actions: [
          TajNetButton(
            fullWidth: false,
            height: 40,
            onPressed: () {
              storeViewModel.clearMessages();
              Navigator.pop(ctx);
            },
            child: const Text('حسناً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((_) {
      storeViewModel.clearMessages();
    });
  }


  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthViewModel, AppUser?>((vm) => vm.appUser);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final storeViewModel = Provider.of<StoreViewModel>(context);

    if (user == null) {
      return _buildNotLoggedIn(context);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const TajNetAppBar(title: 'شراء كروت الانترنت'),
      body: TajNetBackground(
        child: SafeArea(
          child: RefreshIndicator(
                color: AppTheme.primaryColor,
                backgroundColor: AppTheme.surfaceColor,
                onRefresh: () async {
                  HapticFeedback.selectionClick();
                  await Future.wait([
                    Provider.of<AuthViewModel>(context, listen: false).refreshUserProfile(),
                    Provider.of<AuthViewModel>(context, listen: false).checkStatus(isPolling: false),
                  ]);
                },
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Balance Card
                            _buildBalanceCard(context, user),
                            const SizedBox(height: 20),
                            // Error Banner with dismiss button
                            if (storeViewModel.errorMessage != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(storeViewModel.errorMessage!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13))),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, color: AppTheme.errorColor, size: 18),
                                      onPressed: () => storeViewModel.clearMessages(),
                                    ),
                                  ],
                                ),
                              ),

                            const SectionHeader(title: 'الباقات المتاحة'),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),

                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: storeViewModel.activePackages,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: CircularProgressIndicator(color: AppTheme.primaryColor),
                              ),
                            ),
                          );
                        }

                        final packages = snapshot.data ?? [];
                        if (packages.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.wifi_off_rounded, size: 64, color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'لا توجد باقات متاحة حالياً',
                                      style: TextStyle(color: AppTheme.subtitleColor, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final profile = packages[index];
                                final priceStr = profile['priceText'] ?? '';
                                final priceVal = double.tryParse(profile['priceValue']?.toString() ?? '') ?? 0.0;
                                return _buildCardTile(
                                  context,
                                  index: index,
                                  profile: profile,
                                  priceStr: priceStr,
                                  priceVal: priceVal,
                                  authViewModel: authViewModel,
                                  storeViewModel: storeViewModel,
                                );
                              },
                              childCount: packages.length,
                            ),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.64,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }

  Widget _buildBalanceCard(BuildContext context, AppUser user) {
    return AppCard(
      color: AppTheme.surfaceColorElevated,
      borderColor: AppTheme.accentGold.withValues(alpha: 0.3),
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مرحباً، ${user.name} 👋',
                    style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        user.balance.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentGold,
                          height: 1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4, right: 6),
                        child: Text('ريال',
                            style: TextStyle(color: AppTheme.accentGold, fontSize: 15)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('رصيد المحفظة', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
                ],
              ),
            ),
            TajNetButton(
              fullWidth: false,
              height: 44,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RechargeWalletScreen()),
              ),
              gradientColors: const [AppTheme.accentGold, Color(0xFFFF8F00)],
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text('شحن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTile(
    BuildContext context, {
    required int index,
    required Map<String, dynamic> profile,
    required String priceStr,
    required double priceVal,
    required AuthViewModel authViewModel,
    required StoreViewModel storeViewModel,
  }) {
    final palette = PackageColorHelper.getPalette(
      priceStr,
      customHex: profile['colorHex'],
      index: index,
    );
    final cardGradientColors = palette.gradientColors;
    final cardGradient = palette.gradient;

    return AppCard(
      color: AppTheme.surfaceColor,
      borderColor: palette.accentColor.withValues(alpha: 0.35),
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon header
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: cardGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: palette.accentColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const Icon(Icons.wifi_rounded, color: Colors.white, size: 22),
            ),
            const Spacer(),

            // Price prominently gold
            Text(
              priceStr,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 2),

            // Details
            Text(
              profile['transfer'] ?? '',
              style: const TextStyle(color: AppTheme.textColor, fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              profile['validity'] ?? '',
              style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Buy Button
            SizedBox(
              width: double.infinity,
              height: 38,
              child: TajNetButton(
                onPressed: storeViewModel.isLoading
                    ? null
                    : () => _confirmAndBuyCard(
                          profilePrice: priceStr,
                          priceValue: priceVal,
                        ),
                isLoading: storeViewModel.isLoading,
                gradientColors: cardGradientColors,
                child: const Text(
                  'شراء الآن',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotLoggedIn(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const TajNetAppBar(title: 'شراء كروت الانترنت'),
      body: TajNetBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColorElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                    boxShadow: AppTheme.primaryGlow,
                  ),
                  child: const Icon(Icons.lock_outline_rounded, size: 42, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 24),
                const Text(
                  'يلزم تسجيل الدخول',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                ),
                const SizedBox(height: 10),
                const Text(
                  'سجّل دخولك بحسابك لاستخدام المتجر وشراء كروت الإنترنت',
                  style: TextStyle(color: AppTheme.subtitleColor, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 200,
                  child: TajNetButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AccountAuthScreen()),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('تسجيل الدخول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

