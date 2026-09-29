import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/app_user.dart';
import '../../../core/services/notification_service.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // ── PIN Security Helpers ────────────────────────────────────────────────
  /// SHA-256 hash for Wallet PIN before storing in Firestore
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  /// Generate a unique 6-digit accountNumber that does not already exist
  Future<String> _generateUniqueAccountNumber(String uid) async {
    // Deterministic hash from UID (avoids clock collisions)
    final hash = uid.codeUnits.fold(0, (int acc, int c) => acc + c);
    final candidate = (100000 + (hash.abs() % 900000)).toString();

    final existing = await _db
        .collection('users')
        .where('accountNumber', isEqualTo: candidate)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) return candidate;

    // Fallback: microsecond-based to avoid second collision
    return (100000 + DateTime.now().microsecondsSinceEpoch % 900000).toString();
  }

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Stream current user profile from Firestore
  Stream<AppUser?> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    });
  }

  // Get user profile once
  Future<AppUser?> getUserProfile(String uid, {bool forceServer = false}) async {
    try {
      final doc = await _db.collection('users').doc(uid).get(
        forceServer ? const GetOptions(source: Source.server) : null,
      );
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint("Error getting user profile: $e");
    }
    return null;
  }

  /// Normalize any Yemeni phone number format to 967XXXXXXXXX
  static String normalizePhone(String phone) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String clean = phone.trim();
    for (int i = 0; i < 10; i++) {
      clean = clean.replaceAll(arabicDigits[i], englishDigits[i]);
      clean = clean.replaceAll(persianDigits[i], englishDigits[i]);
    }
    clean = clean.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    // Remove leading zeros: 0770... → 770...
    if (clean.startsWith('00967')) clean = clean.substring(2);   // 00967... → 967...
    if (clean.startsWith('0'))     clean = clean.substring(1);   // 0770... → 770...
    // Add country code if missing (9-digit Yemeni numbers start with 7)
    if (clean.length == 9 && clean.startsWith('7')) clean = '967$clean';
    return clean;
  }

  // Find user by phone number (searches all possible format variants)
  Future<AppUser?> findUserByPhone(String phone) async {
    if (phone.trim().isEmpty) return null;
    final normalized = normalizePhone(phone);

    // Build all possible stored variants of this number
    final variants = <String>{normalized};
    // Without country code (9 digits): 967770... → 770...
    if (normalized.startsWith('967') && normalized.length == 12) {
      variants.add(normalized.substring(3));          // 770XXXXXXX
      variants.add('0${normalized.substring(3)}');    // 0770XXXXXXX
    }

    for (final variant in variants) {
      try {
        final query = await _db
            .collection('users')
            .where('phone', isEqualTo: variant)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          return AppUser.fromFirestore(query.docs.first);
        }
      } catch (e) {
        debugPrint('Error finding user by phone variant "$variant": $e');
        // Don't rethrow - unauthenticated reads may be rejected by Firestore rules
      }
    }
    return null;
  }

  // ── Phone Registry (Industry-Standard Unique Phone Pattern) ──────────────
  // Collection: phone_registry/{normalizedPhone} → {uid, registeredAt}
  // Document-ID reads work without auth (unlike collection queries).
  // Firestore rule needed: match /phone_registry/{phone} { allow read: if true; }

  /// Check if a phone number already belongs to an existing user account (checks phone_registry & users)
  Future<bool> isPhoneRegisteredInUsers(String phone) async {
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) return false;

    // 1. Check phone_registry collection (direct document read)
    try {
      final doc = await _db.collection('phone_registry').doc(normalized).get();
      if (doc.exists) {
        debugPrint('Phone $normalized found in phone_registry');
        return true;
      }
    } catch (e) {
      debugPrint('phone_registry check error: $e');
    }

    // 2. Check users collection across all phone format variants (allowed via limit <= 2)
    final existingUser = await findUserByPhone(normalized);
    if (existingUser != null) {
      debugPrint('Phone $normalized found in users collection for user: ${existingUser.uid}');
      // Auto-sync into phone_registry for faster future reads
      try {
        await _db.collection('phone_registry').doc(normalized).set({
          'uid': existingUser.uid,
          'registeredAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
      return true;
    }

    return false;
  }

  /// Check if a phone number has an active registration request (pending or approved)
  Future<bool> hasActiveRegistrationRequest(String phone) async {
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) return false;

    // Check direct doc by normalized phone
    try {
      final reqDoc = await _db.collection('registration_requests').doc(normalized).get();
      if (reqDoc.exists) {
        final st = reqDoc.data()?['status'] ?? '';
        if (st == 'pending' || st == 'approved') {
          debugPrint('Phone $normalized has active request with status $st');
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error checking registration_requests doc: $e');
    }

    // Query registration_requests across variants in case older requests had auto-generated IDs
    final variants = <String>{normalized};
    if (normalized.startsWith('967') && normalized.length == 12) {
      final local9 = normalized.substring(3);
      variants.add(local9);
      variants.add('0$local9');
    }
    for (final v in variants) {
      try {
        final q = await _db
            .collection('registration_requests')
            .where('phone', isEqualTo: v)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          final st = q.docs.first.data()['status'] ?? '';
          if (st == 'pending' || st == 'approved') {
            debugPrint('Phone variant $v has active request with status $st');
            return true;
          }
        }
      } catch (e) {
        debugPrint('Error querying registration_requests for variant $v: $e');
      }
    }

    return false;
  }

  /// Get active registration request details if any exists (pending or approved)
  Future<Map<String, dynamic>?> getRegistrationRequest(String phone) async {
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) return null;

    // 1. Check direct doc by normalized phone
    try {
      final reqDoc = await _db.collection('registration_requests').doc(normalized).get();
      if (reqDoc.exists) {
        final data = reqDoc.data() ?? {};
        final st = data['status'] ?? '';
        if (st == 'pending' || st == 'approved') {
          return {'id': reqDoc.id, ...data};
        }
      }
    } catch (e) {
      debugPrint('Error getting registration_requests doc: $e');
    }

    // 2. Query across variants
    final variants = <String>{normalized};
    if (normalized.startsWith('967') && normalized.length == 12) {
      final local9 = normalized.substring(3);
      variants.add(local9);
      variants.add('0$local9');
    }
    for (final v in variants) {
      try {
        final q = await _db
            .collection('registration_requests')
            .where('phone', isEqualTo: v)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          final doc = q.docs.first;
          final data = doc.data();
          final st = data['status'] ?? '';
          if (st == 'pending' || st == 'approved') {
            return {'id': doc.id, ...data};
          }
        }
      } catch (e) {
        debugPrint('Error querying registration_requests for variant $v: $e');
      }
    }

    return null;
  }

  /// Cancel/delete pending or approved registration request by phone
  Future<void> cancelRegistrationRequest(String phone) async {
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) return;

    try {
      await _db.collection('registration_requests').doc(normalized).delete();
      debugPrint('Cancelled registration request for $normalized');
    } catch (e) {
      debugPrint('Error deleting registration request by doc ID: $e');
    }

    final variants = <String>{normalized};
    if (normalized.startsWith('967') && normalized.length == 12) {
      final local9 = normalized.substring(3);
      variants.add(local9);
      variants.add('0$local9');
    }
    for (final v in variants) {
      try {
        final q = await _db
            .collection('registration_requests')
            .where('phone', isEqualTo: v)
            .limit(5)
            .get();
        for (final doc in q.docs) {
          final st = doc.data()['status'] ?? '';
          if (st == 'pending' || st == 'approved') {
            await doc.reference.delete();
          }
        }
      } catch (_) {}
    }
  }

  /// Check if phone is in use either by an existing user or by an active registration request
  Future<bool> isPhoneInRegistry(String phone) async {
    if (await isPhoneRegisteredInUsers(phone)) return true;
    if (await hasActiveRegistrationRequest(phone)) return true;
    return false;
  }

  /// Check if an email is already registered to an existing user in users collection
  Future<bool> isEmailRegisteredInUsers(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;
    try {
      final query = await _db
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking email in users: $e');
      return false;
    }
  }

  /// Get active registration request by email (pending or approved) if any exists
  Future<Map<String, dynamic>?> getRegistrationRequestByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;
    try {
      final query = await _db
          .collection('registration_requests')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        final st = data['status'] ?? '';
        if (st == 'pending' || st == 'approved') {
          return {'id': doc.id, ...data};
        }
      }
    } catch (e) {
      debugPrint('Error checking registration_requests by email: $e');
    }
    return null;
  }

  /// Submit registration request to Admin and notify admins immediately
  Future<Map<String, String>> submitRegistrationRequest({
    required String name,
    required String email,
    required String phone,
    String bankName = '',
    String bankAccountName = '',
    String bankAccountNumber = '',
  }) async {
    final normalizedPhone = normalizePhone(phone);
    final cleanEmail = email.trim().toLowerCase();

    // Validate phone structure (9 digits starting with 77, 78, 73, 71 when excluding 967 prefix)
    final localPhone = normalizedPhone.startsWith('967') && normalizedPhone.length == 12
        ? normalizedPhone.substring(3)
        : normalizedPhone;
    const validPrefixes = ['77', '78', '73', '71'];
    if (localPhone.length != 9 || !validPrefixes.any((p) => localPhone.startsWith(p))) {
      throw Exception('invalid_phone_format');
    }

    // 1. Verify phone not already in phone_registry or users
    final isRegisteredUser = await isPhoneRegisteredInUsers(normalizedPhone);
    if (isRegisteredUser) {
      throw Exception('phone_already_registered');
    }

    // 2. Verify email not already in users collection
    final isRegisteredEmail = await isEmailRegisteredInUsers(cleanEmail);
    if (isRegisteredEmail) {
      throw Exception('email_already_registered');
    }

    // 3. Check if there is already an active registration request for this phone
    final hasActiveReq = await hasActiveRegistrationRequest(normalizedPhone);
    if (hasActiveReq) {
      throw Exception('phone_has_pending_request');
    }

    // 4. Check if there is already an active registration request for this email
    final activeReqForEmail = await getRegistrationRequestByEmail(cleanEmail);
    if (activeReqForEmail != null) {
      throw Exception('email_has_pending_request');
    }

    final requestDocRef = _db.collection('registration_requests').doc(normalizedPhone);

    // 5. Save request to Firestore (Doc ID = phone, verificationCode empty, status pending)
    await requestDocRef.set({
      'name': name.trim(),
      'email': cleanEmail,
      'phone': normalizedPhone,
      'bankName': bankName.trim(),
      'bankAccountName': bankAccountName.trim(),
      'bankAccountNumber': bankAccountNumber.trim(),
      'verificationCode': '',
      'status': 'pending',
      'failedAttempts': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 6. Send Instant Push Notification + in-app notification to all Admins
    try {
      await NotificationService().sendRegistrationNotificationToAdmins(
        userName: name.trim(),
        userPhone: normalizedPhone,
      );
    } catch (e) {
      debugPrint('Error notifying admins about new registration: $e');
    }

    // 7. Return requestId and phone
    return {
      'requestId': normalizedPhone,
      'phone': normalizedPhone,
    };
  }



  /// Mark registration request as completed
  Future<void> completeRegistrationRequest(String requestId) async {
    try {
      await _db.collection('registration_requests').doc(requestId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Remove completed registration request
  Future<void> removeRegistrationRequest(String requestId) async {
    try {
      await _db.collection('registration_requests').doc(requestId).delete();
    } catch (_) {}
  }

  // Register new account
  Future<AppUser?> registerUser({
    required String email,
    required String password,
    required String name,
    required String phone,
    String bankName = '',
    String bankAccountName = '',
    String bankAccountNumber = '',
  }) async {
    UserCredential? userCredential;
    final normalizedPhone = normalizePhone(phone);

    // Validate phone structure (9 digits starting with 77, 78, 73, 71 when excluding 967 prefix)
    final localPhone = normalizedPhone.startsWith('967') && normalizedPhone.length == 12
        ? normalizedPhone.substring(3)
        : normalizedPhone;
    const validPrefixes = ['77', '78', '73', '71'];
    if (localPhone.length != 9 || !validPrefixes.any((p) => localPhone.startsWith(p))) {
      throw Exception('invalid_phone_format');
    }

    // Pre-check phone uniqueness in users & phone_registry
    final isAlreadyRegistered = await isPhoneRegisteredInUsers(normalizedPhone);
    if (isAlreadyRegistered) {
      throw Exception('phone_already_registered');
    }

    try {
      // Step 1: Create Firebase Auth account (passwords handled verbatim, never trimmed)
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = userCredential.user?.uid ?? (throw Exception('user_creation_failed'));
      final accountNumber = await _generateUniqueAccountNumber(uid);

      final userRef = _db.collection('users').doc(uid);
      final phoneRef = _db.collection('phone_registry').doc(normalizedPhone);

      // Step 2: Atomic transaction — checks phone uniqueness AND saves user atomically
      await _db.runTransaction((txn) async {
        final phoneSnap = await txn.get(phoneRef);
        if (phoneSnap.exists) {
          throw Exception('phone_already_registered');
        }

        final newUser = AppUser(
          uid: uid,
          name: name.trim(),
          email: email.trim(),
          phone: normalizedPhone,
          role: 'user',
          balance: 0.0,
          bankName: bankName.trim(),
          bankAccountName: bankAccountName.trim(),
          bankAccountNumber: bankAccountNumber.trim(),
          accountNumber: accountNumber,
          createdAt: DateTime.now(),
        );

        // Write user profile and phone registry entry atomically
        txn.set(userRef, newUser.toMap());
        txn.set(phoneRef, {
          'uid': uid,
          'registeredAt': FieldValue.serverTimestamp(),
        });
      });

      // Return the registered user
      return AppUser(
        uid: uid,
        name: name.trim(),
        email: email.trim(),
        phone: normalizedPhone,
        role: 'user',
        balance: 0.0,
        bankName: bankName.trim(),
        bankAccountName: bankAccountName.trim(),
        bankAccountNumber: bankAccountNumber.trim(),
        accountNumber: accountNumber,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      // If transaction failed (e.g. phone taken), delete the Firebase Auth account
      if (userCredential != null && userCredential.user != null) {
        try { await userCredential.user!.delete(); } catch (_) {}
      }
      debugPrint("Error registering user: $e");
      rethrow;
    }
  }

  // Login user (supports either email or phone number)
  Future<AppUser?> loginUser(String identifier, String password) async {
    try {
      String emailToUse = identifier.trim();

      // If user provided a phone number instead of an email
      if (!emailToUse.contains('@')) {
        final normalized = normalizePhone(emailToUse);
        final userByPhone = await findUserByPhone(normalized);
        if (userByPhone == null || userByPhone.email.trim().isEmpty) {
          throw Exception('user_not_found');
        }
        emailToUse = userByPhone.email.trim();
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('user_not_found');
      }
      final uid = firebaseUser.uid;

      // ✅ Force fresh data from server to avoid stale isBlocked cache
      var profile = await getUserProfile(uid, forceServer: true);

      // If profile doc was not found on first try, retry after 500ms
      if (profile == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        profile = await getUserProfile(uid);
      }

      // If profile does not exist in Firestore, do NOT create arbitrary fallback profile
      if (profile == null) {
        await _auth.signOut();
        throw Exception('user-profile-not-found');
      }

      return profile;
    } catch (e) {
      debugPrint("Error logging in: $e");
      rethrow;
    }
  }

  // Update bank details
  Future<void> updateBankDetails({
    required String uid,
    required String bankName,
    required String bankAccountName,
    required String bankAccountNumber,
  }) async {
    await _db.collection('users').doc(uid).update({
      'bankName': bankName.trim(),
      'bankAccountName': bankAccountName.trim(),
      'bankAccountNumber': bankAccountNumber.trim(),
    });
  }

  // Send password reset email (Anti-Enumeration: never reveals if email exists)
  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) return;

    try {
      await _auth.sendPasswordResetEmail(email: cleanEmail);
    } catch (e) {
      // Silently log; never reveal account existence to caller
      debugPrint("Password reset handled: $e");
    }
  }

  // Change Password for signed in user
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('لم يتم العثور على مستخدم مسجل الدخول');
    }

    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  // Verify account password
  Future<bool> verifyPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update Wallet Security PIN — stored as SHA-256 hash
  Future<void> updateWalletPin({
    required String uid,
    required String walletPin,
  }) async {
    // ✅ Never store plain-text PIN
    await _db.collection('users').doc(uid).update({
      'walletPin': hashPin(walletPin),
    });
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await NotificationService().clearFCMToken();
    } catch (e) {
      debugPrint('Error clearing FCM token on signOut: $e');
    }
    await _auth.signOut();
  }
}
