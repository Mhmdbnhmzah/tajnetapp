import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/config.dart';

/// معالج الإشعارات في الخلفية - يجب أن يكون دالة علوية خارج الكلاس
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // عند استقبال إشعار والتطبيق في الخلفية أو مغلق تماماً
  debugPrint("📩 Background notification received: ${message.notification?.title}");
  // Firebase يعرض الإشعار تلقائياً في شريط النظام عندما يكون التطبيق مغلقاً
  // إذا كانت الرسالة تحتوي على notification payload فقط (لا data فقط)
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// قناة الإشعارات - يجب أن تتطابق مع AndroidManifest.xml
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'إشعارات شبكة تاج نت',
    description: 'قناة الإشعارات الفورية والمباشرة لتطبيق شبكة تاج نت',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      debugPrint('ℹ️ Push notifications are disabled on web.');
      return;
    }

    try {
      // 1. طلب إذن الإشعارات من المستخدم
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        announcement: false,
      );

      debugPrint('🔔 Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('⚠️ User denied notification permission!');
        return;
      }

      // 2. إعداد flutter_local_notifications لعرض الإشعارات عند فتح التطبيق (Foreground)
      const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('🔔 Local notification tapped: ${response.payload}');
        },
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
      );

      // 3. إنشاء القناة عالية الأولوية في أندرويد
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_channel);
      // التأكد من أن القناة مفعّلة وغير معطّلة من قبل المستخدم
      final channels = await androidPlugin?.getNotificationChannels();
      for (final ch in channels ?? []) {
        debugPrint('📢 Channel: ${ch.id} - importance: ${ch.importance}');
      }

      // 4. تهيئة خيارات الإشعارات عند فتح التطبيق (iOS)
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. تسجيل معالج الخلفية (Background Handler)
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 6. الاستماع للإشعارات عند فتح التطبيق (Foreground)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 7. الاستماع عند فتح التطبيق بالنقر على الإشعار (Background → Opened)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🟢 App opened from notification: ${message.notification?.title}');
      });

      // 8. التحقق من فتح التطبيق عبر إشعار عند كان مغلقاً تماماً (Terminated)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔵 App launched from terminated via notification: ${initialMessage.notification?.title}');
      }

      // 9. الاستماع لتحديثات التوكن لمرة واحدة عند تهيئة الخدمة
      _messaging.onTokenRefresh.listen((newToken) async {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;
        debugPrint('🔄 FCM Token refreshed: $newToken');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
              'fcmToken': newToken,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
      });

      // 10. حفظ FCM Token وتحديثه عند تسجيل الدخول
      await saveFCMToken();
      FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user != null) await saveFCMToken();
      });

      debugPrint('✅ NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
    }
  }

  /// معالج الإشعارات عند فتح التطبيق (Foreground)
  void _handleForegroundMessage(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notifications_enabled') ?? true;
      if (!enabled) {
        debugPrint('🔕 Foreground notification suppressed (notifications disabled by user)');
        return;
      }
    } catch (_) {}

    debugPrint('📩 Foreground message: ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    // عرض إشعار محلي لأن FCM لا يعرض الإشعار تلقائياً عند فتح التطبيق
    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/launcher_icon',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
          styleInformation: BigTextStyleInformation(notification.body ?? ''),
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// تفعيل الإشعارات للمستخدم
  Future<void> enableNotifications() async {
    try {
      await _messaging.subscribeToTopic('all_users');
      await saveFCMToken();
      debugPrint('🔔 Notifications enabled & subscribed to all_users');
    } catch (e) {
      debugPrint('❌ Error enabling notifications: $e');
    }
  }

  /// تعطيل الإشعارات للمستخدم
  Future<void> disableNotifications() async {
    try {
      await _messaging.unsubscribeFromTopic('all_users');
      await clearFCMToken();
      debugPrint('🔕 Notifications disabled & unsubscribed from all_users');
    } catch (e) {
      debugPrint('❌ Error disabling notifications: $e');
    }
  }

  /// مسح FCM Token من Firestore عند تسجيل الخروج لمنع وصول إشعارات الحساب القديم
  Future<void> clearFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': FieldValue.delete(),
        });
        // إزالة التوكن من قائمة المديرين إذا كان مديراً
        try {
          await FirebaseFirestore.instance
              .collection('app_config')
              .doc('admin_push_tokens')
              .update({
            user.uid: FieldValue.delete(),
          });
        } catch (_) {}
        debugPrint('🧹 FCM Token cleared for user ${user.uid}');
      }
    } catch (e) {
      debugPrint('❌ Error clearing FCM token: $e');
    }
  }

  /// مزامنة توكن المدير في app_config/admin_push_tokens
  Future<void> syncAdminFCMToken(String adminUid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('app_config')
            .doc('admin_push_tokens')
            .set({
          adminUid: token,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('🔑 Admin push token synced for $adminUid');
      }
    } catch (e) {
      debugPrint('Error syncing admin FCM token: $e');
    }
  }

  /// حفظ FCM Device Token في Firestore وتنظيفه من الأجهزة والحسابات القديمة
  Future<void> saveFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // الحصول على التوكن
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ FCM Token is null or empty!');
        return;
      }
      debugPrint('🔑 FCM Token: $token');

      final db = FirebaseFirestore.instance;

      // 1. إزالة هذا التوكن من أي حساب مستخدم آخر قديم سجل خروجه سابقاً على هذا الجهاز
      final duplicateDocs = await db
          .collection('users')
          .where('fcmToken', isEqualTo: token)
          .get();

      if (duplicateDocs.docs.isNotEmpty) {
        final batch = db.batch();
        bool hasOtherUsers = false;

        for (final doc in duplicateDocs.docs) {
          if (doc.id != user.uid) {
            batch.update(doc.reference, {'fcmToken': FieldValue.delete()});
            hasOtherUsers = true;
            debugPrint('🧹 Removing duplicate FCM token from old account: ${doc.id}');
          }
        }

        if (hasOtherUsers) {
          await batch.commit();
        }
      }

      // 2. حفظ التوكن للمستخدم الحالي
      await db.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

      // 3. إذا كان المستخدم مديراً، نحفظ التوكن في app_config/admin_push_tokens
      try {
        final userDoc = await db.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data()?['role'] == 'admin') {
          await db.collection('app_config').doc('admin_push_tokens').set({
            user.uid: token,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint('🔑 Admin push token recorded in app_config/admin_push_tokens');
        }
      } catch (e) {
        debugPrint('Note: could not update admin_push_tokens in saveFCMToken: $e');
      }
    } catch (e) {
      debugPrint('❌ Error saving FCM Token: $e');
    }
  }

  /// إرسال إشعار لمستخدم محدد عبر FCM HTTP v1 API
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    String type = 'deposit_update',
    Map<String, String>? extraData,
  }) async {
    try {
      final db = FirebaseFirestore.instance;

      // 1. حفظ الإشعار في Firestore (للعرض داخل التطبيق)
      await db.collection('user_notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. الحصول على FCM Token للمستخدم والتحقق من تفعيل الإشعارات
      final userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final isEnabled = userDoc.data()?['notificationsEnabled'] ?? true;
      if (!isEnabled) {
        debugPrint('🔕 User $userId disabled push notifications. Skipping FCM push.');
        return;
      }

      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.trim().isEmpty) {
        debugPrint('⚠️ No FCM token for user $userId');
        return;
      }

      debugPrint('📤 Sending FCM push to user $userId, token: ${fcmToken.substring(0, 20)}...');

      // 3. إرسال الإشعار عبر FCM HTTP v1 API
      await _sendFCMv1Push(
        fcmToken: fcmToken,
        title: title,
        body: body,
        data: {
          'type': type,
          'userId': userId,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          ...?extraData,
        },
      );
    } catch (e) {
      debugPrint('❌ Error sending notification to user $userId: $e');
    }
  }

  /// إرسال إشعار لجميع المديرين عبر FCM HTTP v1 API
  Future<void> sendNotificationToAdmins({
    required String title,
    required String body,
    String type = 'deposit_new',
    Map<String, String>? extraData,
  }) async {
    try {
      final db = FirebaseFirestore.instance;

      // 1. حفظ الإشعار في admin_notifications
      await db.collection('admin_notifications').add({
        'title': title,
        'message': body,
        'type': type,
        'userName': extraData?['userName'] ?? '',
        'amount': double.tryParse(extraData?['amount'] ?? '') ?? 0.0,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. الحصول على توكنات جميع المديرين
      final adminDocs = await db
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (final doc in adminDocs.docs) {
        final token = doc.data()['fcmToken'] as String?;
        if (token == null || token.trim().isEmpty) continue;

        debugPrint('📤 Sending FCM push to admin ${doc.id}');
        await _sendFCMv1Push(
          fcmToken: token,
          title: title,
          body: body,
          data: {
            'type': type,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            ...?extraData,
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending notification to admins: $e');
    }
  }

  /// إرسال إشعار لجميع المديرين عند تقديم طلب تسجيل جديد (يعمل بدون تسجيل دخول)
  Future<void> sendRegistrationNotificationToAdmins({
    required String userName,
    required String userPhone,
  }) async {
    try {
      final db = FirebaseFirestore.instance;

      // 1. حفظ الإشعار في admin_notifications (مسموح بدون تسجيل دخول بنوع registration_new)
      try {
        await db.collection('admin_notifications').add({
          'title': 'طلب إنشاء حساب جديد 👤',
          'message': 'طلب جديد من العميل $userName ($userPhone). يرجى المراجعة وتزويده برمز التفعيل.',
          'type': 'registration_new',
          'userName': userName,
          'amount': 0.0,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Admin in-app notification saved for new registration');
      } catch (e) {
        debugPrint('⚠️ Error saving registration admin notification: $e');
      }

      // 2. جلب توكنات المديرين من app_config/admin_push_tokens (مفتوح القراءة للجميع)
      final List<String> adminTokens = [];
      try {
        final tokensDoc = await db.collection('app_config').doc('admin_push_tokens').get();
        if (tokensDoc.exists) {
          final data = tokensDoc.data() ?? {};
          for (final entry in data.entries) {
            if (entry.key == 'lastUpdated') continue;
            final token = entry.value as String?;
            if (token != null && token.trim().isNotEmpty) {
              adminTokens.add(token.trim());
            }
          }
        }
      } catch (e) {
        debugPrint('Error reading admin_push_tokens: $e');
      }

      // الوضع الاحتياطي: إذا لم نجد توكنات في app_config، نحاول الاستعلام عن users
      if (adminTokens.isEmpty) {
        try {
          final adminDocs = await db.collection('users').where('role', isEqualTo: 'admin').get();
          for (final doc in adminDocs.docs) {
            final token = doc.data()['fcmToken'] as String?;
            if (token != null && token.trim().isNotEmpty) {
              adminTokens.add(token.trim());
            }
          }
        } catch (_) {}
      }

      debugPrint('🔔 Sending push notification to ${adminTokens.length} admin device(s)...');

      // 3. إرسال Push Notification لكل مدير عبر FCM HTTP v1 API
      for (final token in adminTokens) {
        await _sendFCMv1Push(
          fcmToken: token,
          title: 'طلب إنشاء حساب جديد 👤',
          body: 'طلب جديد من العميل $userName ($userPhone). يرجى تزويده برمز التفعيل.',
          data: {
            'type': 'registration_new',
            'userName': userName,
            'userPhone': userPhone,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending registration notification to admins: $e');
    }
  }

  /// إرسال Push Notification عبر FCM HTTP v1 API الرسمي والحديث
  Future<void> _sendFCMv1Push({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (fcmToken.trim().isEmpty) return;

    final clientEmail = AppConfig.fcmClientEmail.trim();
    final privateKey = AppConfig.fcmPrivateKey.trim();
    final projectId = AppConfig.fcmProjectId.trim();

    if (clientEmail.isEmpty || privateKey.isEmpty) {
      debugPrint('⚠️ FCM Service Account credentials are missing in AppConfig.');
      debugPrint('   → يرجى إضافة fcmClientEmail و fcmPrivateKey في lib/core/constants/config.dart');
      // الوضع الاحتياطي: حفظ الإشعار في Firestore فقط (بدون System Push)
      return;
    }

    try {
      // الحصول على Access Token عبر Service Account
      final credentials = ServiceAccountCredentials.fromJson({
        'type': 'service_account',
        'project_id': projectId,
        'client_email': clientEmail,
        'client_id': AppConfig.fcmClientId,
        'private_key': privateKey,
        'token_uri': 'https://oauth2.googleapis.com/token',
        'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
        'auth_provider_x509_cert_url': 'https://www.googleapis.com/oauth2/v1/certs',
      });

      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final authClient = await clientViaServiceAccount(credentials, scopes);

      try {
        final accessToken = authClient.credentials.accessToken.data;

        // إرسال الطلب لـ FCM HTTP v1 API
        final url = Uri.parse(
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
        );

        final payload = {
          'message': {
            'token': fcmToken,
            'notification': {
              'title': title,
              'body': body,
            },
            'android': {
              'priority': 'HIGH',          // HIGH أو NORMAL - مستوى الأولوية على مستوى الرسالة
              'notification': {
                'channel_id': 'high_importance_channel',
                'sound': 'default',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                'notification_priority': 'PRIORITY_MAX', // PRIORITY_MIN/LOW/DEFAULT/HIGH/MAX
                'visibility': 'PUBLIC',
              },
            },
            'apns': {
              'headers': {
                'apns-priority': '10',
              },
              'payload': {
                'aps': {
                  'sound': 'default',
                  'badge': 1,
                  'content-available': 1,
                },
              },
            },
            'data': data?.map((k, v) => MapEntry(k, v)) ?? {},
          },
        };

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          debugPrint('✅ FCM v1 Push sent successfully to ${fcmToken.substring(0, 20)}...');
        } else {
          debugPrint('❌ FCM v1 Push failed [${response.statusCode}]: ${response.body}');
        }
      } finally {
        authClient.close();
      }
    } catch (e) {
      debugPrint('❌ Error in _sendFCMv1Push: $e');
    }
  }

  /// عرض إشعار محلي (للاستخدام العام)
  Future<void> showLocalBanner({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/launcher_icon',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      payload: payload,
    );
  }
}

/// معالج الإشعارات في الخلفية (يجب أن يكون دالة علوية)
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  debugPrint('🔔 Background local notification tapped: ${response.payload}');
}
