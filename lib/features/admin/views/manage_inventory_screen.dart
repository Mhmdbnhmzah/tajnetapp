import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/models/card_item.dart';
import '../../../core/theme/theme.dart';
import '../viewmodels/admin_viewmodel.dart';
import 'upload_cards_screen.dart';

class ManageInventoryScreen extends StatefulWidget {
  const ManageInventoryScreen({super.key});

  @override
  State<ManageInventoryScreen> createState() => _ManageInventoryScreenState();
}

class _ManageInventoryScreenState extends State<ManageInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _filterStatus = 'all'; // 'all', 'available', 'sold'
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
          'مخزون الكروت',
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded, color: AppTheme.primaryColor, size: 20),
            ),
            tooltip: 'رفع كروت جديدة',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadCardsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.subtitleColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Tajawal'),
          tabs: const [
            Tab(text: 'المخزون حسب الفئات'),
            Tab(text: 'تفاصيل الكروت'),
          ],
        ),
      ),
      body: StreamBuilder<List<CardItem>>(
        stream: adminVm.allCards,
        builder: (context, cardsSnapshot) {
          if (cardsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final allCards = cardsSnapshot.data ?? [];
          final availableCardsCount = allCards.where((c) => c.isAvailable).length;
          final soldCardsCount = allCards.where((c) => !c.isAvailable).length;

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: adminVm.allPackages,
            builder: (context, packagesSnapshot) {
              final packages = packagesSnapshot.data ?? [];

              return TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Category Summary
                  _buildCategorySummaryTab(
                    context,
                    adminVm: adminVm,
                    allCards: allCards,
                    packages: packages,
                    totalAvailable: availableCardsCount,
                    totalSold: soldCardsCount,
                  ),

                  // Tab 2: Detailed Cards List
                  _buildDetailedCardsTab(
                    context,
                    adminVm: adminVm,
                    allCards: allCards,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ─── TAB 1: CATEGORY SUMMARY ───────────────────────────────────────────────
  Widget _buildCategorySummaryTab(
    BuildContext context, {
    required AdminViewModel adminVm,
    required List<CardItem> allCards,
    required List<Map<String, dynamic>> packages,
    required int totalAvailable,
    required int totalSold,
  }) {
    // Build category map combining packages and uploaded card profiles
    final Map<String, Map<String, dynamic>> categoryStats = {};

    // 1. First populate from active packages
    for (var pkg in packages) {
      final String profileName = (pkg['priceText'] ?? pkg['profilePrice'] ?? pkg['name'] ?? '').toString().trim();
      if (profileName.isEmpty || profileName == 'غير محدد') continue;

      final double priceValue = (pkg['priceValue'] as num?)?.toDouble() ?? 0.0;
      categoryStats[profileName] = {
        'profileName': profileName,
        'priceValue': priceValue,
        'availableCount': 0,
        'soldCount': 0,
        'totalCount': 0,
        'hasDefinedPackage': true,
      };
    }

    // 2. Count cards for each profile
    for (var card in allCards) {
      final String profileName = card.profilePrice.trim();
      if (profileName.isEmpty || profileName == 'غير محدد') continue;

      if (!categoryStats.containsKey(profileName)) {
        categoryStats[profileName] = {
          'profileName': profileName,
          'priceValue': card.priceValue,
          'availableCount': 0,
          'soldCount': 0,
          'totalCount': 0,
          'hasDefinedPackage': false,
        };
      }

      categoryStats[profileName]!['totalCount'] = (categoryStats[profileName]!['totalCount'] as int) + 1;
      if (card.isAvailable) {
        categoryStats[profileName]!['availableCount'] = (categoryStats[profileName]!['availableCount'] as int) + 1;
      } else {
        categoryStats[profileName]!['soldCount'] = (categoryStats[profileName]!['soldCount'] as int) + 1;
      }
    }

    final categoryList = categoryStats.values.toList();
    categoryList.sort((a, b) => (a['priceValue'] as double).compareTo(b['priceValue'] as double));

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      backgroundColor: AppTheme.surfaceColor,
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 400));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Global Overview Header Cards
          _buildOverviewCards(totalAvailable, totalSold, allCards.length),

          const SizedBox(height: 24),
          const SectionHeader(title: 'كميات الكروت المتوفرة لكل فئة'),
          const SizedBox(height: 14),

          if (categoryList.isEmpty)
            const AppCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'لا توجد فئات أو كروت في المخزون حالياً',
                    style: TextStyle(color: AppTheme.subtitleColor),
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categoryList.length,
              itemBuilder: (context, index) {
                final cat = categoryList[index];
                return _buildCategoryItemCard(context, adminVm, cat);
              },
            ),
        ],
      ),
    ),
  );
  }

  Widget _buildOverviewCards(int available, int sold, int total) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 16),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'الكروت المتوفرة',
                        style: TextStyle(fontSize: 12, color: AppTheme.subtitleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$available كارت',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shopping_bag_rounded, color: AppTheme.accentGold, size: 16),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'الكروت المباعة',
                        style: TextStyle(fontSize: 12, color: AppTheme.subtitleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$sold كارت',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accentGold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItemCard(BuildContext context, AdminViewModel adminVm, Map<String, dynamic> cat) {
    final String profileName = cat['profileName'];
    final int available = cat['availableCount'];
    final int sold = cat['soldCount'];
    final int total = cat['totalCount'];

    final bool isOut = available == 0;
    final bool isLow = available > 0 && available <= 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        color: AppTheme.surfaceColor,
        borderColor: isOut
            ? AppTheme.errorColor.withValues(alpha: 0.4)
            : (isLow ? AppTheme.warningColor.withValues(alpha: 0.4) : AppTheme.borderColor),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOut
                        ? AppTheme.errorColor.withValues(alpha: 0.1)
                        : (isLow
                            ? AppTheme.warningColor.withValues(alpha: 0.1)
                            : AppTheme.primaryColor.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.style_rounded,
                    color: isOut ? AppTheme.errorColor : (isLow ? AppTheme.warningColor : AppTheme.primaryColor),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profileName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Text(
                            'المخزون: $total',
                            style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 11),
                          ),
                          Text(
                            'مباع: $sold',
                            style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Stock Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOut
                        ? AppTheme.errorColor.withValues(alpha: 0.1)
                        : (isLow
                            ? AppTheme.warningColor.withValues(alpha: 0.1)
                            : AppTheme.successColor.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOut
                          ? AppTheme.errorColor
                          : (isLow ? AppTheme.warningColor : AppTheme.successColor),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOut
                            ? Icons.warning_amber_rounded
                            : (isLow ? Icons.hourglass_empty_rounded : Icons.check_circle_outline_rounded),
                        color: isOut
                            ? AppTheme.errorColor
                            : (isLow ? AppTheme.warningColor : AppTheme.successColor),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOut ? 'نفدت الكروت' : '$available متوفر',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isOut
                              ? AppTheme.errorColor
                              : (isLow ? AppTheme.warningColor : AppTheme.successColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const NeonDivider(),
            const SizedBox(height: 10),

            // Category Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedCategoryFilter = profileName;
                      _tabController.animateTo(1);
                    });
                  },
                  icon: const Icon(Icons.list_alt_rounded, size: 16, color: AppTheme.primaryColor),
                  label: const Text(
                    'عرض كروت هذه الفئة',
                    style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),

                if (available > 0)
                  InkWell(
                    onTap: () => _confirmDeleteProfileCards(context, adminVm, profileName, available),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.errorColor.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text(
                            'حذف غير المباع ($available)',
                            style: TextStyle(color: AppTheme.errorColor.withValues(alpha: 0.8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProfileCards(
    BuildContext context,
    AdminViewModel adminVm,
    String profileName,
    int availableCount,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
            SizedBox(width: 10),
            Text('حذف الكروت غير المباعة', style: TextStyle(color: AppTheme.errorColor, fontSize: 18)),
          ],
        ),
        content: Text(
          'هل أنت تأكد من رغبتك في حذف جميع الكروت غير المباعة ($availableCount كارت) الخاصة بـ "$profileName" من المخزون؟',
          style: const TextStyle(color: AppTheme.textColor, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.subtitleColor)),
          ),
          TajNetButton(
            fullWidth: false,
            height: 42,
            gradientColors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final ok = await adminVm.deleteAvailableCardsForProfile(profileName);
              if (ok && mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(adminVm.successMessage ?? 'تم الحذف بنجاح'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
            },
            child: const Text('حذف الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: DETAILED CARDS ──────────────────────────────────────────────────
  Widget _buildDetailedCardsTab(
    BuildContext context, {
    required AdminViewModel adminVm,
    required List<CardItem> allCards,
  }) {
    // Extract unique profile categories for filter dropdown/chips
    final Set<String> profilesSet = {};
    for (var c in allCards) {
      if (c.profilePrice.isNotEmpty) profilesSet.add(c.profilePrice);
    }
    final profilesList = profilesSet.toList();

    // Apply Filters
    final String query = _searchController.text.trim().toLowerCase();

    final filteredCards = allCards.where((card) {
      // 1. Status Filter
      if (_filterStatus == 'available' && !card.isAvailable) return false;
      if (_filterStatus == 'sold' && card.isAvailable) return false;

      // 2. Profile Category Filter
      if (_selectedCategoryFilter != null &&
          _selectedCategoryFilter!.isNotEmpty &&
          card.profilePrice != _selectedCategoryFilter) {
        return false;
      }

      // 3. Search Query Filter (PIN or Serial)
      if (query.isNotEmpty) {
        final matchesPin = card.pin.toLowerCase().contains(query);
        final matchesSerial = card.serialNumber.toLowerCase().contains(query);
        final matchesProfile = card.profilePrice.toLowerCase().contains(query);
        final matchesUser = (card.soldToUserName ?? '').toLowerCase().contains(query);
        return matchesPin || matchesSerial || matchesProfile || matchesUser;
      }

      return true;
    }).toList();

    return Column(
      children: [
        // Filter & Search Controls Header
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.surfaceColor,
          child: Column(
            children: [
              // Search Input
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppTheme.textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'بحث برمز الكرت (PIN) أو الرقم التسلسلي...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.subtitleColor),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppTheme.subtitleColor),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surfaceColorElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('الكل', 'all', _filterStatus == 'all', () {
                      setState(() => _filterStatus = 'all');
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('المتوفرة فقط', 'available', _filterStatus == 'available', () {
                      setState(() => _filterStatus = 'available');
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('المباعة فقط', 'sold', _filterStatus == 'sold', () {
                      setState(() => _filterStatus = 'sold');
                    }),

                    if (profilesList.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Container(
                        height: 24,
                        width: 1,
                        color: AppTheme.borderColor,
                      ),
                      const SizedBox(width: 12),

                      // Category Dropdown Chip
                      PopupMenuButton<String?>(
                        onSelected: (val) {
                          setState(() => _selectedCategoryFilter = val);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem<String?>(
                            value: null,
                            child: Text('جميع الفئات'),
                          ),
                          ...profilesList.map((p) => PopupMenuItem<String?>(
                                value: p,
                                child: Text(p),
                              )),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedCategoryFilter != null
                                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                : AppTheme.surfaceColorElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _selectedCategoryFilter != null
                                  ? AppTheme.primaryColor
                                  : AppTheme.borderColor,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.filter_alt_rounded,
                                size: 14,
                                color: _selectedCategoryFilter != null
                                    ? AppTheme.primaryColor
                                    : AppTheme.subtitleColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _selectedCategoryFilter ?? 'كل الفئات',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedCategoryFilter != null
                                      ? AppTheme.primaryColor
                                      : AppTheme.subtitleColor,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 18,
                                color: _selectedCategoryFilter != null
                                    ? AppTheme.primaryColor
                                    : AppTheme.subtitleColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Count info banner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'عرض ${filteredCards.length} كارت',
                style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 13),
              ),
              if (_selectedCategoryFilter != null || _filterStatus != 'all' || query.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _filterStatus = 'all';
                      _selectedCategoryFilter = null;
                      _searchController.clear();
                    });
                  },
                  child: const Text(
                    'إلغاء تصفية النتائج',
                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),

        // Cards ListView
        Expanded(
          child: filteredCards.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: AppTheme.subtitleColor.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'لا توجد كروت تطابق معايير البحث أو التصفية',
                          style: TextStyle(color: AppTheme.subtitleColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: filteredCards.length,
                  itemBuilder: (context, index) {
                    final card = filteredCards[index];
                    return _buildSingleCardTile(context, adminVm, card);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColorElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppTheme.subtitleColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSingleCardTile(BuildContext context, AdminViewModel adminVm, CardItem card) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        color: AppTheme.surfaceColor,
        child: Column(
          children: [
            Row(
              children: [
                // Profile tag badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    card.profilePrice,
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: card.isAvailable
                        ? AppTheme.successColor.withValues(alpha: 0.1)
                        : AppTheme.accentGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: card.isAvailable
                          ? AppTheme.successColor.withValues(alpha: 0.4)
                          : AppTheme.accentGold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    card.isAvailable ? 'متوفر' : 'مباع',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: card.isAvailable ? AppTheme.successColor : AppTheme.accentGold,
                    ),
                  ),
                ),

                const Spacer(),

                // Delete Card Button (Only for available cards)
                if (card.isAvailable)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: 18),
                    onPressed: () => _confirmDeleteSingleCard(context, adminVm, card),
                    tooltip: 'حذف هذا الكارت',
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // PIN Code Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SelectableText(
                            card.pin,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              fontFamily: 'monospace',
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: card.pin));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('📋 تم نسخ PIN الكارت')),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.copy_rounded, size: 16, color: AppTheme.primaryColor),
                            ),
                          ),
                        ],
                      ),
                      if (card.serialNumber.isNotEmpty)
                        Text(
                          'رقم تسلسلي: ${card.serialNumber}',
                          style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Sale Information (If sold)
            if (!card.isAvailable && card.soldToUserName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColorElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.subtitleColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'مباع إلى: ${card.soldToUserName}',
                        style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 11, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (card.soldAt != null)
                      Text(
                        '${card.soldAt!.day}/${card.soldAt!.month}/${card.soldAt!.year}',
                        style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSingleCard(BuildContext context, AdminViewModel adminVm, CardItem card) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
            SizedBox(width: 10),
            Text('تأكيد حذف الكارت', style: TextStyle(color: AppTheme.errorColor, fontSize: 18)),
          ],
        ),
        content: Text(
          'هل أنت تأكد من رغبتك في حذف هذا الكارت (${card.pin}) من المخزون؟',
          style: const TextStyle(color: AppTheme.textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.subtitleColor)),
          ),
          TajNetButton(
            fullWidth: false,
            height: 42,
            gradientColors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final ok = await adminVm.deleteCard(card.id);
              if (ok && mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(adminVm.successMessage ?? 'تم حذف الكارت بنجاح'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
