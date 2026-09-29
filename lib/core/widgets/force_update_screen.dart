import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/force_update_service.dart';
import '../theme/theme.dart';

/// 🚀 شاشة التحديث الإلزامي (Mandatory Force Update Screen)
/// تصميم احترافي عالمي مستوحى من كبرى التطبيقات العالمية
class MandatoryUpdateScreen extends StatefulWidget {
  final UpdateCheckResult updateResult;

  const MandatoryUpdateScreen({
    super.key,
    required this.updateResult,
  });

  @override
  State<MandatoryUpdateScreen> createState() => _MandatoryUpdateScreenState();
}

class _MandatoryUpdateScreenState extends State<MandatoryUpdateScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  bool _isLaunching = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdateTap() async {
    final url = widget.updateResult.downloadUrl.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ لم يتم تحديد رابط التحديث في لوحة التحكم بعد.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isLaunching = true);
    final success = await ForceUpdateService.launchUpdateUrl(url);
    if (!success && mounted) {
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم نسخ رابط التحديث إلى الحافظة! افتحه في المتصفح.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
    if (mounted) setState(() => _isLaunching = false);
  }

  @override
  Widget build(BuildContext context) {
    // Non-dismissible screen: Prevent back button pop
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: TajNetBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // ── Animated Rocket & System Update Icon ───────────
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.2),
                            AppTheme.accentPurple.withValues(alpha: 0.1),
                          ],
                        ),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        size: 54,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Title & Subtitle ──────────────────────────────
                  ShaderMask(
                    shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                    child: const Text(
                      'تحديث إلزامي جديد 🚀',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Tajawal',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'تم إطلاق إصدار جديد ومطور من تطبيق شبكة تاج نت. يرجى التحديث للاستمرار في استخدام الخدمة وأحدث الميزات.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.subtitleColor,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // ── Version Comparison Badge ─────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'إصدارك الحالي',
                              style: TextStyle(fontSize: 11, color: AppTheme.subtitleColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.updateResult.currentVersion,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        Column(
                          children: [
                            const Text(
                              'الإصدار المطلوب',
                              style: TextStyle(fontSize: 11, color: AppTheme.subtitleColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.updateResult.minVersion,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.successColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Admin Update Message Card ─────────────────────
                  if (widget.updateResult.updateMessage.isNotEmpty)
                    AppCard(
                      color: AppTheme.primaryColor.withValues(alpha: 0.06),
                      borderColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.campaign_rounded,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.updateResult.updateMessage,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textColor,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  // ── Update Action Button ──────────────────────────
                  TajNetButton(
                    onPressed: _isLaunching ? null : _handleUpdateTap,
                    isLoading: _isLaunching,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'تحديث التطبيق الآن 🚀',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Copy Link fallback button
                  if (widget.updateResult.downloadUrl.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.updateResult.downloadUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ تم نسخ رابط التحميل مباشر!'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded,
                          size: 16, color: AppTheme.subtitleColor),
                      label: const Text(
                        'نسخ رابط التحميل المباشر',
                        style: TextStyle(
                            color: AppTheme.subtitleColor, fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 🛡️ Force Update Gate (Real-Time Version Monitor)
/// بوابـة التحديث الإلزامي التفاعلية التي تراقب إصدار التطبيق في الوقت الفعلي
class ForceUpdateGate extends StatefulWidget {
  final Widget child;

  const ForceUpdateGate({super.key, required this.child});

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate> {
  final _forceUpdateService = ForceUpdateService();
  bool _hasPromptedOptional = false;

  void _showOptionalUpdateDialog(BuildContext context, UpdateCheckResult res) {
    if (_hasPromptedOptional) return;
    _hasPromptedOptional = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stars_rounded,
                      color: AppTheme.accentGold, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إصدار جديد متوفر ✨ (${res.latestVersion})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'إصدارك الحالي: ${res.currentVersion}',
                        style: const TextStyle(
                            color: AppTheme.subtitleColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              res.updateMessage,
              style: const TextStyle(
                  color: AppTheme.subtitleColor, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('تذكيري لاحقاً',
                        style: TextStyle(color: AppTheme.subtitleColor)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TajNetButton(
                    height: 44,
                    onPressed: () {
                      Navigator.pop(ctx);
                      ForceUpdateService.launchUpdateUrl(res.downloadUrl);
                    },
                    child: const Text(
                      'تحديث الآن 🌟',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UpdateCheckResult>(
      stream: _forceUpdateService.streamUpdateCheck(),
      builder: (context, snapshot) {
        final result = snapshot.data;

        // If mandatory update is required -> BLOCK with MandatoryUpdateScreen
        if (result != null && result.needsUpdate) {
          return MandatoryUpdateScreen(updateResult: result);
        }

        // If optional update is available -> Prompt non-blocking bottom sheet
        if (result != null && result.suggestUpdate && !_hasPromptedOptional) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showOptionalUpdateDialog(context, result);
          });
        }

        // Otherwise -> Pass through to normal app screen
        return widget.child;
      },
    );
  }
}
