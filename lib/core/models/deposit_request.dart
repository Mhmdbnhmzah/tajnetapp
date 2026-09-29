import 'package:cloud_firestore/cloud_firestore.dart';

class DepositRequest {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String userAccountNumber;
  final double amount;
  final String status; // 'pending', 'approved', 'rejected'
  final String adminNote;
  final DateTime createdAt;
  final DateTime? processedAt;

  DepositRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    this.userAccountNumber = '',
    required this.amount,
    required this.status,
    required this.adminNote,
    required this.createdAt,
    this.processedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  factory DepositRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DepositRequest(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      userName: data['userName']?.toString() ?? '',
      userPhone: data['userPhone']?.toString() ?? '',
      userAccountNumber: data['userAccountNumber']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      status: data['status']?.toString() ?? 'pending',
      adminNote: data['adminNote']?.toString() ?? '',
      createdAt: _parseDateTime(data['createdAt']),
      processedAt: data['processedAt'] != null
          ? _parseDateTime(data['processedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'userAccountNumber': userAccountNumber,
      'amount': amount,
      'status': status,
      'adminNote': adminNote,
      'createdAt': FieldValue.serverTimestamp(),
      'processedAt': processedAt != null
          ? Timestamp.fromDate(processedAt!)
          : null,
    };
  }
}
