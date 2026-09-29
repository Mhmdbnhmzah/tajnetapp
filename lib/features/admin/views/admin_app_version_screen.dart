import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/force_update_service.dart';
import '../../../core/theme/theme.dart';

class AdminAppVersionScreen extends StatefulWidget {
  const AdminAppVersionScreen({super.key});

  @override
  State<AdminAppVersionScreen> createState() => _AdminAppVersionScreenState();
}

class _AdminAppVersionScreenState extends State<AdminAppVersionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _minVersionController = TextEditingController();
  final _latestVersionController = TextEditingController();
  final _downloadUrlController = TextEditingController();
  final _updateMessageController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _successMsg;
  String? _errorMsg;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final _db = FirebaseFirestore.instance;
  static const _collection = 'app_config';
  static const _document = 'version';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _minVersionController.dispose();
    _latestVersionController.dispose();
    _downloadUrlController.dispose();
    _updateMessageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    try {
      final doc = await _db.collection(_collection).doc(_document).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _minVersionController.text = data['min_version'] ?? '1.0.0';
        _latestVersionController.text = data['latest_version'] ?? '1.0.0';
        _downloadUrlController.text = data['download_url'] ?? '';
        _updateMessageController.text = data['update_message'] ??
            'يتوفر تحديث جديد ومهم للتطبيق. يرجى التحديث للاستمرار في الاستخدام.';
      } else {
        // Set sensible defaults for first time
        _minVersionController.text = '1.0.0';
        _latestVersionController.text = '1.0.0';
        _updateMessageController.text =
            'يتوفر تحديث جديد ومهم للتطبيق. يرجى التحديث للاستمرار في الاستخدام.';
      }
    } catch (e) {
      debugPrint('Error loading app version settings: $e');
      if (!mounted) return;
      setState(() => _errorMsg = 'تعذر تحميل إعدادات الإصدار. يرجى التحقق من الاتصال بالإنترنت.');
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  String? _validateVersion(String? val) {
    if (val == null || val.trim().isEmpty) return 'الحقل مطلوب';
    final parts = val.trim().split('.');
    if (parts.length != 3) return 'الصيغة يجب أن تكون: X.Y.Z (مثال: 1.2.0)';
    for (final p in parts) {
      if (int.tryParse(p) == null) return 'الأرقام فقط (مثال: 1.2.0)';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final minV = _minVersionController.text.trim();
    final latestV = _latestVersionController.text.trim();

    // Sanity: min must be <= latest
    if (ForceUpdateService.compareVersions(minV, latestV) > 0) {
      setState(
          () => _errorMsg = 'الحد الأدنى لا يمكن أن يكون أكبر من الإصدار الأخير');
      return;
    }

    setState(() {
      _isSaving = true;
      _successMsg = null;
      _errorMsg = null;
    });

    try {
      await _db.collection(_collection).doc(_document).set({
        'min_version': minV,
        'latest_version': latestV,
        'download_url': _downloadUrlController.text.trim(),
        'update_message': _updateMessageController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      setState(() => _successMsg = 'تم حفظ الإعدادات بنجاح ✓');
    } catch (e) {
      debugPrint('Error saving app version settings: $e');
      setState(() => _errorMsg = 'تعذر حفظ الإعدادات حالياً. يرجى المحاولة لاحقاً.');
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: TajNetBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                // ─── App Bar ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                AppTheme.surfaceColor.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: const Icon(Icons.arrow_back_ios_rounded,
                              color: AppTheme.textColor, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'إدارة إصدارات التطبيق',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                      ),
                      // Refresh button
                      GestureDetector(
                        onTap: _loadCurrentConfig,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: const Icon(Icons.refresh_rounded,
                              color: AppTheme.primaryColor, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ─── Body ──────────────────────────────────────────
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryColor))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // How-it-works banner
                                _buildInfoBanner(),
                                const SizedBox(height: 20),

                                // Version Config Card
                                _buildSectionCard(
                                  title: 'إعدادات الإصدار',
                                  icon: Icons.system_update_rounded,
                                  iconColor: AppTheme.accentGold,
                                  children: [
                                    _buildVersionField(
                                      label: 'الحد الأدنى للإصدار (min_version)',
                                      hint: '1.0.0',
                                      controller: _minVersionController,
                                      helperText:
                                          'أي مستخدم إصداره أقل من هذا سيُجبر على التحديث',
                                      color: AppTheme.errorColor,
                                      icon: Icons.block_rounded,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildVersionField(
                                      label: 'أحدث إصدار (latest_version)',
                                      hint: '1.0.0',
                                      controller: _latestVersionController,
                                      helperText:
                                          'أي مستخدم إصداره أقل ولكن فوق الحد الأدنى سيرى اقتراحاً اختيارياً',
                                      color: AppTheme.successColor,
                                      icon: Icons.new_releases_rounded,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Download URL Card
                                _buildSectionCard(
                                  title: 'رابط التحديث',
                                  icon: Icons.link_rounded,
                                  iconColor: AppTheme.primaryColor,
                                  children: [
                                    _buildTextField(
                                      label: 'رابط تحميل APK أو المتجر',
                                      hint: 'https://example.com/app.apk',
                                      controller: _downloadUrlController,
                                      keyboardType: TextInputType.url,
                                      helperText:
                                          'الرابط الذي سيفتح عند ضغط المستخدم على زر التحديث',
                                      icon: Icons.download_rounded,
                                      isRequired: false,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Message Card
                                _buildSectionCard(
                                  title: 'رسالة التحديث',
                                  icon: Icons.message_rounded,
                                  iconColor: AppTheme.accentPurple,
                                  children: [
                                    _buildTextField(
                                      label: 'النص الذي يراه المستخدم',
                                      hint:
                                          'يتوفر تحديث جديد ومهم للتطبيق...',
                                      controller: _updateMessageController,
                                      maxLines: 3,
                                      icon: Icons.edit_note_rounded,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Preview Card
                                _buildPreviewCard(),
                                const SizedBox(height: 20),

                                // Messages
                                if (_successMsg != null)
                                  _buildAlert(
                                      _successMsg!, AppTheme.successColor,
                                      Icons.check_circle_rounded),
                                if (_errorMsg != null)
                                  _buildAlert(
                                      _errorMsg!, AppTheme.errorColor,
                                      Icons.error_rounded),
                                if (_successMsg != null || _errorMsg != null)
                                  const SizedBox(height: 16),

                                // Save Button
                                SizedBox(
                                  width: double.infinity,
                                  child: TajNetButton(
                                    onPressed: _save,
                                    isLoading: _isSaving,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.save_rounded,
                                            color: Colors.white, size: 20),
                                        SizedBox(width: 10),
                                        Text(
                                          'حفظ الإعدادات في Firestore',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.12),
            AppTheme.accentPurple.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 10),
              const Text(
                'كيف يعمل نظام التحديث؟',
                style: TextStyle(
                  color: AppTheme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow('🔴', 'إصدار المستخدم < الحد الأدنى',
              '← شاشة إلزامية لا يمكن تجاوزها'),
          _infoRow('🟡', 'إصدار المستخدم < الأخير (فوق الأدنى)',
              '← نافذة اقتراح يمكن تجاهلها'),
          _infoRow('🟢', 'إصدار المستخدم = الأخير', '← لا يظهر شيء'),
        ],
      ),
    );
  }

  Widget _infoRow(String emoji, String condition, String result) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 12.5, color: AppTheme.subtitleColor, height: 1.5),
                children: [
                  TextSpan(
                      text: condition,
                      style: const TextStyle(color: AppTheme.textColor)),
                  TextSpan(text: result),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildVersionField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required String helperText,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: AppTheme.subtitleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: _validateVersion,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: AppTheme.subtitleColor.withValues(alpha: 0.4)),
            filled: true,
            fillColor: color.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.7)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 6),
        Text(helperText,
            style:
                TextStyle(color: AppTheme.subtitleColor.withValues(alpha: 0.7), fontSize: 11.5)),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    String? helperText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.subtitleColor, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.subtitleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: AppTheme.textColor, fontSize: 14),
          validator: isRequired
              ? (val) => (val == null || val.trim().isEmpty) ? 'الحقل مطلوب' : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: AppTheme.subtitleColor.withValues(alpha: 0.4), fontSize: 13),
            filled: true,
            fillColor: AppTheme.surfaceColorElevated.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(helperText,
              style: TextStyle(
                  color: AppTheme.subtitleColor.withValues(alpha: 0.7),
                  fontSize: 11.5)),
        ],
      ],
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentGold.withValues(alpha: 0.08),
            AppTheme.surfaceColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview_rounded,
                  color: AppTheme.accentGold, size: 18),
              const SizedBox(width: 8),
              const Text(
                'معاينة الإعدادات الحالية',
                style: TextStyle(
                  color: AppTheme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _previewRow('min_version', _minVersionController.text, AppTheme.errorColor),
          _previewRow('latest_version', _latestVersionController.text, AppTheme.successColor),
          _previewRow(
              'download_url',
              _downloadUrlController.text.isEmpty ? '(فارغ)' : _downloadUrlController.text,
              AppTheme.primaryColor),
          _previewRow('Firestore path', 'app_config/version', AppTheme.subtitleColor),
        ],
      ),
    );
  }

  Widget _previewRow(String key, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColorElevated,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(key,
                style: const TextStyle(
                    color: AppTheme.subtitleColor,
                    fontSize: 11.5,
                    fontFamily: 'monospace')),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlert(String message, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}
