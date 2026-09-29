import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotification {
  final String id;
  final String title;
  final String message;
  final String type; // 'card_purchase', 'deposit_new', 'deposit_approved', 'transfer'
  final double amount;
  final String userName;
  final DateTime createdAt;
  final bool isRead;

  AdminNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.amount = 0.0,
    this.userName = '',
    required this.createdAt,
    this.isRead = false,
  });

  factory AdminNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AdminNotification(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'general',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      userName: data['userName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'amount': amount,
      'userName': userName,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': isRead,
    };
  }
}
