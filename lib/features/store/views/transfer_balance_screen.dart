import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_user.dart';
import '../../../core/theme/theme.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/store_viewmodel.dart';
import 'wallet_pin_dialog.dart';

class TransferBalanceScreen extends StatefulWidget {
  const TransferBalanceScreen({super.key});

  @override
  State<TransferBalanceScreen> createState() => _TransferBalanceScreenState();
}

class _TransferBalanceScreenState extends State<TransferBalanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isSearching = false;
  AppUser? _foundRecipient;
  String? _searchError;

  @override
  void dispose() {
    _accController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _searchRecipient() async {
    final accNum = _accController.text.trim();
    if (accNum.isEmpty) {
      setState(() {
        _searchError = 'يرجى كتابة رقم الحساب الخاص بالمستلم';
        _foundRecipient = null;
      });
      return;
    }

    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final currentUser = authVm.appUser;
    if (currentUser == null) return;

    if (accNum == currentUser.accountNumber) {
      setState(() {
        _searchError = 'لا يمكنك التحويل لنفس حسابك!';
        _foundRecipient = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    final storeVm = Provider.of<StoreViewModel>(context, listen: false);
    final recipient = await storeVm.findUserByAccountNumber(accNum);

    if (!mounted) return;

    setState(() {
      _isSearching = false;
      if (recipient == null) {
        _searchError = 'لم يتم العثور على حساب بهذا الرقم. تأكد من الرقم وكرر المحاولة.';
        _foundRecipient = null;
      } else if (recipient.isBlocked) {
        _searchError = 'عفواً، هذا الحساب متوقف حالياً';
        _foundRecipient = null;
      } else {
        _foundRecipient = recipient;
        _searchError = null;
      }
    });
  }

  void _confirmAndTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_foundRecipient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى التحقق من وجود حساب المستلم أولاً'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final storeVm = Provider.of<StoreViewModel>(context, listen: false);
    final user = authVm.appUser;

    if (user == null) return;

    if (amount > user.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('رصيدك الحالي (${user.balance.toStringAsFixed(1)} ريال) غير كافٍ لهذا المبلغ'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: AppTheme.accentCyan),
            SizedBox(width: 10),
            Text('تأكيد الحوالة', style: TextStyle(color: AppTheme.textColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('هل أنت متأكد من تحويل المبلغ التالي؟', style: TextStyle(color: AppTheme.subtitleColor)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColorElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المستلم:', style: TextStyle(color: AppTheme.subtitleColor)),
                      Text(_foundRecipient!.name, style: const TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('رقم الحساب:', style: TextStyle(color: AppTheme.subtitleColor)),
                      Text(_foundRecipient!.accountNumber, style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المبلغ:', style: TextStyle(color: AppTheme.subtitleColor)),
                      Text('$amount ريال', style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.subtitleColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد التحويل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final verified = await WalletPinDialog.show(
      context,
      title: 'رمز حماية المحفظة 🔒',
      subtitle: 'أدخل رمز حماية المحفظة لتأكيد تحويل $amount ريال إلى ${_foundRecipient!.name}',
    );
    if (verified != true || !mounted) return;

    final success = await storeVm.transferBalance(
      senderUid: user.uid,
      recipientAccountNumber: _foundRecipient!.accountNumber,
      amount: amount,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم تحويل $amount ريال إلى ${_foundRecipient!.name} بنجاح!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      final err = storeVm.errorMessage ?? 'تعذر إتمام عملية التحويل. يرجى المحاولة لاحقاً.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ $err'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthViewModel, AppUser?>((vm) => vm.appUser);
    final storeVm = Provider.of<StoreViewModel>(context);

    return TajNetBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const TajNetAppBar(
          title: 'تحويل رصيد',
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender Balance Card
                if (user != null)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentGold.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('رصيدك المتاح للتحويل', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(
                                '${user.balance.toStringAsFixed(1)} ريال',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: '1. رقم الحساب الخاص بالمستلم'),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _accController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppTheme.accentCyan),
                              decoration: InputDecoration(
                                hintText: 'رقم حساب المستلم (6 أرقام)',
                                hintStyle: TextStyle(color: AppTheme.subtitleColor.withValues(alpha: 0.7)),
                                prefixIcon: const Icon(Icons.numbers_rounded, color: AppTheme.accentCyan),
                                filled: true,
                                fillColor: AppTheme.surfaceColorElevated,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppTheme.accentCyan, width: 2),
                                ),
                              ),
                              onChanged: (_) {
                                if (_foundRecipient != null || _searchError != null) {
                                  setState(() {
                                    _foundRecipient = null;
                                    _searchError = null;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 58,
                            width: 96,
                            child: ElevatedButton(
                              onPressed: _isSearching ? null : _searchRecipient,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.1),
                                foregroundColor: AppTheme.accentCyan,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: AppTheme.accentCyan.withValues(alpha: 0.5)),
                                ),
                                elevation: 0,
                              ),
                              child: _isSearching
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan))
                                  : const Text('تحقق', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),

                      if (_searchError != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(_searchError!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13)),
                        ),
                      ],

                      // Found Recipient Details Card
                      if (_foundRecipient != null) ...[
                        const SizedBox(height: 14),
                        AppCard(
                          color: AppTheme.accentCyan.withValues(alpha: 0.05),
                          borderColor: AppTheme.accentCyan.withValues(alpha: 0.4),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentCyan.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                    )
                                  ]
                                ),
                                child: CircleAvatar(
                                  backgroundColor: AppTheme.accentCyan,
                                  radius: 22,
                                  child: Text(
                                    _foundRecipient!.name.isNotEmpty ? _foundRecipient!.name[0] : '👤',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _foundRecipient!.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textColor),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.verified_rounded, color: AppTheme.accentCyan, size: 16),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'حساب رقم: ${_foundRecipient!.accountNumber}',
                                      style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      const SectionHeader(title: '2. المبلغ المراد تحويله (بالريال)'),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.accentGold),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: TextStyle(color: AppTheme.accentGold.withValues(alpha: 0.5)),
                          prefixIcon: const Icon(Icons.monetization_on_rounded, color: AppTheme.accentGold),
                          filled: true,
                          fillColor: AppTheme.surfaceColorElevated,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppTheme.accentGold.withValues(alpha: 0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppTheme.accentGold, width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ المراد تحويله';
                          final num = double.tryParse(v.trim());
                          if (num == null || num <= 0) return 'أدخل مبلغاً صحيحاً أكبر من 0';
                          return null;
                        },
                      ),

                      const SizedBox(height: 32),

                      TajNetButton(
                        isLoading: storeVm.isLoading,
                        onPressed: storeVm.isLoading ? null : _confirmAndTransfer,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('تأكيد وإرسال الحوالة 🚀', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
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
