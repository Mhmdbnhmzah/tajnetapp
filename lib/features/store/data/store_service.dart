import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/config.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/bank_account.dart';
import '../../../core/models/card_item.dart';
import '../../../core/models/deposit_request.dart';
import '../../../core/services/notification_service.dart';

class StoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Bank Accounts ────────────────────────────────────────────────────────

  Stream<List<BankAccount>> streamActiveBankAccounts() {
    return _db
        .collection('network_bank_accounts')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BankAccount.fromFirestore(doc))
            .toList());
  }

  // ─── Package Color Cache (C-02 Optimization) ─────────────────────────────
  static Map<String, String>? _cachedPackageHexMap;
  static DateTime? _packageMapCacheTime;
  static const Duration _packageCacheDuration = Duration(minutes: 15);

  /// Helper to get or refresh package hex map with memory caching (prevents repeat Firestore queries)
  Future<Map<String, String>> _getPackageHexMap({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedPackageHexMap != null &&
        _packageMapCacheTime != null &&
        now.difference(_packageMapCacheTime!) < _packageCacheDuration) {
      return _cachedPackageHexMap!;
    }

    try {
      final pkgs = await _db.collection('packages').get();
      final map = <String, String>{};
      for (var pDoc in pkgs.docs) {
        final pData = pDoc.data();
        final pName = pData['priceText']?.toString() ?? '';
        final pHex = pData['colorHex']?.toString();
        if (pName.isNotEmpty && pHex != null && pHex.isNotEmpty) {
          map[pName] = pHex;
        }
      }
      _cachedPackageHexMap = map;
      _packageMapCacheTime = now;
      return map;
    } catch (e) {
      debugPrint('Error loading package hex map: $e');
      return _cachedPackageHexMap ?? {};
    }
  }

  // ─── Active Packages ──────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> streamActivePackages() {
    return _db
        .collection('packages')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      final list =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      // Proactively update in-memory packageHexMap cache
      final map = <String, String>{};
      for (var p in list) {
        final pName = p['priceText']?.toString() ?? '';
        final pHex = p['colorHex']?.toString();
        if (pName.isNotEmpty && pHex != null && pHex.isNotEmpty) {
          map[pName] = pHex;
        }
      }
      if (map.isNotEmpty) {
        _cachedPackageHexMap = map;
        _packageMapCacheTime = DateTime.now();
      }
      return list;
    });
  }

  // ─── Check Pending Deposit Request ─────────────────────────────────────────

  /// Checks if a user already has an active pending deposit request.
  Future<DepositRequest?> getPendingDepositRequest(String userId) async {
    try {
      final existingPending = await _db
          .collection('deposit_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingPending.docs.isNotEmpty) {
        return DepositRequest.fromFirestore(existingPending.docs.first);
      }
    } catch (e) {
      debugPrint('Error checking pending deposit request: $e');
    }
    return null;
  }

  // ─── Submit Deposit Request (receipt sent via WhatsApp) ────────────────────

  /// Creates a deposit request in Firestore.
  /// Throws an exception if the user already has a pending request.
  Future<void> submitDepositRequest({
    required String userId,
    required String userName,
    required String userPhone,
    required String userAccountNumber,
    required double amount,
  }) async {
    try {
      if (amount < AppConfig.minDepositAmount) {
        throw Exception(
            'الحد الأدنى لطلب شحن المحفظة هو ${AppConfig.minDepositAmount.toInt()} ريال');
      }

      // ✅ HIGH-02: Prevent duplicate pending requests from the same user
      final existingPending = await _db
          .collection('deposit_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingPending.docs.isNotEmpty) {
        throw Exception(
            'يوجد لديك طلب شحن سابق قيد المراجعة. يرجى انتظار معالجته قبل إرسال طلب جديد.');
      }

      final docRef = _db.collection('deposit_requests').doc();
      final newRequest = DepositRequest(
        id: docRef.id,
        userId: userId,
        userName: userName,
        userPhone: userPhone,
        userAccountNumber: userAccountNumber,
        amount: amount,
        status: 'pending',
        adminNote: '',
        createdAt: DateTime.now(),
      );

      await docRef.set(newRequest.toMap());

      // ✅ Notify all admins (in-app notification only; WhatsApp carries the receipt)
      await NotificationService().sendNotificationToAdmins(
        title: 'طلب شحن رصيد جديد 💳',
        body:
            'قام العميل "$userName" بطلب شحن رصيد بمبلغ $amount ريال (سيُرسل السند عبر واتساب)',
        type: 'deposit_new',
        extraData: {
          'userName': userName,
          'amount': amount.toString(),
        },
      );
    } catch (e) {
      debugPrint('Error submitting deposit request: $e');
      rethrow;
    }
  }

  // ─── Stream User's Deposit Requests ─────────────────────────────────────

  Stream<List<DepositRequest>> streamUserDepositRequests(String userId) {
    return _db
        .collection('deposit_requests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => DepositRequest.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ─── Buy Card — ATOMIC FINANCIAL TRANSACTION ─────────────────────────────

  Future<CardItem> buyCardWithBalance({
    required String userId,
    required String userName,
    required String profilePrice,
    required double priceValue,
  }) async {
    final userRef = _db.collection('users').doc(userId);

    // ✅ HIGH-01: Query an available card BEFORE the transaction (limit+1 for retry resilience)
    final availableCardsQuery = await _db
        .collection('card_inventory')
        .where('profilePrice', isEqualTo: profilePrice)
        .where('status', isEqualTo: 'available')
        .limit(1)
        .get();

    if (availableCardsQuery.docs.isEmpty) {
      throw Exception(
          'عفواً، لا توجد كروت متاحة حالياً لهذه الفئة في المخزون');
    }

    final cardDoc = availableCardsQuery.docs.first;
    final cardRef = _db.collection('card_inventory').doc(cardDoc.id);

    // Pre-fetch fallback package color before transaction using in-memory cache
    String? fallbackColorHex;
    try {
      final pkgMap = await _getPackageHexMap();
      fallbackColorHex = pkgMap[profilePrice];
    } catch (_) {}

    // Execute Atomic Firestore Transaction
    final boughtCard = await _db.runTransaction<CardItem>((transaction) async {
      // Step A: Read User Data inside transaction
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        throw Exception('المستخدم غير موجود');
      }

      final double currentBalance =
          (userSnapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;

      if (currentBalance < priceValue) {
        throw Exception(
            'رصيدك غير كافٍ لشراء هذا الكرت. يرجى شحن الرصيد أولاً.');
      }

      // Step B: Read & lock Card inside transaction (prevents race condition)
      final cardSnapshot = await transaction.get(cardRef);
      if (!cardSnapshot.exists ||
          cardSnapshot.data()?['status'] != 'available') {
        throw Exception(
            'الكارت المحدد لم يعد متاحاً، يرجى المحاولة مرة أخرى.');
      }

      // Step C: Atomically update balance and mark card as sold
      final double newBalance = currentBalance - priceValue;
      transaction.update(userRef, {'balance': newBalance});

      final now = DateTime.now();
      transaction.update(cardRef, {
        'status': 'sold',
        'soldToUserId': userId,
        'soldToUserName': userName,
        'soldAt': Timestamp.fromDate(now),
      });

      // Step D: Log transaction
      final logRef = _db.collection('transactions_log').doc();
      transaction.set(logRef, {
        'userId': userId,
        'userName': userName,
        'type': 'card_purchase',
        'amount': priceValue,
        'profilePrice': profilePrice,
        'cardId': cardDoc.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final String? cardColorHex =
          cardSnapshot.data()?['colorHex'] ?? fallbackColorHex;

      return CardItem(
        id: cardDoc.id,
        profilePrice: profilePrice,
        priceValue: priceValue,
        pin: cardSnapshot.data()?['pin'] ?? '',
        serialNumber: cardSnapshot.data()?['serialNumber'] ?? '',
        status: 'sold',
        colorHex: cardColorHex,
        soldToUserId: userId,
        soldToUserName: userName,
        soldAt: now,
        createdAt:
            (cardSnapshot.data()?['createdAt'] as Timestamp?)?.toDate() ?? now,
      );
    });

    // Notify admins after successful transaction
    try {
      await NotificationService().sendNotificationToAdmins(
        title: 'عملية شراء كرت 🛒',
        body:
            'قام العميل "$userName" بشراء كرت فئة "$profilePrice" بمبلغ $priceValue ريال',
        type: 'card_purchase',
        extraData: {
          'userName': userName,
          'amount': priceValue.toString(),
        },
      );
    } catch (e) {
      debugPrint('Error sending card purchase admin notification: $e');
    }

    return boughtCard;
  }

  // ─── Stream Purchased Cards for User ─────────────────────────────────────

  Stream<List<CardItem>> streamUserPurchasedCards(String userId) {
    return _db
        .collection('card_inventory')
        .where('soldToUserId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final cards = snapshot.docs.map((doc) => CardItem.fromFirestore(doc)).toList();

      // Only load package color mappings if there are cards missing colorHex
      final bool needsPackageColors = cards.any(
        (c) => c.colorHex == null || c.colorHex!.isEmpty,
      );

      Map<String, String> packageHexMap = {};
      if (needsPackageColors) {
        packageHexMap = await _getPackageHexMap();
      }

      final list = cards.map((card) {
        if (card.colorHex == null || card.colorHex!.isEmpty) {
          final mappedHex = packageHexMap[card.profilePrice];
          if (mappedHex != null) {
            return CardItem(
              id: card.id,
              profilePrice: card.profilePrice,
              priceValue: card.priceValue,
              pin: card.pin,
              serialNumber: card.serialNumber,
              status: card.status,
              colorHex: mappedHex,
              soldToUserId: card.soldToUserId,
              soldToUserName: card.soldToUserName,
              soldAt: card.soldAt,
              createdAt: card.createdAt,
            );
          }
        }
        return card;
      }).toList();

      list.sort((a, b) =>
          (b.soldAt ?? b.createdAt).compareTo(a.soldAt ?? a.createdAt));
      return list;
    });
  }

  // ─── Search User by Account Number ────────────────────────────────────────

  Future<AppUser?> findUserByAccountNumber(String accountNumber) async {
    final cleanAcc = accountNumber.trim();
    if (cleanAcc.isEmpty) return null;

    // ✅ HIGH-04: Use indexed Firestore query only — no full-collection fallback
    final query = await _db
        .collection('users')
        .where('accountNumber', isEqualTo: cleanAcc)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return AppUser.fromFirestore(query.docs.first);
    }

    return null;
  }

  // ─── Balance Transfer — ATOMIC FINANCIAL TRANSACTION ─────────────────────

  Future<void> transferBalance({
    required String senderUid,
    required String recipientAccountNumber,
    required double amount,
  }) async {
    if (amount <= 0) {
      throw Exception('يرجى إدخال مبلغ صحيح أكبر من صفر');
    }

    final recipient = await findUserByAccountNumber(recipientAccountNumber);
    if (recipient == null) {
      throw Exception('رقم الحساب الخاص بالعميل غير موجود!');
    }

    if (recipient.uid == senderUid) {
      throw Exception('لا يمكنك تحويل الرصيد لنفس الحساب!');
    }

    if (recipient.isBlocked) {
      throw Exception('عفواً، حساب المستلم متوقف حالياً');
    }

    final senderRef = _db.collection('users').doc(senderUid);
    final recipientRef = _db.collection('users').doc(recipient.uid);

    await _db.runTransaction((transaction) async {
      final senderDoc = await transaction.get(senderRef);
      if (!senderDoc.exists) {
        throw Exception('حسابك غير موجود');
      }

      final senderUser = AppUser.fromFirestore(senderDoc);
      if (senderUser.isBlocked) {
        throw Exception('حسابك موقوف، لا يمكنك إجراء التحويل');
      }

      if (senderUser.balance < amount) {
        throw Exception(
            'رصيدك غير كافٍ لإتمام هذه الحوالة! رصيدك الحالي: ${senderUser.balance.toStringAsFixed(1)} ريال');
      }

      final recipientDoc = await transaction.get(recipientRef);
      if (!recipientDoc.exists) {
        throw Exception('حساب المستلم غير موجود');
      }
      final double recipientCurrentBalance =
          (recipientDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;

      // Deduct from sender & add to recipient
      transaction.update(senderRef, {'balance': senderUser.balance - amount});
      transaction
          .update(recipientRef, {'balance': recipientCurrentBalance + amount});

      // Log for sender
      final senderLogRef = _db.collection('transactions_log').doc();
      transaction.set(senderLogRef, {
        'userId': senderUid,
        'userName': senderUser.name,
        'type': 'transfer_sent',
        'amount': amount,
        'recipientUid': recipient.uid,
        'recipientName': recipient.name,
        'recipientAccountNumber': recipient.accountNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Log for recipient
      final recipientLogRef = _db.collection('transactions_log').doc();
      transaction.set(recipientLogRef, {
        'userId': recipient.uid,
        'userName': recipient.name,
        'type': 'transfer_received',
        'amount': amount,
        'senderUid': senderUid,
        'senderName': senderUser.name,
        'senderAccountNumber': senderUser.accountNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Log admin notification inside transaction
      final notifRef = _db.collection('admin_notifications').doc();
      transaction.set(notifRef, {
        'title': 'تحويل رصيد 💸',
        'message':
            'قام العميل "${senderUser.name}" بتحويل مبلغ $amount ريال إلى "${recipient.name}"',
        'type': 'transfer',
        'amount': amount,
        'userName': senderUser.name,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    });

    // Push notification to recipient after transaction
    try {
      final senderDoc = await _db.collection('users').doc(senderUid).get();
      final senderName = senderDoc.data()?['name'] ?? 'مستخدم';
      await NotificationService().sendNotificationToUser(
        userId: recipient.uid,
        title: 'استلام حوالة رصيد 💸',
        body: 'وصلتك حوالة رصيد بقيمة $amount ريال من "$senderName"',
        type: 'transfer_received',
      );
    } catch (e) {
      debugPrint('Error sending notification to recipient: $e');
    }
  }
}
