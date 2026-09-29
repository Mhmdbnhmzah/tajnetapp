import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../auth/data/biometric_service.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

class WalletPinDialog extends StatefulWidget {
  final bool isVerification; // true = verify before transaction, false = setup/change PIN
  final String title;
  final String subtitle;

  const WalletPinDialog({
    super.key,
    this.isVerification = true,
    this.title = 'رمز حماية المحفظة',
    this.subtitle = 'أدخل رمز الحماية المكون من 4 أرقام لتأكيد العملية',
  });

  static Future<bool?> show(
    BuildContext context, {
    bool isVerification = true,
    String title = 'رمز حماية المحفظة 🔒',
    String subtitle = 'أدخل رمز الحماية المكون من 4 أرقام لتأكيد العملية',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WalletPinDialog(
        isVerification: isVerification,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<WalletPinDialog> createState() => _WalletPinDialogState();
}

class _WalletPinDialogState extends State<WalletPinDialog> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  final List<TextEditingController> _confirmControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _confirmFocusNodes = List.generate(4, (_) => FocusNode());

  bool _isSetupMode = false;
  bool _isVerifyCurrentStep = false; // Require current PIN verification when changing existing PIN
  bool _isConfirmStep = false;

  String _firstEnteredPin = '';
  String? _errorMessage;
  bool _isLoading = false;

  final BiometricService _biometricService = BiometricService();
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _isSetupMode = !widget.isVerification;

    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final hasExistingPin = authVm.appUser?.hasWalletPin ?? false;

    // If changing PIN and user already has an existing PIN, require verifying current PIN first
    if (_isSetupMode && hasExistingPin) {
      _isVerifyCurrentStep = true;
    }

    _checkBiometrics();
  }

  void _checkBiometrics() async {
    final canUse = await _biometricService.isBiometricsAvailable();
    if (mounted) {
      setState(() => _canUseBiometrics = canUse);
    }
  }

  void _authenticateWithBiometrics() async {
    final success = await _biometricService.authenticate(
      localizedReason: 'استخدم بصمة الإصبع أو الوجه لتأكيد العملية في تاج نت 🔒',
    );
    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    for (var c in _confirmControllers) {
      c.dispose();
    }
    for (var f in _confirmFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _getEnteredPin(List<TextEditingController> controllers) {
    return controllers.map((c) => c.text).join();
  }

  void _onPinDigitChanged(
    int index,
    String value,
    List<TextEditingController> controllers,
    List<FocusNode> focusNodes,
  ) {
    if (value.isNotEmpty) {
      HapticFeedback.lightImpact();
    }
    if (value.length == 1) {
      if (index < 3) {
        focusNodes[index + 1].requestFocus();
      } else {
        focusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      HapticFeedback.selectionClick();
      focusNodes[index - 1].requestFocus();
    }
    setState(() => _errorMessage = null);
  }

  // 1. Submit Current PIN Verification (When updating an existing PIN)
  void _submitVerifyCurrentPin() {
    final pin = _getEnteredPin(_controllers);
    if (pin.length < 4) {
      setState(() => _errorMessage = 'يرجى إدخال 4 أرقام كاملة');
      return;
    }

    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final isValid = authVm.verifyWalletPin(pin);

    if (isValid) {
      setState(() {
        _isVerifyCurrentStep = false;
        _errorMessage = null;
        for (var c in _controllers) {
          c.clear();
        }
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _focusNodes[0].requestFocus();
      });
    } else {
      setState(() {
        _errorMessage = '❌ رمز المحفظة الحالي غير صحيح، يرجى المحاولة مرة أخرى';
        for (var c in _controllers) {
          c.clear();
        }
      });
      _focusNodes[0].requestFocus();
    }
  }

  // 2. Submit Transaction PIN Verification
  void _submitVerification() {
    final enteredPin = _getEnteredPin(_controllers);
    if (enteredPin.length < 4) {
      setState(() => _errorMessage = 'يرجى إدخال 4 أرقام كاملة');
      return;
    }

    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final isValid = authVm.verifyWalletPin(enteredPin);

    if (isValid) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMessage = '❌ رمز حماية المحفظة غير صحيح، يرجى المحاولة مرة أخرى';
        for (var c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      });
    }
  }

  // 3. Submit Setup First Step (Enter New PIN)
  void _submitSetupFirstStep() {
    final pin = _getEnteredPin(_controllers);
    if (pin.length < 4) {
      setState(() => _errorMessage = 'يرجى إدخال 4 أرقام كاملة');
      return;
    }

    setState(() {
      _firstEnteredPin = pin;
      _isConfirmStep = true;
      _errorMessage = null;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _confirmFocusNodes[0].requestFocus();
    });
  }

  // 4. Submit Setup Final Step (Confirm New PIN)
  void _submitSetupFinalStep() async {
    final confirmPin = _getEnteredPin(_confirmControllers);
    if (confirmPin.length < 4) {
      setState(() => _errorMessage = 'يرجى تأكيد الأرقام الـ 4 كلياً');
      return;
    }

    if (confirmPin != _firstEnteredPin) {
      setState(() {
        _errorMessage = '❌ الرموز غير متطابقة! أعد إدخال الرمز من جديد';
        _isConfirmStep = false;
        _firstEnteredPin = '';
        for (var c in _controllers) {
          c.clear();
        }
        for (var c in _confirmControllers) {
          c.clear();
        }
      });
      _focusNodes[0].requestFocus();
      return;
    }

    setState(() => _isLoading = true);
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final success = await authVm.setWalletPin(confirmPin);
    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 تم حفظ وتفعيل رمز حماية المحفظة بنجاح!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      setState(() => _errorMessage = authVm.authError ?? 'حدث خطأ أثناء ضبط الرمز');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = Provider.of<AuthViewModel>(context);
    final user = authVm.appUser;
    final bool hasExistingPin = user?.hasWalletPin ?? false;

    String titleText;
    String subtitleText;
    String buttonText;

    if (_isVerifyCurrentStep) {
      titleText = 'رمز المحفظة الحالي 🔒';
      subtitleText = 'أدخل رمزك الحالي لتأكيد هويتك قبل ضبط رمز جديد';
      buttonText = 'التحقق والمتابعة لتغيير الرمز';
    } else if (_isSetupMode) {
      if (_isConfirmStep) {
        titleText = 'تأكيد الرمز الجديد 🔒';
        subtitleText = 'أعد إدخال الرمز الجديد المكون من 4 أرقام للتأكيد';
        buttonText = 'حفظ الرمز الجديد';
      } else {
        titleText = hasExistingPin ? 'رمز حماية جديد 🔒' : 'إنشاء رمز حماية المحفظة 🔒';
        subtitleText = 'قم بإدخال رمز جديد مكون من 4 أرقام لحماية محفظتك';
        buttonText = 'المتابعة لتأكيد الرمز';
      }
    } else {
      titleText = widget.title;
      subtitleText = widget.subtitle;
      buttonText = 'تأكيد وتنفيذ العملية';
    }

    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.primaryGlow,
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              const SizedBox(height: 16),

              // Title
              Text(
                titleText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                subtitleText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.subtitleColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              if (_isSetupMode || hasExistingPin) ...[
                // PIN Input Grid
                _buildPinInputRow(
                  controllers: _isConfirmStep ? _confirmControllers : _controllers,
                  focusNodes: _isConfirmStep ? _confirmFocusNodes : _focusNodes,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),

                // Submit Button
                TajNetButton(
                  isLoading: _isLoading,
                  onPressed: () {
                    if (_isVerifyCurrentStep) {
                      _submitVerifyCurrentPin();
                    } else if (_isSetupMode) {
                      if (_isConfirmStep) {
                        _submitSetupFinalStep();
                      } else {
                        _submitSetupFirstStep();
                      }
                    } else {
                      _submitVerification();
                    }
                  },
                  child: Text(
                    buttonText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),

                const SizedBox(height: 12),

                // Biometrics Alternative Button (Fingerprint / Face ID) - ONLY when verifying an EXISTING PIN
                if (widget.isVerification && hasExistingPin && !_isSetupMode && _canUseBiometrics) ...[
                  OutlinedButton.icon(
                    onPressed: _authenticateWithBiometrics,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryColor, size: 22),
                    label: const Text(
                      'تأكيد بالبصمة',
                      style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Cancel / Back Button
                TextButton(
                  onPressed: () {
                    if (_isConfirmStep) {
                      setState(() {
                        _isConfirmStep = false;
                        _firstEnteredPin = '';
                        for (var c in _controllers) {
                          c.clear();
                        }
                        for (var c in _confirmControllers) {
                          c.clear();
                        }
                      });
                      _focusNodes[0].requestFocus();
                    } else {
                      Navigator.pop(context, false);
                    }
                  },
                  child: Text(
                    _isConfirmStep ? 'الرجوع' : 'إلغاء',
                    style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 14),
                  ),
                ),
              ] else ...[
                // Banner for User with NO PIN set yet (When attempting a transaction - Mandatory Setup)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.shield_rounded, color: AppTheme.accentGold, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'إعداد رمز حماية المحفظة إلزامي 🔒',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentGold, fontSize: 15),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'لحماية رصيدك وأمان حسابك، يلزم إنشاء رمز حماية مكون من 4 أرقام قبل إتمام عملية الشراء أو التحويل.',
                        style: TextStyle(color: AppTheme.textColor, fontSize: 13, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                TajNetButton(
                  onPressed: () {
                    setState(() {
                      _isSetupMode = true;
                    });
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted) _focusNodes[0].requestFocus();
                    });
                  },
                  gradientColors: const [AppTheme.accentGold, Color(0xFFFF8F00)],
                  child: const Text(
                    'إنشاء رمز حماية للمحفظة الآن 🔒',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),

                const SizedBox(height: 10),

                TextButton(
                  onPressed: () => Navigator.pop(context, false), // Mandatory: cannot proceed without PIN
                  child: const Text('إلغاء العملية', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinInputRow({
    required List<TextEditingController> controllers,
    required List<FocusNode> focusNodes,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          width: 44,
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            controller: controllers[index],
            focusNode: focusNodes[index],
            autofocus: index == 0,
            obscureText: true,
            obscuringCharacter: '●',
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            textInputAction: index == 3 ? TextInputAction.done : TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: AppTheme.surfaceColorElevated,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
            onChanged: (val) => _onPinDigitChanged(index, val, controllers, focusNodes),
          ),
        );
      }),
    );
  }
}
