import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/card_item.dart';

class OfflineCacheService {
  static const _storage = FlutterSecureStorage();
  static const String _userKey = 'cached_user_profile_json';
  static const String _cardsPrefix = 'cached_cards_';

  // ─── Cache & Load User Profile ────────────────────────────────────────────

  static Future<void> cacheUserProfile(AppUser user) async {
    try {
      final jsonStr = jsonEncode(user.toMap());
      await _storage.write(key: _userKey, value: jsonStr);
    } catch (e) {
      debugPrint('Error caching user profile: $e');
    }
  }

  static Future<AppUser?> getCachedUserProfile() async {
    try {
      final jsonStr = await _storage.read(key: _userKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        return AppUser(
          uid: map['uid'] ?? '',
          name: map['name'] ?? '',
          email: map['email'] ?? '',
          phone: map['phone'] ?? '',
          role: map['role'] ?? 'user',
          balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
          accountNumber: map['accountNumber'] ?? '',
          bankName: map['bankName'] ?? '',
          bankAccountName: map['bankAccountName'] ?? '',
          bankAccountNumber: map['bankAccountNumber'] ?? '',
          walletPin: map['walletPin'],
          isBlocked: map['isBlocked'] ?? false,
          createdAt: map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
              : DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Error reading cached user profile: $e');
    }
    return null;
  }

  static Future<void> clearUserProfileCache() async {
    try {
      await _storage.delete(key: _userKey);
    } catch (e) {
      debugPrint('Error clearing cached user profile: $e');
    }
  }

  // ─── Cache & Load Purchased Cards ─────────────────────────────────────────

  static Future<void> cacheUserCards(String userId, List<CardItem> cards) async {
    try {
      final listMap = cards.map((c) => {
        'id': c.id,
        'profilePrice': c.profilePrice,
        'priceValue': c.priceValue,
        'pin': c.pin,
        'serialNumber': c.serialNumber,
        'status': c.status,
        'colorHex': c.colorHex,
        'soldToUserId': c.soldToUserId,
        'soldToUserName': c.soldToUserName,
        'soldAt': c.soldAt?.toIso8601String(),
        'createdAt': c.createdAt.toIso8601String(),
      }).toList();

      final jsonStr = jsonEncode(listMap);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cardsPrefix$userId', jsonStr);
    } catch (e) {
      debugPrint('Error caching user cards: $e');
    }
  }

  static Future<List<CardItem>> getCachedUserCards(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_cardsPrefix$userId');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> listMap = jsonDecode(jsonStr);
        return listMap.map((map) => CardItem(
          id: map['id'] ?? '',
          profilePrice: map['profilePrice'] ?? '',
          priceValue: (map['priceValue'] as num?)?.toDouble() ?? 0.0,
          pin: map['pin'] ?? '',
          serialNumber: map['serialNumber'] ?? '',
          status: map['status'] ?? 'sold',
          colorHex: map['colorHex'],
          soldToUserId: map['soldToUserId'],
          soldToUserName: map['soldToUserName'],
          soldAt: map['soldAt'] != null ? DateTime.tryParse(map['soldAt']) : null,
          createdAt: map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
              : DateTime.now(),
        )).toList();
      }
    } catch (e) {
      debugPrint('Error reading cached user cards: $e');
    }
    return [];
  }
}
