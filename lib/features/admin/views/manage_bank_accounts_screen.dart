import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/models/bank_account.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/bank_logo_widget.dart';
import '../viewmodels/admin_viewmodel.dart';

class ManageBankAccountsScreen extends StatelessWidget {
  const ManageBankAccountsScreen({super.key});

  void _showAccountDialog(
    BuildContext context,
    AdminViewModel adminViewModel, {
    BankAccount? accountToEdit,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BankAccountDialog(
        adminViewModel: adminViewModel,
        accountToEdit: accountToEdit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminViewModel = Provider.of<AdminViewModel>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('إدارة الحسابات والمحافظ المصرفية'),
        centerTitle: true,
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'إضافة حساب أو محفظة',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: () => _showAccountDialog(context, adminViewModel),
      ),
      body: SafeArea(
        child: StreamBuilder<List<BankAccount>>(
          stream: adminViewModel.allBankAccounts,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }

            final accounts = snapshot.data ?? [];
            if (accounts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_outlined,
                          size: 64,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'لا توجد حسابات بنكية مضافة حتى الآن',
                        style: TextStyle(
                          color: AppTheme.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'اضغط على الزر أدناه لإضافة حساب بنكي أو محفظة إلكترونية مع شعارها الخاص.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.subtitleColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final acc = accounts[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: acc.isActive
                          ? AppTheme.borderColor
                          : AppTheme.errorColor.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Bank Logo
                            BankLogoWidget(
                              imageUrl: acc.imageUrl,
                              bankName: acc.bankName,
                              size: 72,
                              radius: 16,
                              fit: BoxFit.cover,
                            ),
                            const SizedBox(width: 14),

                            // Bank Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          acc.bankName,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textColor,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (acc.isActive
                                                  ? AppTheme.successColor
                                                  : AppTheme.errorColor)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: (acc.isActive
                                                    ? AppTheme.successColor
                                                    : AppTheme.errorColor)
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Text(
                                          acc.isActive ? 'مفعّل' : 'معطّل',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: acc.isActive
                                                ? AppTheme.successColor
                                                : AppTheme.errorColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'الاسم: ${acc.accountHolder}',
                                    style: const TextStyle(
                                      color: AppTheme.subtitleColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Text(
                                        'رقم الحساب: ',
                                        style: TextStyle(
                                          color: AppTheme.subtitleColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        acc.accountNumber,
                                        style: const TextStyle(
                                          color: AppTheme.accentGold,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (acc.iban.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'IBAN: ${acc.iban}',
                                      style: const TextStyle(
                                        color: AppTheme.subtitleColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        const Divider(color: Colors.white10, height: 1),
                        const SizedBox(height: 8),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Toggle Active
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: acc.isActive
                                    ? AppTheme.subtitleColor
                                    : AppTheme.successColor,
                              ),
                              icon: Icon(
                                acc.isActive
                                    ? Icons.pause_circle_outline_rounded
                                    : Icons.play_circle_outline_rounded,
                                size: 18,
                              ),
                              label: Text(
                                acc.isActive ? 'تعطيل' : 'تفعيل',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                final updated =
                                    acc.copyWith(isActive: !acc.isActive);
                                await adminViewModel.updateBankAccount(updated);
                              },
                            ),
                            const SizedBox(width: 4),

                            // Edit Button
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text(
                                'تعديل',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () => _showAccountDialog(
                                context,
                                adminViewModel,
                                accountToEdit: acc,
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Delete Button
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppTheme.errorColor,
                                size: 20,
                              ),
                              tooltip: 'حذف الحساب',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AppTheme.surfaceColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(
                                        color: AppTheme.borderColor,
                                      ),
                                    ),
                                    title: const Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: AppTheme.errorColor,
                                          size: 24,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'تأكيد الحذف',
                                          style: TextStyle(
                                            color: AppTheme.textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: Text(
                                      'هل أنت متأكد من رغبتك في حذف حساب "${acc.bankName}" نهائياً من النظام؟',
                                      style: const TextStyle(
                                        color: AppTheme.subtitleColor,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text(
                                          'إلغاء',
                                          style: TextStyle(
                                            color: AppTheme.subtitleColor,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.errorColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'حذف الحساب',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await adminViewModel
                                      .deleteBankAccount(acc.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Bank Account Dialog with Logo Picker & Quick Presets
// ─────────────────────────────────────────────────────────────────────────────

class _BankAccountDialog extends StatefulWidget {
  final AdminViewModel adminViewModel;
  final BankAccount? accountToEdit;

  const _BankAccountDialog({
    required this.adminViewModel,
    this.accountToEdit,
  });

  @override
  State<_BankAccountDialog> createState() => _BankAccountDialogState();
}

class _BankAccountDialogState extends State<_BankAccountDialog> {
  late final TextEditingController _bankNameController;
  late final TextEditingController _holderController;
  late final TextEditingController _numberController;
  late final TextEditingController _ibanController;
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  String? _existingImageUrl;
  bool _isActive = true;
  bool _isSaving = false;

  final List<String> _popularBanks = const [
    'الكريمي',
    'العمقي',
    'ون كاش',
    'جيب',
    'التضامن',
    'كاك بنك',
    'بنك اليمن والكويت',
    'الشمول للتمويل',
  ];

  @override
  void initState() {
    super.initState();
    final acc = widget.accountToEdit;
    _bankNameController = TextEditingController(text: acc?.bankName ?? '');
    _holderController = TextEditingController(text: acc?.accountHolder ?? '');
    _numberController = TextEditingController(text: acc?.accountNumber ?? '');
    _ibanController = TextEditingController(text: acc?.iban ?? '');
    _existingImageUrl = acc?.imageUrl;
    _isActive = acc?.isActive ?? true;
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _holderController.dispose();
    _numberController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo(ImageSource source) async {
    try {
      final effectiveSource = (kIsWeb && source == ImageSource.camera)
          ? ImageSource.gallery
          : source;
      final file = await _picker.pickImage(
        source: effectiveSource,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedImageFile = file;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking bank logo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر اختيار صورة الشعار، يرجى المحاولة ثانية'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    if (kIsWeb) {
      _pickLogo(ImageSource.gallery);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'اختيار صورة شعار البنك أو المحفظة',
                style: TextStyle(
                  color: AppTheme.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryColor),
                ),
                title: const Text('المعرض (الاستوديو)', style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold)),
                subtitle: const Text('اختيار صورة شعار جاهزة من جهازك', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickLogo(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.accentCyan),
                ),
                title: const Text('الكاميرا (تصوير مباشر)', style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold)),
                subtitle: const Text('التقاط صورة للشعار بالكاميرا الآن', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickLogo(ImageSource.camera);
                },
              ),
              if (_selectedImageBytes != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)) ...[
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
                  ),
                  title: const Text('حذف الشعار الحالي', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedImageBytes = null;
                      _selectedImageFile = null;
                      _existingImageUrl = null;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAccount() async {
    final bankName = _bankNameController.text.trim();
    final holder = _holderController.text.trim();
    final number = _numberController.text.trim();
    final iban = _ibanController.text.trim();

    if (bankName.isEmpty || holder.isEmpty || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع البيانات الأساسية المطلوبة'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? finalImageUrl = _existingImageUrl;

      // If a new image was chosen, upload it
      if (_selectedImageBytes != null && _selectedImageFile != null) {
        final uploadedUrl = await widget.adminViewModel.uploadBankLogo(
          _selectedImageBytes!,
          _selectedImageFile!.name,
        );
        if (uploadedUrl != null) {
          finalImageUrl = uploadedUrl;
        }
      }

      final isEditing = widget.accountToEdit != null;

      if (isEditing) {
        final updatedAccount = widget.accountToEdit!.copyWith(
          bankName: bankName,
          accountHolder: holder,
          accountNumber: number,
          iban: iban,
          imageUrl: finalImageUrl,
          isActive: _isActive,
        );
        await widget.adminViewModel.updateBankAccount(updatedAccount);
      } else {
        final newAccount = BankAccount(
          id: '',
          bankName: bankName,
          accountHolder: holder,
          accountNumber: number,
          iban: iban,
          imageUrl: finalImageUrl,
          isActive: _isActive,
        );
        await widget.adminViewModel.addBankAccount(newAccount);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? '✅ تم تحديث بيانات الحساب المصرفي بنجاح'
                  : '✅ تم إضافة الحساب المصرفي الجديد بنجاح',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving bank account: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ حدث خطأ أثناء الحفظ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.accountToEdit != null;

    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      title: Text(
        isEditing ? 'تعديل الحساب المصرفي' : 'إضافة حساب مصرفي أو محفظة',
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo Picker Section
              Center(
                child: Column(
                  children: [
                    // Interactive Logo Box
                    GestureDetector(
                      onTap: _showImageSourcePicker,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primaryColor.withValues(alpha: 0.6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: _buildLogoPreview(),
                            ),
                          ),
                          // Camera Edit Badge
                          Positioned(
                            bottom: -4,
                            left: -4,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.surfaceColor,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add_a_photo_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Delete Badge
                          if (_selectedImageBytes != null ||
                              (_existingImageUrl != null &&
                                  _existingImageUrl!.isNotEmpty))
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImageBytes = null;
                                    _selectedImageFile = null;
                                    _existingImageUrl = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.errorColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Clear Side-by-Side Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Button 1: Gallery
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: BorderSide(
                              color: AppTheme.primaryColor.withValues(alpha: 0.6),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(Icons.photo_library_rounded, size: 17),
                          label: const Text(
                            'المعرض (الاستوديو)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _pickLogo(ImageSource.gallery),
                        ),
                        if (!kIsWeb) ...[
                          const SizedBox(width: 8),
                          // Button 2: Camera
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentCyan,
                              side: BorderSide(
                                color: AppTheme.accentCyan.withValues(alpha: 0.6),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            icon: const Icon(Icons.camera_alt_rounded, size: 17),
                            label: const Text(
                              'الكاميرا',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _pickLogo(ImageSource.camera),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'اضغط على الشعار أو اختر من المعرض أو الكاميرا',
                      style: TextStyle(
                        color: AppTheme.subtitleColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Divider(color: Colors.white10),
              const SizedBox(height: 10),

              // Quick Preset Chips
              const Text(
                'اقتراحات سريعة لاسم البنك / المحفظة:',
                style: TextStyle(
                  color: AppTheme.subtitleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _popularBanks.map((name) {
                  return InkWell(
                    onTap: () {
                      _bankNameController.text = name;
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColorElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.borderColor.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              // Bank Name Field
              TextField(
                controller: _bankNameController,
                decoration: InputDecoration(
                  labelText: 'اسم البنك / المحفظة *',
                  hintText: 'مثلاً: بنك الكريمي أو محفظة جيب',
                  prefixIcon: const Icon(
                    Icons.account_balance_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceColorElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Holder Name Field
              TextField(
                controller: _holderController,
                decoration: InputDecoration(
                  labelText: 'اسم صاحب الحساب *',
                  hintText: 'الاسم الثلاثي أو الرباعي',
                  prefixIcon: const Icon(
                    Icons.person_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceColorElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Account Number Field
              TextField(
                controller: _numberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'رقم الحساب المصرفي *',
                  hintText: 'رقم الحساب للتحويل',
                  prefixIcon: const Icon(
                    Icons.credit_card_rounded,
                    color: AppTheme.accentGold,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceColorElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // IBAN Field
              TextField(
                controller: _ibanController,
                decoration: InputDecoration(
                  labelText: 'رقم الآيبان IBAN (اختياري)',
                  hintText: 'YE...',
                  prefixIcon: const Icon(
                    Icons.numbers_rounded,
                    color: AppTheme.subtitleColor,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceColorElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Is Active Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppTheme.successColor,
                title: const Text(
                  'تفعيل الحساب واستقبال التحويلات',
                  style: TextStyle(
                    color: AppTheme.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'عند إلغاء التفعيل لن يظهر الحساب للعملاء في شاشة الشحن',
                  style: TextStyle(
                    color: AppTheme.subtitleColor,
                    fontSize: 11,
                  ),
                ),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text(
            'إلغاء',
            style: TextStyle(color: AppTheme.subtitleColor),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: _isSaving ? null : _saveAccount,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isEditing ? 'تحديث الحساب' : 'إضافة الحساب',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLogoPreview() {
    if (_selectedImageBytes != null) {
      return Image.memory(
        _selectedImageBytes!,
        fit: BoxFit.cover,
      );
    }
    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      return BankLogoWidget(
        imageUrl: _existingImageUrl,
        size: 96,
        radius: 18,
        fit: BoxFit.cover,
      );
    }
    return Container(
      color: AppTheme.surfaceColorElevated,
      child: const Center(
        child: Icon(
          Icons.account_balance_rounded,
          color: AppTheme.primaryColor,
          size: 44,
        ),
      ),
    );
  }
}
