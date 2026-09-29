import 'package:cloud_firestore/cloud_firestore.dart';

class BankAccount {
  final String id;
  final String bankName;
  final String accountHolder;
  final String accountNumber;
  final String iban;
  final String? imageUrl;
  final bool isActive;

  BankAccount({
    required this.id,
    required this.bankName,
    required this.accountHolder,
    required this.accountNumber,
    required this.iban,
    this.imageUrl,
    this.isActive = true,
  });

  factory BankAccount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BankAccount(
      id: doc.id,
      bankName: data['bankName'] ?? '',
      accountHolder: data['accountHolder'] ?? '',
      accountNumber: data['accountNumber'] ?? '',
      iban: data['iban'] ?? '',
      imageUrl: data['imageUrl'] as String?,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bankName': bankName,
      'accountHolder': accountHolder,
      'accountNumber': accountNumber,
      'iban': iban,
      if (imageUrl != null && imageUrl!.trim().isNotEmpty) 'imageUrl': imageUrl!.trim(),
      'isActive': isActive,
    };
  }

  BankAccount copyWith({
    String? id,
    String? bankName,
    String? accountHolder,
    String? accountNumber,
    String? iban,
    String? imageUrl,
    bool? isActive,
  }) {
    return BankAccount(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountHolder: accountHolder ?? this.accountHolder,
      accountNumber: accountNumber ?? this.accountNumber,
      iban: iban ?? this.iban,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
    );
  }
}
