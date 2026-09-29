import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_user.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/theme.dart';
import '../viewmodels/admin_viewmodel.dart';

class AdminSendNotificationScreen extends StatefulWidget {
  const AdminSendNotificationScreen({super.key});

  @override
  State<AdminSendNotificationScreen> createState() =>
      _AdminSendNotificationScreenState();
}

class _AdminSendNotificationScreenState
    extends State<AdminSendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  bool _sendToAll = true; // true = All users, false = Specific user
  String? _selectedUserId;
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _submitNotification(List<AppUser> allUsers) async {
    if (!_formKey.currentState!.validate()) return;

    String? selectedUserName;
    if (!_sendToAll) {
      if (_selectedUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ يرجى اختيار العميل المستهدف أولاً'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      final matched = allUsers.where((u) => u.uid == _selectedUserId);
      if (matched.isNotEmpty) {
        selectedUserName = matched.first.name;
      }
    }

    setState(() => _isSending = true);

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    try {
      if (_sendToAll) {
        // Send in parallel to all non-admin users
        final clientUsers = allUsers.where((u) => !u.isAdmin).toList();
        await Future.wait(
          clientUsers.map((user) => NotificationService().sendNotificationToUser(
            userId: user.uid,
            title: title,
            body: body,
            type: 'admin_broadcast',
          )),
        );
      } else if (_selectedUserId != null) {
        // Send to specific selected user
        await NotificationService().sendNotificationToUser(
          userId: _selectedUserId!,
          title: title,
          body: body,
          type: 'admin_direct',
        );
      }

      if (mounted) {
        setState(() => _isSending = false);
        _titleController.clear();
        _bodyController.clear();

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppTheme.successColor),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 28),
                SizedBox(width: 10),
                Text('تم الإرسال بنجاح! 🎉', style: TextStyle(color: AppTheme.textColor, fontSize: 18)),
              ],
            ),
            content: Text(
              _sendToAll
                  ? 'تم إرسال الإشعار بنجاح لجميع العملاء! 🚀'
                  : 'تم إرسال الإشعار بنجاح إلى العميل "${selectedUserName ?? ''}"',
              style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending admin notification: $e');
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إرسال الإشعار حالياً. يرجى التأكد من الاتصال بالإنترنت والمحاولة مجدداً.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminVm = Provider.of<AdminViewModel>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: const TajNetAppBar(
        title: 'إرسال إشعارات للمستخدمين 📣',
      ),
      body: TajNetBackground(
        child: SafeArea(
          child: StreamBuilder<List<AppUser>>(
            stream: adminVm.allUsers,
            builder: (context, snapshot) {
              final allUsers = (snapshot.data ?? [])
                  .where((u) => !u.isAdmin)
                  .toList();

              final validSelectedUserId = allUsers.any((u) => u.uid == _selectedUserId) ? _selectedUserId : null;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Target Audience Selector Card
                      AppCard(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.15),
                            AppTheme.surfaceColorElevated,
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.group_work_rounded,
                                    color: AppTheme.primaryColor, size: 22),
                                SizedBox(width: 10),
                                Text(
                                  'تحديد الفئة المستهدفة للإشعار',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _sendToAll = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: _sendToAll
                                            ? AppTheme.primaryColor
                                                .withValues(alpha: 0.2)
                                            : AppTheme.surfaceColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _sendToAll
                                              ? AppTheme.primaryColor
                                              : AppTheme.borderColor,
                                          width: _sendToAll ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.campaign_rounded,
                                            size: 20,
                                            color: _sendToAll
                                                ? AppTheme.primaryColor
                                                : AppTheme.subtitleColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'جميع العملاء',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: _sendToAll
                                                  ? AppTheme.primaryColor
                                                  : AppTheme.subtitleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _sendToAll = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: !_sendToAll
                                            ? AppTheme.accentPurple
                                                .withValues(alpha: 0.2)
                                            : AppTheme.surfaceColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: !_sendToAll
                                              ? AppTheme.accentPurple
                                              : AppTheme.borderColor,
                                          width: !_sendToAll ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.person_rounded,
                                            size: 20,
                                            color: !_sendToAll
                                                ? AppTheme.accentPurple
                                                : AppTheme.subtitleColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'عميل محدد',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: !_sendToAll
                                                  ? AppTheme.accentPurple
                                                  : AppTheme.subtitleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // User Dropdown Selector if "Specific User" is chosen
                            if (!_sendToAll) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: AppTheme.accentPurple),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: validSelectedUserId,
                                    hint: const Text(
                                      'اختر العميل المستهدف من القائمة...',
                                      style: TextStyle(
                                          color: AppTheme.subtitleColor,
                                          fontSize: 13),
                                    ),
                                    isExpanded: true,
                                    dropdownColor: AppTheme.surfaceColorElevated,
                                    items: allUsers.map((user) {
                                      return DropdownMenuItem<String>(
                                        value: user.uid,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                user.name,
                                                style: const TextStyle(
                                                    color: AppTheme.textColor,
                                                    fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '(${user.accountNumber})',
                                              style: const TextStyle(
                                                  color: AppTheme.primaryColor,
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (userId) =>
                                        setState(() => _selectedUserId = userId),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      const SectionHeader(title: 'محتوى الرسالة والإشعار'),
                      const SizedBox(height: 12),

                      // Notification Title Input
                      TextFormField(
                        controller: _titleController,
                        style: const TextStyle(color: AppTheme.textColor),
                        decoration: InputDecoration(
                          hintText: 'عنوان الإشعار (مثال: تنبيه هام من الإدارة 🚀)',
                          hintStyle: TextStyle(
                              color: AppTheme.subtitleColor
                                  .withValues(alpha: 0.7)),
                          prefixIcon: const Icon(Icons.title_rounded,
                              color: AppTheme.primaryColor),
                          filled: true,
                          fillColor: AppTheme.surfaceColorElevated,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppTheme.borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppTheme.primaryColor, width: 2),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'يرجى كتابة عنوان الإشعار'
                            : null,
                      ),

                      const SizedBox(height: 16),

                      // Notification Body Input
                      TextFormField(
                        controller: _bodyController,
                        maxLines: 5,
                        style: const TextStyle(color: AppTheme.textColor),
                        decoration: InputDecoration(
                          hintText:
                              'اكتب نص الرسالة والإشعار الذي سيظهر للمستخدم في شاشة التنبيهات...',
                          hintStyle: TextStyle(
                              color: AppTheme.subtitleColor
                                  .withValues(alpha: 0.7)),
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: AppTheme.surfaceColorElevated,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppTheme.borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppTheme.primaryColor, width: 2),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'يرجى كتابة نص الرسالة'
                            : null,
                      ),

                      const SizedBox(height: 28),

                      // Send Button
                      TajNetButton(
                        isLoading: _isSending,
                        onPressed: () => _submitNotification(allUsers),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              _sendToAll
                                  ? 'إرسال الإشعار لجميع العملاء 📣'
                                  : 'إرسال الإشعار للعميل المحدد 📩',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
