import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/admin_notification.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/bank_account.dart';
import '../../../core/models/card_item.dart';
import '../../../core/models/deposit_request.dart';
import '../../../core/models/registration_request.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/data/firebase_auth_service.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Stream All Pending Deposit Requests (Client-side sorted to avoid missing Firestore index errors)
  Stream<List<DepositRequest>> streamPendingDepositRequests() {
    return _db
        .collection('deposit_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final list = <DepositRequest>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(DepositRequest.fromFirestore(doc));
        } catch (e) {
          // Skip invalid document format instead of failing whole stream
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Stream All Deposit Requests (History)
  Stream<List<DepositRequest>> streamAllDepositRequests() {
    return _db
        .collection('deposit_requests')
        .snapshots()
        .map((snapshot) {
      final list = <DepositRequest>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(DepositRequest.fromFirestore(doc));
        } catch (e) {
          // Skip invalid document format instead of failing whole stream
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // 2. ATOMIC FINANCIAL TRANSACTION: Approve Deposit Request & Credit User Balance
  Future<void> approveDepositRequest({
    required String requestId,
    required String userId,
    required double amount,
    String adminNote = '',
  }) async {
    final requestRef = _db.collection('deposit_requests').doc(requestId);
    final userRef = _db.collection('users').doc(userId);

    await _db.runTransaction((transaction) async {
      // Step A: Verify request status inside transaction
      final requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists) {
        throw Exception('طلب الشحن غير موجود');
      }

      final String currentStatus =
          requestSnapshot.data()?['status'] ?? 'pending';
      if (currentStatus != 'pending') {
        throw Exception('تمت معالجة هذا الطلب سابقاً!');
      }

      // Step B: Get User profile inside transaction
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        throw Exception('حساب العميل غير موجود');
      }

      final double currentBalance =
          (userSnapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      final double newBalance = currentBalance + amount;

      // Step C: Atomically update user balance and mark request as approved
      transaction.update(userRef, {'balance': newBalance});

      final now = DateTime.now();
      transaction.update(requestRef, {
        'status': 'approved',
        'adminNote': adminNote,
        'processedAt': Timestamp.fromDate(now),
      });

      // Step D: Log transaction
      final logRef = _db.collection('transactions_log').doc();
      transaction.set(logRef, {
        'userId': userId,
        'type': 'deposit_approved',
        'amount': amount,
        'requestId': requestId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    // Step E: Send targeted FCM notification ONLY to THAT client
    await NotificationService().sendNotificationToUser(
      userId: userId,
      title: 'تمت الموافقة على طلب الشحن ✅',
      body: 'تمت إضافة مبلغ ${amount.toStringAsFixed(1)} ريال إلى محفظتك بنجاح! 🎉',
      type: 'deposit_approved',
    );
  }

  // 3. Reject Deposit Request
  Future<void> rejectDepositRequest({
    required String requestId,
    required String userId,
    required double amount,
    String adminNote = '',
  }) async {
    await _db.collection('deposit_requests').doc(requestId).update({
      'status': 'rejected',
      'adminNote': adminNote.trim(),
      'processedAt': FieldValue.serverTimestamp(),
    });

    // Send targeted FCM notification ONLY to THAT client
    await NotificationService().sendNotificationToUser(
      userId: userId,
      title: 'تم رفض طلب الشحن ❌',
      body: 'نأسف، تم رفض طلب شحن الرصيد بمبلغ ${amount.toStringAsFixed(1)} ريال. ${adminNote.trim().isNotEmpty ? "السبب: ${adminNote.trim()}" : ""}',
      type: 'deposit_rejected',
    );
  }

  // 4. Bulk Upload Cards
  Future<int> addCardsBulk(List<Map<String, dynamic>> cardsData) async {
    if (cardsData.isEmpty) return 0;
    int addedCount = 0;
    const chunkSize = 450;

    for (int i = 0; i < cardsData.length; i += chunkSize) {
      final chunk = cardsData.sublist(
        i,
        (i + chunkSize > cardsData.length) ? cardsData.length : i + chunkSize,
      );
      final batch = _db.batch();

      for (var card in chunk) {
        final docRef = _db.collection('card_inventory').doc();
        batch.set(docRef, {
          'profilePrice': card['profilePrice'],
          'priceValue': card['priceValue'],
          'pin': card['pin'],
          'serialNumber': card['serialNumber'] ?? '',
          'status': 'available',
          'soldToUserId': null,
          'soldToUserName': null,
          'soldAt': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
        addedCount++;
      }
      await batch.commit();
    }

    return addedCount;
  }

  // 5. Manage Network Bank Accounts
  Stream<List<BankAccount>> streamAllBankAccounts() {
    return _db.collection('network_bank_accounts').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => BankAccount.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> addBankAccount(BankAccount account) async {
    final docRef = _db.collection('network_bank_accounts').doc();
    await docRef.set(account.toMap());
  }

  Future<void> updateBankAccount(BankAccount account) async {
    await _db.collection('network_bank_accounts').doc(account.id).update(account.toMap());
  }

  Future<void> deleteBankAccount(String accountId) async {
    await _db.collection('network_bank_accounts').doc(accountId).delete();
  }

  Future<String?> uploadBankLogo(Uint8List bytes, String filename) async {
    try {
      final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'jpg';
      final cleanExt = (ext == 'png') ? 'png' : 'jpeg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('bank_logos')
          .child('${DateTime.now().millisecondsSinceEpoch}.$cleanExt');

      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$cleanExt'),
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Firebase Storage upload failed, fallback to base64: $e');
      final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'jpg';
      final cleanExt = (ext == 'png') ? 'png' : 'jpeg';
      final base64String = base64Encode(bytes);
      return 'data:image/$cleanExt;base64,$base64String';
    }
  }

  // 6. Manage All Users
  Stream<List<AppUser>> streamAllUsers() {
    return _db
        .collection('users')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Reset user's Wallet Security PIN
  Future<void> resetUserWalletPin(String uid) async {
    await _db.collection('users').doc(uid).update({
      'walletPin': FieldValue.delete(),
    });
  }

  // Toggle user block status
  Future<void> toggleUserBlockStatus(String userId, bool isBlocked) async {
    await _db.collection('users').doc(userId).update({
      'isBlocked': isBlocked,
    });
  }

  // 8. Manage Packages
  Stream<List<Map<String, dynamic>>> streamAllPackages() {
    return _db
        .collection('packages')
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  Future<void> addPackage(Map<String, dynamic> data) async {
    final docRef = _db.collection('packages').doc();
    data['createdAt'] = FieldValue.serverTimestamp();
    await docRef.set(data);
  }

  Future<void> updatePackage(String packageId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('packages').doc(packageId).update(data);
  }

  Future<void> deletePackage(String packageId) async {
    await _db.collection('packages').doc(packageId).delete();
  }

  // 9. Card Inventory Stream & Management
  Stream<List<CardItem>> streamAllCards() {
    return _db.collection('card_inventory').snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => CardItem.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> deleteCard(String cardId) async {
    await _db.collection('card_inventory').doc(cardId).delete();
  }

  // 9. Delete Available Cards For Profile
  Future<int> deleteAvailableCardsForProfile(String profilePrice) async {
    final query = await _db
        .collection('card_inventory')
        .where('profilePrice', isEqualTo: profilePrice)
        .where('status', isEqualTo: 'available')
        .get();

    const chunkSize = 450;
    for (int i = 0; i < query.docs.length; i += chunkSize) {
      final chunk = query.docs.sublist(
        i,
        (i + chunkSize > query.docs.length) ? query.docs.length : i + chunkSize,
      );
      final batch = _db.batch();
      for (var doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    return query.docs.length;
  }

  // 10. Admin Notifications Stream & Methods
  Stream<List<AdminNotification>> streamAdminNotifications() {
    return _db
        .collection('admin_notifications')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AdminNotification.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> addNotification({
    required String title,
    required String message,
    required String type,
    double amount = 0.0,
    String userName = '',
  }) async {
    final docRef = _db.collection('admin_notifications').doc();
    await docRef.set({
      'title': title,
      'message': message,
      'type': type,
      'amount': amount,
      'userName': userName,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  // Stream All Sold Cards for Analytics
  Stream<List<CardItem>> streamSoldCards() {
    return _db
        .collection('card_inventory')
        .where('status', isEqualTo: 'sold')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => CardItem.fromFirestore(doc)).toList();
      list.sort((a, b) => (b.soldAt ?? b.createdAt).compareTo(a.soldAt ?? a.createdAt));
      return list;
    });
  }

  // Stream All Approved Deposit Requests for Analytics
  Stream<List<DepositRequest>> streamApprovedDeposits() {
    return _db
        .collection('deposit_requests')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => DepositRequest.fromFirestore(doc)).toList();
      list.sort((a, b) => (b.processedAt ?? b.createdAt).compareTo(a.processedAt ?? a.createdAt));
      return list;
    });
  }

  // 11. Stream Pending Registration Requests
  Stream<List<RegistrationRequest>> streamPendingRegistrationRequests() {
    return _db
        .collection('registration_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final list = <RegistrationRequest>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(RegistrationRequest.fromFirestore(doc));
        } catch (_) {}
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Generate a unique 6-digit accountNumber that does not already exist
  Future<String> _generateUniqueAccountNumber(String uid) async {
    final hash = uid.codeUnits.fold(0, (int acc, int c) => acc + c);
    final candidate = (100000 + (hash.abs() % 900000)).toString();

    final existing = await _db
        .collection('users')
        .where('accountNumber', isEqualTo: candidate)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) return candidate;

    return (100000 + DateTime.now().microsecondsSinceEpoch % 900000).toString();
  }

  /// Creates the user account in Firebase Auth using a secondary app (to preserve Admin session)
  /// and writes the user document to Firestore atomically.
  Future<bool> provisionUserAccount({
    required RegistrationRequest request,
    required String password,
  }) async {
    FirebaseApp? secondaryApp;
    final normalizedPhone = FirebaseAuthService.normalizePhone(request.phone);

    try {
      final appName = 'UserProvisionApp_${DateTime.now().millisecondsSinceEpoch}';
      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final userCred = await secondaryAuth.createUserWithEmailAndPassword(
        email: request.email.trim(),
        password: password,
      );

      final uid = userCred.user?.uid;
      if (uid == null) {
        throw Exception('failed_to_create_user');
      }

      final accountNumber = await _generateUniqueAccountNumber(uid);
      final userRef = _db.collection('users').doc(uid);
      final phoneRef = _db.collection('phone_registry').doc(normalizedPhone);
      final reqRef = _db.collection('registration_requests').doc(request.id);

      await _db.runTransaction((txn) async {
        final phoneSnap = await txn.get(phoneRef);
        if (phoneSnap.exists) {
          throw Exception('phone_already_registered');
        }

        final newUser = AppUser(
          uid: uid,
          name: request.name.trim(),
          email: request.email.trim(),
          phone: normalizedPhone,
          role: 'user',
          balance: 0.0,
          bankName: request.bankName.trim(),
          bankAccountName: request.bankAccountName.trim(),
          bankAccountNumber: request.bankAccountNumber.trim(),
          accountNumber: accountNumber,
          createdAt: DateTime.now(),
        );

        txn.set(userRef, newUser.toMap());
        txn.set(phoneRef, {
          'uid': uid,
          'registeredAt': FieldValue.serverTimestamp(),
        });
        txn.update(reqRef, {
          'status': 'completed',
          'approvedAt': FieldValue.serverTimestamp(),
        });
      });

      await secondaryAuth.signOut();
      return true;
    } catch (e) {
      debugPrint('Error provisioning user account: $e');
      rethrow;
    } finally {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }
    }
  }

  // Approve Registration Request (Admin approved status only)
  Future<bool> approveRegistrationRequest(String requestId) async {
    try {
      await _db.collection('registration_requests').doc(requestId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Reject Registration Request
  Future<bool> rejectRegistrationRequest({
    required String requestId,
    required String adminNote,
  }) async {
    try {
      await _db.collection('registration_requests').doc(requestId).update({
        'status': 'rejected',
        'adminNote': adminNote,
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
