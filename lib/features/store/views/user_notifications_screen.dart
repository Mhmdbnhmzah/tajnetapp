import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_user.dart';
import '../../../core/theme/theme.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

class UserNotificationsScreen extends StatefulWidget {
  const UserNotificationsScreen({super.key});

  @override
  State<UserNotificationsScreen> createState() => _UserNotificationsScreenState();
}

class _UserNotificationsScreenState extends State<UserNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // عند فتح شاشة الإشعارات، نقوم بتعليم جميع الإشعارات كـ "مقروءة"
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllAsRead());
  }

  Future<void> _markAllAsRead() async {
    final user = context.read<AuthViewModel>().appUser;
    if (user == null) return;

    try {
      final unreadDocs = await FirebaseFirestore.instance
          .collection('user_notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      if (unreadDocs.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthViewModel, AppUser?>((vm) => vm.appUser);
    final String userId = user?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: const TajNetAppBar(
        title: 'الإشعارات والتنويهات 🔔',
      ),
      body: TajNetBackground(
        child: SafeArea(
          child: userId.isEmpty
              ? const Center(
                  child: Text(
                    'يرجى تسجيل الدخول لعرض الإشعارات',
                    style: TextStyle(color: AppTheme.subtitleColor),
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('user_notifications')
                      .where('userId', isEqualTo: userId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_rounded,
                              size: 64,
                              color: AppTheme.subtitleColor,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'لا توجد إشعارات حالياً 🌸',
                              style: TextStyle(
                                color: AppTheme.subtitleColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Client-side sort by createdAt descending
                    final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
                    sortedDocs.sort((a, b) {
                      final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                      final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                      if (aTime == null || bTime == null) return 0;
                      return bTime.compareTo(aTime);
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sortedDocs.length,
                      itemBuilder: (context, index) {
                        final data = sortedDocs[index].data() as Map<String, dynamic>;
                        final String title = data['title'] ?? 'إشعار جديد';
                        final String body = data['body'] ?? '';
                        final String type = data['type'] ?? 'info';
                        final bool isRead = data['isRead'] ?? false;
                        final Timestamp? ts = data['createdAt'] as Timestamp?;
                        final DateTime date = ts?.toDate() ?? DateTime.now();

                        IconData iconData = Icons.notifications_rounded;
                        Color iconColor = AppTheme.primaryColor;

                        if (type == 'deposit_approved') {
                          iconData = Icons.check_circle_rounded;
                          iconColor = AppTheme.successColor;
                        } else if (type == 'deposit_rejected') {
                          iconData = Icons.cancel_rounded;
                          iconColor = AppTheme.errorColor;
                        } else if (type == 'admin_broadcast' || type == 'admin_direct') {
                          iconData = Icons.campaign_rounded;
                          iconColor = AppTheme.accentGold;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            color: isRead
                                ? AppTheme.surfaceColorElevated
                                : AppTheme.primaryColor.withValues(alpha: 0.07),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Unread indicator dot
                                if (!isRead)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 0, right: 0, top: 6),
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsetsDirectional.only(end: 8, top: 4),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(width: 16),

                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: isRead ? 0.08 : 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                    border: isRead
                                        ? null
                                        : Border.all(color: iconColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Icon(iconData, color: iconColor, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                                color: isRead ? AppTheme.textColor : AppTheme.primaryColor,
                                              ),
                                            ),
                                          ),
                                          if (!isRead)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                                                ),
                                              ),
                                              child: const Text(
                                                'جديد',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        body,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.subtitleColor,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.subtitleColor.withValues(alpha: 0.7),
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
                    );
                  },
                ),
        ),
      ),
    );
  }
}
