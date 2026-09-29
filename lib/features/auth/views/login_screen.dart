import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../viewmodels/auth_viewmodel.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  Timer? _autoDetectLoginTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    // Check immediately upon mounting LoginScreen to detect if already logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AuthViewModel>(context, listen: false).checkStatus(isPolling: true);
      }
    });

    // Automatically check router status periodically (every 3 seconds) to detect browser login immediately
    _autoDetectLoginTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        final authVm = Provider.of<AuthViewModel>(context, listen: false);
        if (!authVm.isLoggedIn && !authVm.isLoading) {
          authVm.checkStatus(isPolling: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _autoDetectLoginTimer?.cancel();
    _pinController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String _improveInput(String input) {
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String cleanStr = input.replaceAll(' ', '');
    for (int i = 0; i < arabicNumbers.length; i++) {
      cleanStr = cleanStr.replaceAll(arabicNumbers[i], englishNumbers[i]);
    }
    return cleanStr;
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      body: TajNetBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: RefreshIndicator(
              color: AppTheme.primaryColor,
              backgroundColor: AppTheme.surfaceColor,
              onRefresh: () async {
                await authViewModel.checkStatus(isPolling: false);
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildBanner(),
                    const SizedBox(height: 24),
                    if (authViewModel.errorMessage != null)
                      _buildErrorBox(authViewModel.errorMessage!),
                    _buildHotspotForm(authViewModel),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
              width: 2.5,
            ),
            boxShadow: [
              ...AppTheme.primaryGlow,
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.25),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/img/logo.jpeg',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ShaderMask(
          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            'شبكة تاج نت',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'إنترنت سريع · بلا حدود',
          style: TextStyle(fontSize: 13, color: AppTheme.subtitleColor),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    return AppCard(
      gradient: LinearGradient(
        colors: [AppTheme.primaryColor.withValues(alpha: 0.15), AppTheme.surfaceColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_rounded, color: AppTheme.primaryColor, size: 28),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أهلاً بك في شبكة تاج نت 👋',
                    style: TextStyle(color: AppTheme.textColor, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'استمتع بأسرع خدمة إنترنت وتغطية عالية الجودة كلياً',
                    style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotspotForm(AuthViewModel authViewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'تسجيل كرت الشبكة'),
        const SizedBox(height: 14),

        if (authViewModel.savedPins.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerRight,
            child: Text('الكروت المحفوظة:', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 13)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: authViewModel.savedPins.map((pin) {
              return GestureDetector(
                onTap: () {
                  _pinController.text = pin;
                  authViewModel.login(pin);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColorElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.2), blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    pin,
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColorElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: TextField(
            controller: _pinController,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textColor, fontSize: 22, letterSpacing: 3, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'أدخل رمز الكرت',
              hintStyle: TextStyle(color: AppTheme.subtitleColor.withValues(alpha: 0.6)),
              prefixIcon: const Icon(Icons.wifi_password, color: AppTheme.primaryColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 24),

        TajNetButton(
          onPressed: () async {
            final pin = _improveInput(_pinController.text);
            if (pin.isEmpty) return;
            await authViewModel.login(pin);
          },
          isLoading: authViewModel.isLoading,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login_rounded, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'دخول الشبكة',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.errorColor.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
