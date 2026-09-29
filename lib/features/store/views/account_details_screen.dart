import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_user.dart';
import '../../../core/theme/theme.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import 'wallet_pin_dialog.dart';

class AccountDetailsScreen extends StatelessWidget {
  const AccountDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthViewModel, AppUser?>((vm) => vm.appUser);

    if (user == null) {
      return TajNetBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: const TajNetAppBar(title: 'معلومات الحساب'),
          body: const Center(child: Text('لم يتم تسجيل الدخول', style: TextStyle(color: AppTheme.textColor))),
        ),
      );
    }

    return TajNetBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const TajNetAppBar(
          title: 'معلومات الحساب',
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Header Card
                AppCard(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.5),
                  borderColor: AppTheme.accentCyan.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentCyan.withValues(alpha: 0.4),
                              blurRadius: 12,
                            )
                          ]
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            user.name.isNotEmpty ? user.name[0] : '👤',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
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
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.phone,
                              style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const SectionHeader(title: 'بيانات الحساب الأساسية'),
                const SizedBox(height: 12),

                _buildInfoTile(
                  context,
                  icon: Icons.numbers_rounded,
                  label: 'رقم الحساب الخاص في التطبيق',
                  value: user.accountNumber,
                  isHighlight: true,
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: user.accountNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📋 تم نسخ رقم الحساب الخاص بنجاح!'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  },
                ),

                _buildInfoTile(
                  context,
                  icon: Icons.person_outline_rounded,
                  label: 'الاسم الكامل',
                  value: user.name,
                ),

                _buildInfoTile(
                  context,
                  icon: Icons.phone_outlined,
                  label: 'رقم الهاتف',
                  value: user.phone,
                ),

                if (user.email.isNotEmpty)
                  _buildInfoTile(
                    context,
                    icon: Icons.email_outlined,
                    label: 'البريد الإلكتروني',
                    value: user.email,
                  ),

                const SizedBox(height: 24),
                const SectionHeader(title: 'إعدادات أمان الدخول'),
                const SizedBox(height: 12),

                Consumer<AuthViewModel>(
                  builder: (context, authVm, child) {
                    return AppCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.touch_app_rounded, color: AppTheme.primaryColor, size: 20),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تسجيل الدخول التلقائي',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'الدخول مباشرة عند فتح التطبيق بدون طلب البيانات',
                                  style: TextStyle(fontSize: 12, color: AppTheme.subtitleColor),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: authVm.autoLoginEnabled,
                            activeTrackColor: AppTheme.accentCyan,
                            activeThumbColor: Colors.white,
                            onChanged: (val) {
                              authVm.setAutoLoginEnabled(val);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(val
                                      ? '✅ تم تفعيل تسجيل الدخول التلقائي'
                                      : '🔒 تم إيقاف الدخول التلقائي (سيطلب التطبيق البيانات عند فتح التطبيق)'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Wallet Security PIN Config Card
                AppCard(
                  onTap: () => WalletPinDialog.show(context, isVerification: false),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (user.hasWalletPin ? AppTheme.successColor : AppTheme.accentGold).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.shield_rounded,
                          color: user.hasWalletPin ? AppTheme.successColor : AppTheme.accentGold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'رمز حماية المحفظة',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.hasWalletPin
                                  ? 'رمز مكون من 4 أرقام يمنع الشراء والتحويل بدون إذنك'
                                  : 'اضغط هنا لإنشاء رمز مكون من 4 أرقام لتأمين محفظتك',
                              style: const TextStyle(fontSize: 12, color: AppTheme.subtitleColor),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_left_rounded, color: AppTheme.subtitleColor, size: 22),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Change Password Button
                TajNetButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const _ChangePasswordDialog(),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_reset_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text('تغيير كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
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

  Widget _buildInfoTile(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
    VoidCallback? onCopy,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlight ? AppTheme.primaryColor.withValues(alpha: 0.08) : AppTheme.surfaceColorElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isHighlight ? AppTheme.accentCyan : AppTheme.borderColor),
        boxShadow: isHighlight ? [
          BoxShadow(
            color: AppTheme.accentCyan.withValues(alpha: 0.15),
            blurRadius: 10,
          )
        ] : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHighlight ? AppTheme.accentCyan : AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: isHighlight ? Colors.black : AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isHighlight ? 18 : 15,
                    fontWeight: FontWeight.bold,
                    color: isHighlight ? AppTheme.accentCyan : AppTheme.textColor,
                    letterSpacing: isHighlight ? 1 : 0,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.copy_rounded, color: AppTheme.accentCyan, size: 14),
                    SizedBox(width: 4),
                    Text('نسخ', style: TextStyle(color: AppTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _dialogError;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _dialogError = null;
    });

    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final success = await authVm.changePassword(
      currentPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم تغيير كلمة المرور بنجاح!'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      setState(() {
        _isSubmitting = false;
        _dialogError = authVm.authError ?? 'عفواً، تعذر تغيير كلمة المرور. يرجى التأكد من كلمة المرور الحالية.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.accentPurple.withValues(alpha: 0.5)),
      ),
      title: const Row(
        children: [
          Icon(Icons.lock_reset_rounded, color: AppTheme.accentPurple),
          SizedBox(width: 10),
          Text('تغيير كلمة المرور', style: TextStyle(color: AppTheme.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_dialogError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(_dialogError!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                ),
              ],

              const Text('1. كلمة السر القديمة (الحالية)', style: TextStyle(fontSize: 13, color: AppTheme.subtitleColor)),
              const SizedBox(height: 6),
              _buildPasswordField(
                controller: _oldPasswordController,
                obscure: _obscureOld,
                hintText: 'أدخل كلمة السر القديمة',
                onToggleObscure: () => setState(() => _obscureOld = !_obscureOld),
                validator: (v) => v == null || v.isEmpty ? 'يرجى إدخال كلمة السر القديمة' : null,
              ),

              const SizedBox(height: 16),

              const Text('2. كلمة السر الجديدة', style: TextStyle(fontSize: 13, color: AppTheme.subtitleColor)),
              const SizedBox(height: 6),
              _buildPasswordField(
                controller: _newPasswordController,
                obscure: _obscureNew,
                hintText: 'أدخل كلمة السر الجديدة (8 خانات تتضمن أحرفاً وأرقاماً)',
                icon: Icons.lock_reset_rounded,
                onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'يرجى إدخال كلمة السر الجديدة';
                  if (v.length < 8) return 'يجب أن تكون 8 خانات على الأقل';
                  final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(v);
                  final hasDigit = RegExp(r'\d').hasMatch(v);
                  if (!hasLetter || !hasDigit) return 'يجب أن تحتوي على أحرف وأرقام معاً';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              const Text('3. تأكيد كلمة السر الجديدة', style: TextStyle(fontSize: 13, color: AppTheme.subtitleColor)),
              const SizedBox(height: 6),
              _buildPasswordField(
                controller: _confirmPasswordController,
                obscure: _obscureConfirm,
                hintText: 'أعد إدخال كلمة السر الجديدة للتأكيد',
                icon: Icons.check_circle_outline_rounded,
                onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'يرجى تأكيد كلمة السر الجديدة';
                  if (v != _newPasswordController.text) return 'كلمتا السر غير متطابقتين';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: AppTheme.subtitleColor)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(130, 44),
            backgroundColor: AppTheme.accentPurple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSubmitting ? null : _submitChangePassword,
          child: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('حفظ التغيير', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscure,
    required String hintText,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
    IconData icon = Icons.lock_outline_rounded,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.textColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppTheme.subtitleColor.withValues(alpha: 0.7)),
        prefixIcon: Icon(icon, color: AppTheme.accentPurple),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppTheme.accentPurple),
          onPressed: onToggleObscure,
        ),
        filled: true,
        fillColor: AppTheme.surfaceColorElevated,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.accentPurple.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accentPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.errorColor, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}
