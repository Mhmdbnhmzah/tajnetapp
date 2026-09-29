import 'package:flutter/material.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/bank_account.dart';
import '../../../core/models/card_item.dart';
import '../../../core/models/deposit_request.dart';
import '../data/store_service.dart';

class StoreViewModel extends ChangeNotifier {
  final StoreService _storeService = StoreService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  // Active bank accounts stream
  Stream<List<BankAccount>> get activeBankAccounts =>
      _storeService.streamActiveBankAccounts();

  // Active packages stream
  Stream<List<Map<String, dynamic>>> get activePackages =>
      _storeService.streamActivePackages();

  // User's deposit requests stream
  Stream<List<DepositRequest>> getUserDepositRequests(String userId) =>
      _storeService.streamUserDepositRequests(userId);

  // Check pending deposit request
  Future<DepositRequest?> getPendingDepositRequest(String userId) =>
      _storeService.getPendingDepositRequest(userId);

  // User's purchased cards stream
  Stream<List<CardItem>> getUserPurchasedCards(String userId) =>
      _storeService.streamUserPurchasedCards(userId);

  // ─── Submit Deposit Request ───────────────────────────────────────────────

  Future<bool> submitDepositRequest({
    required String userId,
    required String userName,
    required String userPhone,
    required String userAccountNumber,
    required double amount,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _storeService.submitDepositRequest(
        userId: userId,
        userName: userName,
        userPhone: userPhone,
        userAccountNumber: userAccountNumber,
        amount: amount,
      );

      _successMessage =
          'تم تسجيل طلب الشحن بنجاح! سيتم مراجعة سندك وإضافة الرصيد قريباً.';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Buy Card ─────────────────────────────────────────────────────────────

  Future<CardItem?> buyCard({
    required String userId,
    required String userName,
    required String profilePrice,
    required double priceValue,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final card = await _storeService.buyCardWithBalance(
        userId: userId,
        userName: userName,
        profilePrice: profilePrice,
        priceValue: priceValue,
      );

      _successMessage = 'تم شراء الكرت بنجاح! الرمز: ${card.pin}';
      _isLoading = false;
      notifyListeners();
      return card;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ─── Find User by Account Number ──────────────────────────────────────────

  Future<AppUser?> findUserByAccountNumber(String accountNumber) async {
    return await _storeService.findUserByAccountNumber(accountNumber);
  }

  // ─── Transfer Balance ─────────────────────────────────────────────────────

  Future<bool> transferBalance({
    required String senderUid,
    required String recipientAccountNumber,
    required double amount,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _storeService.transferBalance(
        senderUid: senderUid,
        recipientAccountNumber: recipientAccountNumber,
        amount: amount,
      );

      _successMessage = 'تم تحويل مبلغ $amount ريال بنجاح!';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
