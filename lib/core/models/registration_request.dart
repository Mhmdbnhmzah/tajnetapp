import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationRequest {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String bankName;
  final String bankAccountName;
  final String bankAccountNumber;
  final String verificationCode;
  final String status; // 'pending', 'approved', 'rejected', 'completed'
  final String adminNote;
  final int failedAttempts;
  final DateTime createdAt;

  RegistrationRequest({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.bankName = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.verificationCode = '',
    this.status = 'pending',
    this.adminNote = '',
    this.failedAttempts = 0,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCompleted => status == 'completed';

  factory RegistrationRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RegistrationRequest(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      bankName: data['bankName'] ?? '',
      bankAccountName: data['bankAccountName'] ?? '',
      bankAccountNumber: data['bankAccountNumber'] ?? '',
      verificationCode: data['verificationCode'] ?? '',
      status: data['status'] ?? 'pending',
      adminNote: data['adminNote'] ?? '',
      failedAttempts: (data['failedAttempts'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'bankName': bankName,
      'bankAccountName': bankAccountName,
      'bankAccountNumber': bankAccountNumber,
      'verificationCode': verificationCode,
      'status': status,
      'adminNote': adminNote,
      'failedAttempts': failedAttempts,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
