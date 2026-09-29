import 'package:cloud_firestore/cloud_firestore.dart';

class CardItem {
  final String id;
  final String profilePrice; // e.g. "200 ريال"
  final double priceValue; // 200.0
  final String pin;
  final String serialNumber;
  final String status; // 'available', 'sold'
  final String? colorHex; // Optional custom HEX color (e.g. "#FF5733")
  final String? soldToUserId;
  final String? soldToUserName;
  final DateTime? soldAt;
  final DateTime createdAt;

  CardItem({
    required this.id,
    required this.profilePrice,
    required this.priceValue,
    required this.pin,
    required this.serialNumber,
    required this.status,
    this.colorHex,
    this.soldToUserId,
    this.soldToUserName,
    this.soldAt,
    required this.createdAt,
  });

  bool get isAvailable => status == 'available';

  factory CardItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CardItem(
      id: doc.id,
      profilePrice: data['profilePrice'] ?? '',
      priceValue: (data['priceValue'] as num?)?.toDouble() ?? 0.0,
      pin: data['pin'] ?? '',
      serialNumber: data['serialNumber'] ?? '',
      status: data['status'] ?? 'available',
      colorHex: data['colorHex'],
      soldToUserId: data['soldToUserId'],
      soldToUserName: data['soldToUserName'],
      soldAt: (data['soldAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'profilePrice': profilePrice,
      'priceValue': priceValue,
      'pin': pin,
      'serialNumber': serialNumber,
      'status': status,
      'colorHex': colorHex,
      'soldToUserId': soldToUserId,
      'soldToUserName': soldToUserName,
      'soldAt': soldAt != null ? Timestamp.fromDate(soldAt!) : null,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
