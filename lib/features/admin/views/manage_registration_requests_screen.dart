import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/whatsapp_templates.dart';
import '../../../core/models/registration_request.dart';
import '../../../core/theme/theme.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../viewmodels/admin_viewmodel.dart';

class ManageRegistrationRequestsScreen extends StatelessWidget {
  const ManageRegistrationRequestsScreen({super.key});

  /// Generate a high-entropy, human-friendly random password without any fixed prefix
  String _generateSecurePassword() {
    final random = Random.secure();
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; // excludes I, O
    const lower = 'abcdefghjkmnpqrstuvwxyz'; // excludes l, o
    const digits = '23456789'; // excludes 1, 0
    const all = '$upper$lower$digits';

    // Ensure at least one from each category for security and strength
    final chars = <String>[
      upper[random.nextInt(upper.length)],
      lower[random.nextInt(lower.length)],
      digits[random.nextInt(digits.length)],
      // Fill remaining 5 characters randomly from the combined pool (total 8 chars)
      for (int i = 0; i < 5; i++) all[random.nextInt(all.length)],
    ];

    // Shuffle characters completely so structure and positions are unpredictable
    chars.shuffle(random);
    return chars.join();
  }

  String _cleanPhoneForWhatsApp(String phone) {
    return FirebaseAuthService.normalizePhone(phone);
  }

  // ─── Open WhatsApp App Directly to Specific Client Phone ───────────────
  Future<bool> _sendWhatsAppMessage(
      ScaffoldMessengerState messenger, String phone, String message) async {
    final cleanPhone = _cleanPhoneForWhatsApp(phone);
    final encoded = Uri.encodeComponent(message);

    // 1. Direct whatsapp:// URI (preferred for native app on Android & iOS)
    final directUrl = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encoded');
    // 2. wa.me universal link (associates with WhatsApp app on Android & iOS)
    final waMeUrl = Uri.parse('https://wa.me/$cleanPhone?text=$encoded');
    // 3. api.whatsapp.com standard API endpoint
    final apiUrl = Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone&text=$encoded');

    bool launched = false;

    // Fast direct launch attempts without blocking on canLaunchUrl
    for (final uri in [directUrl, waMeUrl, apiUrl]) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) break;
      } catch (e) {
        debugPrint('Failed to launch WhatsApp URL ($uri): $e');
      }
    }

    if (!launched) {
      // Copy message and code to clipboard as guaranteed fallback
      await Clipboard.setData(ClipboardData(text: message));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح تطبيق واتساب تلقائياً. تم نسخ نص الرسالة والكود إلى الحافظة!'),
          backgroundColor: AppTheme.warningColor,
          duration: Duration(seconds: 4),
        ),
      );
      return false;
    }

    return true;
  }

  void _showRejectDialog(
      BuildContext context, AdminViewModel adminViewModel, RegistrationRequest req) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.secondaryBackgroundColor,
        title: const Text('رفض طلب إنشاء الحساب',
            style: TextStyle(
                color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يرجى كتابة سبب الرفض لإبلاغ العميل عبر رسالة واتساب:'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                hintText: 'سبب الرفض (مثلاً: رقم الهاتف غير صحيح، بيانات مكررة)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.subtitleColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              final note = noteController.text.trim();
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final phone = req.phone;
              final rejectMsg = WhatsAppTemplates.registrationRejectionMessage(
                userName: req.name,
                reason: note,
              );

              // 1. Send rejection WhatsApp message
              await _sendWhatsAppMessage(
                messenger,
                phone,
                rejectMsg,
              );

              // 2. Reject in Firestore
              await adminViewModel.rejectRegistrationRequest(
                requestId: req.id,
                adminNote: note,
              );
            },
            child: const Text('تأكيد الرفض وإرسال واتساب'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminViewModel = Provider.of<AdminViewModel>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('طلبات إنشاء الحسابات 👥'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<List<RegistrationRequest>>(
            stream: adminViewModel.pendingRegistrationRequests,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'حدث خطأ في جلب طلبات التسجيل: ',
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                );
              }

              final requests = snapshot.data ?? [];
              if (requests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.how_to_reg_rounded,
                          size: 64, color: AppTheme.primaryColor),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد طلبات إنشاء حسابات جديدة قيد الانتظار 🌸',
                        style: TextStyle(
                            color: AppTheme.subtitleColor, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
                  return _buildRequestCard(context, adminViewModel, req);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(
      BuildContext context, AdminViewModel adminViewModel, RegistrationRequest req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Name + Code Badge ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded,
                          color: AppTheme.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        req.name,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_empty_rounded,
                        color: AppTheme.primaryColor, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'قيد الانتظار',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Client Info ───────────────────────────────────────────────
          _buildInfoRow(Icons.phone_rounded, 'رقم الجوال:', req.phone),
          if (req.email.isNotEmpty)
            _buildInfoRow(Icons.email_outlined, 'البريد:', req.email),
          if (req.bankName.isNotEmpty)
            _buildInfoRow(Icons.account_balance_rounded, 'البنك:', '${req.bankName} - ${req.bankAccountNumber}'),
          _buildInfoRow(
            Icons.access_time_rounded,
            'تاريخ الطلب:',
            '${req.createdAt.day}/${req.createdAt.month}/${req.createdAt.year}'
                ' – ${req.createdAt.hour}:${req.createdAt.minute.toString().padLeft(2, '0')}',
          ),

          const SizedBox(height: 16),

          // ── Action Buttons ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'موافقة وإنشاء الحساب وإرسال كلمة المرور',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                  onPressed: adminViewModel.isLoading
                      ? null
                      : () async {
                          HapticFeedback.mediumImpact();
                          final messenger = ScaffoldMessenger.of(context);
                          final phone = req.phone;
                          final clientName = req.name;

                          // 1. Generate secure random password
                          final generatedPassword = _generateSecurePassword();

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('⏳ جاري إنشاء حساب العميل $clientName في النظام...'),
                              backgroundColor: AppTheme.primaryColor,
                              duration: const Duration(seconds: 2),
                            ),
                          );

                          // 2. Provision account in Firebase Auth + Firestore
                          final success = await adminViewModel.provisionUserAccount(
                            request: req,
                            password: generatedPassword,
                          );

                          if (!success) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(adminViewModel.errorMessage ?? 'تعذر إنشاء الحساب للعميل. يرجى مراجعة البيانات.'),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                            return;
                          }

                          // 3. Build WhatsApp message with credentials
                          final activationMessage = WhatsAppTemplates.accountCreatedWithPasswordMessage(
                            userName: req.name,
                            phone: req.phone,
                            email: req.email,
                            password: generatedPassword,
                          );

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('✅ تم إنشاء الحساب بنجاح! جاري فتح واتساب للعميل $clientName...'),
                              backgroundColor: AppTheme.successColor,
                              duration: const Duration(seconds: 3),
                            ),
                          );

                          // 4. Launch WhatsApp directly
                          await _sendWhatsAppMessage(
                            messenger,
                            phone,
                            activationMessage,
                          );
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.errorColor),
                    foregroundColor: AppTheme.errorColor,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: adminViewModel.isLoading
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          _showRejectDialog(context, adminViewModel, req);
                        },
                  child: const Text('رفض', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.subtitleColor, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.subtitleColor, fontSize: 13)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                  color: AppTheme.textColor, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
