import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/models/card_item.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/theme/theme.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/store_viewmodel.dart';

class MyCardsScreen extends StatefulWidget {
  const MyCardsScreen({super.key});

  @override
  State<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends State<MyCardsScreen> {
  List<CardItem> _cachedCards = [];

  @override
  void initState() {
    super.initState();
    _loadOfflineCachedCards();
  }

  void _loadOfflineCachedCards() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final userId = authViewModel.appUser?.uid ?? '';
    if (userId.isNotEmpty) {
      final list = await OfflineCacheService.getCachedUserCards(userId);
      if (mounted) {
        setState(() {
          _cachedCards = list;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.selectionClick();
    _loadOfflineCachedCards();
    await Provider.of<AuthViewModel>(context, listen: false).refreshUserProfile();
    if (mounted) {
      setState(() {});
    }
  }

  void _copyCardPin(BuildContext context, CardItem card) {
    Clipboard.setData(ClipboardData(text: card.pin));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A), // Dark slate luxury navy
        elevation: 10,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppTheme.primaryColor.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.successColor.withValues(alpha: 0.6),
                ),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.successColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تم نسخ رمز الكرت بنجاح! 📋',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'الرمز: ${card.pin}',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8), // Bright Sky Blue
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final storeViewModel = Provider.of<StoreViewModel>(context, listen: false);
    final userId = authViewModel.appUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: const TajNetAppBar(title: 'كروتي'),
      body: TajNetBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'كروت الإنترنت المشتراة',
                            style: TextStyle(color: AppTheme.subtitleColor, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.credit_card_rounded, color: AppTheme.primaryColor, size: 22),
                    ),
                  ],
                ),
              ),

              // Cards List / Offline Stream Builder
              Expanded(
                child: StreamBuilder<List<CardItem>>(
                  stream: storeViewModel.getUserPurchasedCards(userId),
                  builder: (context, snapshot) {
                    // When live data is received, update cache and state
                    if (snapshot.hasData && snapshot.data != null) {
                      final liveCards = snapshot.data!;
                      if (liveCards.isNotEmpty) {
                        OfflineCacheService.cacheUserCards(userId, liveCards);
                      }
                      if (liveCards.isEmpty) {
                        return _buildEmpty(context);
                      }
                      return _buildCardsListView(context, liveCards, isOffline: false);
                    }

                    // If error or offline connection timeout, fallback to cached cards
                    if (snapshot.hasError || snapshot.connectionState == ConnectionState.none) {
                      if (_cachedCards.isNotEmpty) {
                        return _buildCardsListView(context, _cachedCards, isOffline: true);
                      }
                      return _buildEmpty(context, isOffline: true);
                    }

                    // Loading State with cached fallback
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      if (_cachedCards.isNotEmpty) {
                        return _buildCardsListView(context, _cachedCards, isOffline: false);
                      }
                      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                    }

                    if (_cachedCards.isNotEmpty) {
                      return _buildCardsListView(context, _cachedCards, isOffline: true);
                    }

                    return _buildEmpty(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardsListView(BuildContext context, List<CardItem> cards, {required bool isOffline}) {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      backgroundColor: AppTheme.surfaceColor,
      onRefresh: _handleRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: cards.length + (isOffline ? 1 : 0),
        itemBuilder: (context, index) {
          if (isOffline && index == 0) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: AppTheme.accentGold, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '📡 أنت تعمل بدون إنترنت (تُعرض كروتك المحفوظة محلياً)',
                      style: TextStyle(color: AppTheme.textColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }
          final cardIndex = isOffline ? index - 1 : index;
          return _buildCardItem(context, cards[cardIndex], cardIndex);
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, {bool isOffline = false}) {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      backgroundColor: AppTheme.surfaceColor,
      onRefresh: _handleRefresh,
      child: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Icon(
                      isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                      size: 44,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isOffline ? 'لا توجد كروت محفوظة محلياً' : 'لا توجد كروت بعد',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isOffline
                        ? 'قم بالاتصال بالشبكة لمرة واحدة لحفظ كروتك تلقائياً.'
                        : 'قم بشراء كارت جديد للبدء باستخدام الإنترنت',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.subtitleColor,
                      fontSize: 13,
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

  Widget _buildCardItem(BuildContext context, CardItem card, int index) {
    final cardGradient = PackageColorHelper.getPalette(
      card.profilePrice,
      customHex: card.colorHex,
      index: index,
    ).gradient;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Card Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(gradient: cardGradient),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wifi_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        card.profilePrice,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${card.priceValue.toStringAsFixed(0)} ريال',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Card PIN Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'رمز الكرت (PIN)',
                    style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: AppTheme.surfaceColorElevated,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _copyCardPin(context, card),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SelectableText(
                              card.pin,
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.copy_rounded,
                                color: AppTheme.primaryColor,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (card.serialNumber.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الرقم التسلسلي:', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
                        Text(card.serialNumber, style: const TextStyle(color: AppTheme.textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
