import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // 'user' or 'admin'
  final double balance;
  final String bankName;
  final String bankAccountName;
  final String bankAccountNumber;
  final String accountNumber; // Unique 6-digit App Account Number
  final bool isBlocked;
  final String? walletPin; // 4-digit security PIN for wallet transactions
  final bool notificationsEnabled; // Whether user enabled push notifications
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.balance,
    this.bankName = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    required this.accountNumber,
    this.isBlocked = false,
    this.walletPin,
    this.notificationsEnabled = true,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  /// True if a wallet PIN has been configured (stored as SHA-256 hash = 64 chars,
  /// or legacy plain-text 4-digit PIN for accounts before hash migration).
  bool get hasWalletPin => walletPin != null && walletPin!.trim().isNotEmpty;

  /// True if the stored PIN is already hashed with SHA-256 (64 hex chars).
  bool get isPinHashed => walletPin != null && walletPin!.trim().length == 64;

  /// Generates a deterministic 6-digit account number from user UID as fallback
  static String generateAccountNumberFromUid(String uid) {
    final hash = uid.hashCode.abs();
    final number = 100000 + (hash % 900000);
    return number.toString();
  }

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final String accNum = data['accountNumber'] ?? generateAccountNumberFromUid(doc.id);
    return AppUser(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'user',
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      bankName: data['bankName'] ?? '',
      bankAccountName: data['bankAccountName'] ?? '',
      bankAccountNumber: data['bankAccountNumber'] ?? '',
      accountNumber: accNum,
      isBlocked: data['isBlocked'] ?? false,
      walletPin: data['walletPin'],
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'balance': balance,
      'bankName': bankName,
      'bankAccountName': bankAccountName,
      'bankAccountNumber': bankAccountNumber,
      'accountNumber': accountNumber,
      'isBlocked': isBlocked,
      'walletPin': walletPin,
      'notificationsEnabled': notificationsEnabled,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
