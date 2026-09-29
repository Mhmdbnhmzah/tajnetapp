import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_user.dart';
import '../../../core/theme/theme.dart';
import '../viewmodels/admin_viewmodel.dart';
import 'user_activity_dialog.dart';

enum UserFilterType { all, active, blocked, admins }

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  UserFilterType _selectedFilter = UserFilterType.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> _filterUsers(List<AppUser> users) {
    return users.where((u) {
      // 1. Status Filter
      switch (_selectedFilter) {
        case UserFilterType.active:
          if (u.isBlocked) return false;
          break;
        case UserFilterType.blocked:
          if (!u.isBlocked) return false;
          break;
        case UserFilterType.admins:
          if (!u.isAdmin) return false;
          break;
        case UserFilterType.all:
          break;
      }

      // 2. Search Query Filter (Name, Phone, AccountNumber, Email)
      if (_searchQuery.isNotEmpty) {
        final nameMatch = u.name.toLowerCase().contains(_searchQuery);
        final phoneMatch = u.phone.toLowerCase().contains(_searchQuery);
        final emailMatch = u.email.toLowerCase().contains(_searchQuery);
        final accountMatch = u.accountNumber.toLowerCase().contains(_searchQuery);
        if (!nameMatch && !phoneMatch && !emailMatch && !accountMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final adminViewModel = Provider.of<AdminViewModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة العملاء والحسابات المسجلة'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<AppUser>>(
          stream: adminViewModel.allUsers,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }

            final allUsers = snapshot.data ?? [];
            if (allUsers.isEmpty) {
              return const Center(
                child: Text('لا يوجد عملاء مسجلين حالياً', style: TextStyle(color: AppTheme.subtitleColor)),
              );
            }

            final filteredUsers = _filterUsers(allUsers);

            return Column(
              children: [
                // ── Search & Filter Controls ─────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppTheme.textColor, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'بحث بالاسم، رقم الهاتف، أو رقم الحساب...',
                          hintStyle: const TextStyle(color: AppTheme.subtitleColor, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryColor, size: 22),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: AppTheme.subtitleColor, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          filled: true,
                          fillColor: AppTheme.surfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Filter Chips + Count
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip('الكل (${allUsers.length})', UserFilterType.all),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('النشطين (${allUsers.where((u) => !u.isBlocked).length})', UserFilterType.active),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('المعطلين (${allUsers.where((u) => u.isBlocked).length})', UserFilterType.blocked),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('المشرفين (${allUsers.where((u) => u.isAdmin).length})', UserFilterType.admins),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Results Count Summary ────────────────────────────────
                if (_searchQuery.isNotEmpty || _selectedFilter != UserFilterType.all)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المطابق للبحث: ${filteredUsers.length} من أصل ${allUsers.length}',
                          style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (_searchQuery.isNotEmpty || _selectedFilter != UserFilterType.all)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _searchController.clear();
                                _selectedFilter = UserFilterType.all;
                              });
                            },
                            child: const Text(
                              'إلغاء الفرز',
                              style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),

                // ── Users List ───────────────────────────────────────────
                Expanded(
                  child: filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off_rounded, size: 54, color: AppTheme.subtitleColor),
                              const SizedBox(height: 12),
                              const Text(
                                'لا توجد نتائج مطابقة لمعايير البحث',
                                style: TextStyle(color: AppTheme.subtitleColor, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('إعادة تعيين البحث'),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _selectedFilter = UserFilterType.all;
                                  });
                                },
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            return _buildUserCard(context, filteredUsers[index], adminViewModel);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, UserFilterType type) {
    final isSelected = _selectedFilter == type;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textColor,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.surfaceColor,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
      ),
      onSelected: (_) {
        setState(() => _selectedFilter = type);
      },
    );
  }

  Widget _buildUserCard(BuildContext context, AppUser u, AdminViewModel adminViewModel) {
    final isBlocked = u.isBlocked;

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => UserActivityDialog(user: u),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.secondaryBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isBlocked
                ? AppTheme.errorColor
                : (u.isAdmin ? AppTheme.primaryColor : Colors.white12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          u.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isBlocked ? AppTheme.errorColor : AppTheme.textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (u.isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryColor),
                          ),
                          child: const Text('أدمن', style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      if (isBlocked) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.errorColor),
                          ),
                          child: const Text('معطل 🔴', style: TextStyle(color: AppTheme.errorColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '${u.balance.toStringAsFixed(1)} ريال',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (u.accountNumber.isNotEmpty)
              Text('رقم الحساب: ${u.accountNumber}', style: const TextStyle(color: AppTheme.accentGold, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('البريد: ${u.email}', style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 13)),
            Text('الهاتف: ${u.phone}', style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 13)),
            if (u.bankName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('الحساب المصرفي: ${u.bankName} - ${u.bankAccountName} (${u.bankAccountNumber})',
                  style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryColor),
                      foregroundColor: AppTheme.primaryColor,
                      minimumSize: const Size(double.infinity, 38),
                    ),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('عرض الكروت والسندات 📋', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => UserActivityDialog(user: u),
                      );
                    },
                  ),
                ),
                if (!u.isAdmin) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 38),
                        backgroundColor: isBlocked ? AppTheme.primaryColor : AppTheme.errorColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(isBlocked ? Icons.check_circle_outline : Icons.block, size: 18),
                      label: Text(
                        isBlocked ? 'تفعيل الحساب' : 'إيقاف الحساب',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppTheme.secondaryBackgroundColor,
                            title: Text(
                              isBlocked ? 'تأكيد تفعيل الحساب' : 'تأكيد إيقاف الحساب',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isBlocked ? AppTheme.primaryColor : AppTheme.errorColor,
                              ),
                            ),
                            content: Text(isBlocked
                                ? 'هل أنت متأكد من إعادة تفعيل حساب العميل (${u.name}) للسماح له باستخدام التطبيق؟'
                                : 'هل أنت متأكد من إيقاف وتعطيل حساب العميل (${u.name}) وتجميد دخوله للتطبيق؟'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('إلغاء', style: TextStyle(color: AppTheme.subtitleColor)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isBlocked ? AppTheme.primaryColor : AppTheme.errorColor,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('تأكيد'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          final success = await adminViewModel.toggleUserBlock(u.uid, !isBlocked);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(!isBlocked ? 'تم إيقاف الحساب بنجاح' : 'تم تفعيل الحساب بنجاح'),
                                backgroundColor: !isBlocked ? AppTheme.errorColor : AppTheme.primaryColor,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
            if (u.hasWalletPin) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.accentGold.withValues(alpha: 0.6)),
                  foregroundColor: AppTheme.accentGold,
                  minimumSize: const Size(double.infinity, 36),
                ),
                icon: const Icon(Icons.shield_outlined, size: 16, color: AppTheme.accentGold),
                label: const Text('إلغاء وإعادة ضبط رمز المحفظة للعميل 🔒', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.secondaryBackgroundColor,
                      title: const Text('تأكيد إعادة ضبط رمز المحفظة', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentGold)),
                      content: Text('هل أنت متأكد من إلغاء وإعادة ضبط رمز حماية المحفظة للعميل (${u.name})؟ سيتمكن العميل من تعيين رمز جديد مخصص بمفرده.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('إلغاء', style: TextStyle(color: AppTheme.subtitleColor)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('تأكيد الضبط', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    final success = await adminViewModel.resetUserWalletPin(u.uid);
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ تم إلغاء وإعادة ضبط رمز المحفظة للعميل بنجاح!'),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
