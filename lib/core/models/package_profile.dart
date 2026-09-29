import 'package:cloud_firestore/cloud_firestore.dart';

class PackageProfile {
  final String id;
  final String priceText; // e.g., "200 ريال"
  final double priceValue; // e.g., 200.0
  final String transfer; // e.g., "3 قيقا"
  final String validity; // e.g., "يومين"
  final String? colorHex; // Optional custom HEX color (e.g., "#FF5733" or "FF5733")
  final int order; // For sorting
  final bool isActive;

  PackageProfile({
    required this.id,
    required this.priceText,
    required this.priceValue,
    required this.transfer,
    required this.validity,
    this.colorHex,
    this.order = 0,
    this.isActive = true,
  });

  factory PackageProfile.fromMap(Map<String, dynamic> data, String id) {
    return PackageProfile(
      id: id,
      priceText: data['priceText'] ?? '',
      priceValue: (data['priceValue'] as num?)?.toDouble() ?? 0.0,
      transfer: data['transfer'] ?? '',
      validity: data['validity'] ?? '',
      colorHex: data['colorHex'],
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'priceText': priceText,
      'priceValue': priceValue,
      'transfer': transfer,
      'validity': validity,
      'colorHex': colorHex,
      'order': order,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
