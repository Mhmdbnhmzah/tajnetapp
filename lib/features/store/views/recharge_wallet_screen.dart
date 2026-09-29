import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/config.dart';
import '../../../core/constants/whatsapp_templates.dart';
import '../../../core/models/bank_account.dart';
import '../../../core/models/deposit_request.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/bank_logo_widget.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/store_viewmodel.dart';

class RechargeWalletScreen extends StatefulWidget {
  const RechargeWalletScreen({super.key});

  @override
  State<RechargeWalletScreen> createState() => _RechargeWalletScreenState();
}

class _RechargeWalletScreenState extends State<RechargeWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  XFile? _receiptImage;          // cross-platform (mobile + web)
  Uint8List? _receiptImageBytes; // for web preview via Image.memory
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // ─── Pick Receipt Image ────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    // On web, camera source is not supported — fall back to gallery
    final effectiveSource = (kIsWeb && source == ImageSource.camera)
        ? ImageSource.gallery
        : source;
    try {
      final pickedFile = await _picker.pickImage(
        source: effectiveSource,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (pickedFile != null && mounted) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _receiptImage = pickedFile;
          _receiptImageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر اختيار الصورة. يرجى المحاولة مجدداً.'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  // ─── Pending Request Warning Dialog ───────────────────────────────────────

  void _showPendingRequestDialog(DepositRequest pendingReq) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppTheme.warningColor.withValues(alpha: 0.5),
          ),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              color: AppTheme.warningColor,
              size: 26,
            ),
            SizedBox(width: 10),
            Text(
              'طلب قيد المراجعة ⏳',
              style: TextStyle(
                color: AppTheme.warningColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'عزيزي العميل، يوجد لديك طلب شحن سابق بمبلغ (${pendingReq.amount} ريال) قيد المراجعة والتدقيق حالياً لدى إدارة الشبكة.',
              style: const TextStyle(
                color: AppTheme.textColor,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColorElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.subtitleColor, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'يرجى الانتظار حتى الرد على طلبك من قبل الإدارة، ولا يمكن تقديم طلب شحن جديد حتى اكتمال الطلب السابق.',
                      style: TextStyle(
                        color: AppTheme.subtitleColor,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TajNetButton(
            height: 44,
            borderRadius: 12,
            gradientColors: const [Color(0xFFFFB300), Color(0xFFFF8C00)],
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'حسناً، سأنتظر الرد',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Direct WhatsApp Launch to Administration Number (with Image) ─────────

  Future<bool> _openWhatsAppDirect({
    required String message,
    required XFile? image,
  }) async {
    // 1. Copy message text to clipboard as guaranteed backup
    await Clipboard.setData(ClipboardData(text: message));

    final targetPhone = AppConfig.serviceNumber.replaceAll(RegExp(r'\D'), '');

    // 2. Primary: Native Android direct intent (mobile only)
    if (!kIsWeb) {
      try {
        const nativeChannel = MethodChannel('com.tajnet.app/whatsapp');
        final String imagePath = image?.path ?? '';
        final bool? nativeSuccess = await nativeChannel.invokeMethod<bool>(
          'sendWhatsAppDirect',
          {
            'phone': targetPhone,
            'message': message,
            'imagePath': imagePath,
          },
        );
        if (nativeSuccess == true) return true;
      } catch (e) {
        debugPrint('Native WhatsApp intent error: $e');
      }
    }

    // 3. Fallback: Direct URIs (web + non-Android mobile)
    final encoded = Uri.encodeComponent(message);
    final directUrl = Uri.parse(
      'whatsapp://send?phone=$targetPhone&text=$encoded',
    );
    final waMeUrl = Uri.parse('https://wa.me/$targetPhone?text=$encoded');
    final apiUrl = Uri.parse(
      'https://api.whatsapp.com/send?phone=$targetPhone&text=$encoded',
    );

    for (final uri in [directUrl, waMeUrl, apiUrl]) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (e) {
        debugPrint('Failed to launch WhatsApp URL ($uri): $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر فتح تطبيق واتساب تلقائياً. تم نسخ نص الطلب إلى الحافظة.',
          ),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
    return false;
  }

  // ─── Submit Flow ───────────────────────────────────────────────────────────

  Future<void> _submitDeposit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (_receiptImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى التقاط أو اختيار صورة سند التحويل أولاً'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final storeViewModel = Provider.of<StoreViewModel>(context, listen: false);
    final user = authViewModel.appUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    // 🛑 Step 1: Check if user already has an active pending deposit request
    final pendingReq = await storeViewModel.getPendingDepositRequest(user.uid);
    if (pendingReq != null) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى الانتظار حتى الرد على طلبك'),
            backgroundColor: AppTheme.warningColor,
            duration: Duration(seconds: 4),
          ),
        );
        _showPendingRequestDialog(pendingReq);
      }
      return; // ⛔ STOP! Do NOT submit, do NOT open WhatsApp!
    }

    final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final imageToSend = _receiptImage;

    // ✅ Step 2: Prepare WhatsApp message with user details
    final message = WhatsAppTemplates.depositRequestMessage(
      userName: user.name,
      userPhone: user.phone,
      accountNumber: user.accountNumber,
      amount: amount,
    );

    // 🚀 Step 3: Fast Direct Launch to WhatsApp with attached receipt image
    // Opens chat directly with image attached & caption pre-filled (zero lag)
    final whatsappFuture = _openWhatsAppDirect(
      message: message,
      image: imageToSend,
    );

    // 🛑 Step 4: Record in Firestore in background
    final success = await storeViewModel.submitDepositRequest(
      userId: user.uid,
      userName: user.name,
      userPhone: user.phone,
      userAccountNumber: user.accountNumber,
      amount: amount,
    );

    await whatsappFuture;

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _amountController.clear();
        _receiptImage = null;
        _receiptImageBytes = null;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ تم تسجيل طلب الشحن بنجاح وفتح محادثة الإدارة في واتساب.',
            ),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        final err = storeViewModel.errorMessage ??
            'يرجى الانتظار حتى الرد على طلبك';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $err'),
            backgroundColor: AppTheme.warningColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final storeViewModel = Provider.of<StoreViewModel>(context, listen: false);
    final userId = authViewModel.appUser?.uid ?? '';

    return TajNetBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const TajNetAppBar(title: 'شحن المحفظة'),
        body: SafeArea(
          child: StreamBuilder<List<DepositRequest>>(
            stream: storeViewModel.getUserDepositRequests(userId),
            builder: (context, depositSnap) {
              final userRequests = depositSnap.data ?? [];
              final pendingReq = userRequests.cast<DepositRequest?>().firstWhere(
                (r) => r?.isPending == true,
                orElse: () => null,
              );
              final hasPending = pendingReq != null;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Info Banner ───────────────────────────────────────────
                    _buildInfoBanner(),
                    const SizedBox(height: 18),

                    // ── Pending Request Warning Banner ────────────────────────
                    if (hasPending) ...[
                      _buildPendingRequestBanner(pendingReq),
                      const SizedBox(height: 18),
                    ],

                    // ── Bank Accounts & Form ──────────────────────────────────
                    StreamBuilder<List<BankAccount>>(
                      stream: storeViewModel.activeBankAccounts,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          );
                        }
                        final bankAccounts = snapshot.data ?? [];

                        return Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Step 1: Bank Accounts
                              _buildStepHeader(1, 'الحسابات المصرفية للتحويل'),
                              const SizedBox(height: 12),
                              if (bankAccounts.isEmpty)
                                _buildNoBankAccountsWarning()
                              else
                                ...bankAccounts.map(
                                  (acc) => _buildBankAccountCard(context, acc),
                                ),

                              const SizedBox(height: 24),

                              // Step 2: Amount
                              _buildStepHeader(2, 'المبلغ المُحوَّل (الحد الأدنى 500 ريال)'),
                              const SizedBox(height: 10),
                              _buildAmountField(),

                              const SizedBox(height: 24),

                              // Step 3: Receipt Image
                              _buildStepHeader(3, 'صورة سند الإيداع / الحوالة'),
                              const SizedBox(height: 10),
                              if (_receiptImage != null) _buildImagePreview(),
                              _buildImagePickers(),

                              const SizedBox(height: 32),

                              // Step 4: Submit → WhatsApp
                              _buildSubmitButton(pendingRequest: pendingReq),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 36),
                    const NeonDivider(),
                    const SizedBox(height: 20),

                    // ── History ───────────────────────────────────────────────
                    const SectionHeader(title: 'سجل طلبات الشحن'),
                    const SizedBox(height: 14),
                    _buildHistoryList(
                      userRequests,
                      depositSnap.connectionState == ConnectionState.waiting,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Sub-Widgets ─────────────────────────────────────────────────────────

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'حوِّل المبلغ إلى أحد الحسابات أدناه (الحد الأدنى 500 ريال)، ثم التقط صورة السند وأرسل طلبك عبر واتساب مباشرة إلى المدير.',
              style: TextStyle(
                color: AppTheme.textColor,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBankAccountsWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.warningColor,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'لا توجد حسابات بنكية متاحة حالياً. تواصل مع الدعم.',
              style: TextStyle(color: AppTheme.subtitleColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.accentGold,
      ),
      decoration: InputDecoration(
        hintText: '500.00',
        helperText: 'الحد الأدنى لشحن المحفظة هو ${AppConfig.minDepositAmount.toInt()} ريال',
        helperStyle: TextStyle(
          color: AppTheme.accentGold.withValues(alpha: 0.85),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: AppTheme.accentGold.withValues(alpha: 0.5)),
        prefixIcon: const Icon(
          Icons.attach_money_rounded,
          color: AppTheme.accentGold,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.accentGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accentGold, width: 2),
        ),
        fillColor: AppTheme.surfaceColor.withValues(alpha: 0.5),
        filled: true,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ';
        final num = double.tryParse(v.trim());
        if (num == null || num <= 0) return 'أدخل مبلغاً صحيحاً أكبر من 0';
        if (num < AppConfig.minDepositAmount) {
          return 'الحد الأدنى لطلب الشحن هو ${AppConfig.minDepositAmount.toInt()} ريال';
        }
        return null;
      },
    );
  }

  Widget _buildImagePreview() {
    if (_receiptImageBytes == null) return const SizedBox.shrink();
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.accentCyan, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentCyan.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _receiptImageBytes!,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: GestureDetector(
            onTap: () => setState(() {
              _receiptImage = null;
              _receiptImageBytes = null;
            }),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppTheme.errorColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePickers() {
    if (kIsWeb) {
      // On web: camera not supported — show gallery button only (full width)
      return _buildPickerButton(ImageSource.gallery, fullWidth: true);
    }
    return Row(
      children: [
        _buildPickerButton(ImageSource.gallery),
        const SizedBox(width: 12),
        _buildPickerButton(ImageSource.camera),
      ],
    );
  }

  Widget _buildPickerButton(ImageSource source, {bool fullWidth = false}) {
    final isGallery = source == ImageSource.gallery;
    final label = kIsWeb ? 'رفع صورة السند' : (isGallery ? 'المعرض' : 'الكاميرا');
    final icon = kIsWeb
        ? Icons.upload_file_rounded
        : (isGallery ? Icons.photo_library_outlined : Icons.camera_alt_outlined);

    final button = GestureDetector(
      onTap: () => _pickImage(source),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColorElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.accentCyan.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.accentCyan, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppTheme.accentCyan, fontSize: 13)),
          ],
        ),
      ),
    );

    return fullWidth ? button : Expanded(child: button);
  }

  Widget _buildPendingRequestBanner(DepositRequest pendingReq) {
    return InkWell(
      onTap: () => _showPendingRequestDialog(pendingReq),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.warningColor.withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: AppTheme.warningColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'طلب شحن قيد المعالجة ⏳',
                    style: TextStyle(
                      color: AppTheme.warningColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.warningColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '${pendingReq.amount} ريال',
                    style: const TextStyle(
                      color: AppTheme.warningColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'يوجد لديك طلب شحن سابق قيد المراجعة والتدقيق حالياً لدى الإدارة. يرجى الانتظار حتى يتم الرد على طلبك واعتماده قبل تقديم أي طلب جديد.',
              style: TextStyle(
                color: AppTheme.textColor,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton({DepositRequest? pendingRequest}) {
    return Consumer<StoreViewModel>(
      builder: (context, storeVM, child) {
        final hasPending = pendingRequest != null;
        final isBusy = storeVM.isLoading || _isSubmitting;

        return Column(
          children: [
            // Notice Banner
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: (hasPending ? AppTheme.warningColor : const Color(0xFF25D366))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (hasPending ? AppTheme.warningColor : const Color(0xFF25D366))
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasPending ? Icons.hourglass_top_rounded : Icons.chat_rounded,
                    color: hasPending ? AppTheme.warningColor : const Color(0xFF25D366),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasPending
                          ? '⏳ يرجى الانتظار حتى الرد على طلبك السابق بمبلغ (${pendingRequest.amount} ريال) ومراجعته من الإدارة قبل تقديم طلب جديد.'
                          : '📱 تنبيه: عند الضغط على الزر أدناه، سيتم تسجيل الطلب وفتح محادثة الإدارة في واتساب مباشرة.',
                      style: const TextStyle(
                        color: AppTheme.textColor,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            TajNetButton(
              isLoading: isBusy,
              onPressed: isBusy
                  ? null
                  : (hasPending
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('يرجى الانتظار حتى الرد على طلبك'),
                              backgroundColor: AppTheme.warningColor,
                              duration: Duration(seconds: 4),
                            ),
                          );
                          _showPendingRequestDialog(pendingRequest);
                        }
                      : _submitDeposit),
              gradientColors: hasPending
                  ? const [Color(0xFFFFB300), Color(0xFFFF8C00)]
                  : const [Color(0xFF25D366), Color(0xFF128C7E)],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasPending ? Icons.hourglass_top_rounded : Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        hasPending
                            ? 'يرجى الانتظار حتى الرد على طلبك ⏳'
                            : 'تسجيل الطلب وفتح واتساب للإدارة 📲',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryList(List<DepositRequest> requests, bool isLoading) {
    if (isLoading && requests.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }
    if (requests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'لا توجد طلبات سابقة',
            style: TextStyle(color: AppTheme.subtitleColor),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: requests.length,
      itemBuilder: (context, index) => _buildRequestCard(requests[index]),
    );
  }

  Widget _buildRequestCard(DepositRequest req) {
    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

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

    return AppCard(
      borderColor: statusColor.withValues(alpha: 0.5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${req.amount} ريال',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'طلب شحن رصيد',
                  style: const TextStyle(
                    color: AppTheme.subtitleColor,
                    fontSize: 12,
                  ),
                ),
                if (req.adminNote.isNotEmpty)
                  Text(
                    'ملاحظة: ${req.adminNote}',
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankAccountCard(BuildContext context, BankAccount account) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        color: AppTheme.surfaceColor.withValues(alpha: 0.6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bank Header: Prominent Logo & Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BankLogoWidget(
                  imageUrl: account.imageUrl,
                  bankName: account.bankName,
                  size: 84,
                  radius: 16,
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    account.bankName,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const NeonDivider(),
            const SizedBox(height: 14),

            // Account Holder
            _buildCopyRow(
              context,
              label: 'اسم صاحب الحساب',
              value: account.accountHolder,
              successMsg: '📋 تم نسخ اسم صاحب الحساب!',
              valueFontSize: 15,
              valueColor: AppTheme.textColor,
            ),
            const SizedBox(height: 10),

            // Account Number
            _buildCopyRow(
              context,
              label: 'رقم الحساب المصرفي',
              value: account.accountNumber,
              successMsg: '📋 تم نسخ رقم الحساب!',
              valueFontSize: 17,
              valueColor: AppTheme.primaryColor,
              letterSpacing: 0.5,
            ),

            // IBAN (optional)
            if (account.iban.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildCopyRow(
                context,
                label: 'رقم الآيبان (IBAN)',
                value: account.iban,
                successMsg: '📋 تم نسخ رقم الآيبان!',
                valueFontSize: 14,
                valueColor: AppTheme.textColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCopyRow(
    BuildContext context, {
    required String label,
    required String value,
    required String successMsg,
    required double valueFontSize,
    required Color valueColor,
    double letterSpacing = 0,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColorElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.subtitleColor,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                    letterSpacing: letterSpacing,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(successMsg),
                  backgroundColor: AppTheme.successColor,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.copy_rounded,
                    color: AppTheme.primaryColor,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'نسخ',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

  Widget _buildStepHeader(int step, String title) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$step',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
      ],
    );
  }
}
