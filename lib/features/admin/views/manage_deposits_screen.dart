import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/whatsapp_templates.dart';
import '../../../core/models/deposit_request.dart';
import '../../../core/theme/theme.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../viewmodels/admin_viewmodel.dart';

class ManageDepositsScreen extends StatelessWidget {
  const ManageDepositsScreen({super.key});

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
      // Copy message to clipboard as guaranteed fallback
      await Clipboard.setData(ClipboardData(text: message));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح تطبيق واتساب تلقائياً. تم نسخ نص الرسالة إلى الحافظة!'),
          backgroundColor: AppTheme.warningColor,
          duration: Duration(seconds: 4),
        ),
      );
      return false;
    }

    return true;
  }

  // ─── Open WhatsApp to view the client's receipt ───────────────────────────
  Future<void> _openWhatsAppWithClient(
      BuildContext context, DepositRequest req) async {
    final messenger = ScaffoldMessenger.of(context);
    await _sendWhatsAppMessage(
      messenger,
      req.userPhone,
      WhatsAppTemplates.clientInquiryMessage(
        userName: req.userName,
        amount: req.amount,
        accountNumber: req.userAccountNumber,
      ),
    );
  }

  void _showRejectDialog(
      BuildContext context, AdminViewModel adminViewModel, DepositRequest req) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.secondaryBackgroundColor,
        title: const Text('رفض طلب الشحن',
            style: TextStyle(
                color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يرجى كتابة سبب الرفض لإبلاغ العميل عبر واتساب:'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                hintText: 'سبب الرفض (مثلاً: السند غير واضح، المبلغ غير مطابق)',
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
              final userPhone = req.userPhone;
              final rejectMsg = WhatsAppTemplates.depositRejectionMessage(
                userName: req.userName,
                accountNumber: req.userAccountNumber,
                amount: req.amount,
                reason: note,
              );

              // 1. Reject in Firestore first (ensures database integrity)
              final success = await adminViewModel.rejectDeposit(
                requestId: req.id,
                userId: req.userId,
                amount: req.amount,
                adminNote: note,
              );

              // 2. Only if Firestore rejection succeeded, notify client via WhatsApp
              if (success) {
                await _sendWhatsAppMessage(
                  messenger,
                  userPhone,
                  rejectMsg,
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(adminViewModel.errorMessage ?? 'تعذر رفض الطلب حالياً.'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
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
      appBar: AppBar(
        title: const Text('مراجعة طلبات الشحن'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<List<DepositRequest>>(
            stream: adminViewModel.pendingDepositRequests,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return RefreshIndicator(
                  color: AppTheme.primaryColor,
                  backgroundColor: AppTheme.surfaceColor,
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 400));
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 54, color: AppTheme.errorColor),
                            const SizedBox(height: 14),
                            Text(
                              'حدث خطأ في جلب طلبات الشحن:\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppTheme.subtitleColor, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                return RefreshIndicator(
                  color: AppTheme.primaryColor,
                  backgroundColor: AppTheme.surfaceColor,
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 400));
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 64, color: AppTheme.primaryColor),
                            SizedBox(height: 16),
                            Text(
                              'لا توجد طلبات شحن قيد الانتظار حالياً 🌸',
                              style: TextStyle(
                                  color: AppTheme.subtitleColor, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                color: AppTheme.primaryColor,
                backgroundColor: AppTheme.surfaceColor,
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 400));
                },
                child: ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return _buildRequestCard(context, adminViewModel, req);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(
      BuildContext context, AdminViewModel adminViewModel, DepositRequest req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Name + Amount ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                req.userName,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.accentGold.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${req.amount} ريال',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentGold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Client Info ───────────────────────────────────────────────
          _buildInfoRow(Icons.phone_rounded, 'رقم الهاتف:', req.userPhone),
          _buildInfoRow(Icons.badge_rounded, 'رقم الحساب:', req.userAccountNumber),
          _buildInfoRow(
            Icons.access_time_rounded,
            'تاريخ الطلب:',
            '${req.createdAt.day}/${req.createdAt.month}/${req.createdAt.year}'
                ' – ${req.createdAt.hour}:${req.createdAt.minute.toString().padLeft(2, '0')}',
          ),

          const SizedBox(height: 14),

          // ── WhatsApp Button: view receipt from client ─────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF25D366)),
                foregroundColor: const Color(0xFF25D366),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366)),
              label: Text('فتح محادثة واتساب مع ${req.userName}'),
              onPressed: () => _openWhatsAppWithClient(context, req),
            ),
          ),

          const SizedBox(height: 14),

          // ── Action Buttons ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text('قبول وإضافة الرصيد',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: adminViewModel.isLoading
                      ? null
                      : () async {
                          HapticFeedback.mediumImpact();
                          final messenger = ScaffoldMessenger.of(context);
                          final userPhone = req.userPhone;
                          final clientName = req.userName;
                          final approvalMsg = WhatsAppTemplates.depositApprovalMessage(
                            userName: req.userName,
                            accountNumber: req.userAccountNumber,
                            amount: req.amount,
                          );

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                  '⏳ جاري اعتماد طلب العميل $clientName وإضافة ${req.amount} ريال...'),
                              backgroundColor: AppTheme.primaryColor,
                              duration: const Duration(seconds: 2),
                            ),
                          );

                          // 1. Approve in Firestore first (Atomic financial transaction)
                          final success = await adminViewModel.approveDeposit(
                            requestId: req.id,
                            userId: req.userId,
                            amount: req.amount,
                          );

                          // 2. Only if Firestore approval succeeded, open WhatsApp to notify client
                          if (success) {
                            await _sendWhatsAppMessage(
                              messenger,
                              userPhone,
                              approvalMsg,
                            );
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(adminViewModel.errorMessage ?? 'تعذر اعتماد طلب الشحن حالياً.'),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.errorColor),
                    foregroundColor: AppTheme.errorColor,
                  ),
                  icon: const Icon(Icons.cancel),
                  label: const Text('رفض الطلب'),
                  onPressed: adminViewModel.isLoading
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          _showRejectDialog(context, adminViewModel, req);
                        },
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.subtitleColor, size: 15),
          const SizedBox(width: 6),
          Text('$label ',
              style: const TextStyle(
                  color: AppTheme.subtitleColor, fontSize: 13)),
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
