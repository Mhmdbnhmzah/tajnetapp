import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/admin_notification.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/bank_account.dart';
import '../../../core/models/card_item.dart';
import '../../../core/models/deposit_request.dart';
import '../../../core/models/registration_request.dart';
import '../data/admin_service.dart';

class AdminViewModel extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  DateTime? _lastReadNotificationsTime;

  DateTime? get lastReadNotificationsTime => _lastReadNotificationsTime;

  AdminViewModel() {
    _loadLastReadTime();
  }

  Future<void> _loadLastReadTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt('admin_notif_last_read_millis');
      if (millis != null) {
        _lastReadNotificationsTime = DateTime.fromMillisecondsSinceEpoch(millis);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading last read notification time: $e");
    }
  }

  Future<void> markNotificationsAsRead() async {
    try {
      _lastReadNotificationsTime = DateTime.now();
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('admin_notif_last_read_millis', _lastReadNotificationsTime!.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint("Error marking notifications as read: $e");
    }
  }

  int getUnreadNotificationCount(List<AdminNotification> notifications) {
    if (_lastReadNotificationsTime == null) return notifications.length;
    return notifications.where((n) => n.createdAt.isAfter(_lastReadNotificationsTime!)).length;
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  // Streams
  Stream<List<DepositRequest>> get pendingDepositRequests =>
      _adminService.streamPendingDepositRequests();

  Stream<List<DepositRequest>> get allDepositRequests =>
      _adminService.streamAllDepositRequests();

  Stream<List<BankAccount>> get allBankAccounts =>
      _adminService.streamAllBankAccounts();

  Stream<List<AppUser>> get allUsers =>
      _adminService.streamAllUsers();

  Stream<List<CardItem>> get soldCards =>
      _adminService.streamSoldCards();

  Stream<List<DepositRequest>> get approvedDeposits =>
      _adminService.streamApprovedDeposits();

  Stream<List<Map<String, dynamic>>> get allPackages =>
      _adminService.streamAllPackages();

  Stream<List<CardItem>> get allCards =>
      _adminService.streamAllCards();

  Stream<List<RegistrationRequest>> get pendingRegistrationRequests =>
      _adminService.streamPendingRegistrationRequests();

  Stream<List<AdminNotification>> get adminNotifications =>
      _adminService.streamAdminNotifications();

  // Provision user account and complete registration request
  Future<bool> provisionUserAccount({
    required RegistrationRequest request,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _adminService.provisionUserAccount(
        request: request,
        password: password,
      );
      _isLoading = false;
      if (res) {
        _successMessage = 'تم إنشاء وتفعيل حساب العميل بنجاح';
      }
      notifyListeners();
      return res;
    } catch (e) {
      debugPrint('Admin provisionUserAccount error: $e');
      _isLoading = false;
      final errStr = e.toString();
      if (errStr.contains('email-already-in-use')) {
        _errorMessage = 'البريد الإلكتروني للعميل مسجل مسبقاً في النظام.';
      } else if (errStr.contains('phone_already_registered')) {
        _errorMessage = 'رقم الهاتف مسجل مسبقاً لمستخدم آخر.';
      } else {
        _errorMessage = 'تعذر إنشاء حساب العميل حالياً. يرجى التأكد من البيانات.';
      }
      notifyListeners();
      return false;
    }
  }

  // Approve registration request
  Future<bool> approveRegistrationRequest(String requestId) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _adminService.approveRegistrationRequest(requestId);
      _isLoading = false;
      if (res) {
        _successMessage = 'تمت الموافقة على طلب إنشاء الحساب بنجاح';
      }
      notifyListeners();
      return res;
    } catch (e) {
      debugPrint('Admin approveRegistrationRequest error: $e');
      _isLoading = false;
      _errorMessage = 'تعذر تحديث حالة الطلب حالياً. يرجى المحاولة لاحقاً.';
      notifyListeners();
      return false;
    }
  }

  // Reject registration request
  Future<bool> rejectRegistrationRequest({
    required String requestId,
    required String adminNote,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _adminService.rejectRegistrationRequest(
        requestId: requestId,
        adminNote: adminNote,
      );
      _isLoading = false;
      if (res) {
        _successMessage = 'تم رفض طلب إنشاء الحساب';
      }
      notifyListeners();
      return res;
    } catch (e) {
      debugPrint('Admin rejectRegistrationRequest error: $e');
      _isLoading = false;
      _errorMessage = 'تعذر رفض الطلب حالياً. يرجى المحاولة لاحقاً.';
      notifyListeners();
      return false;
    }
  }

  // Approve deposit
  Future<bool> approveDeposit({
    required String requestId,
    required String userId,
    required double amount,
    String adminNote = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _adminService.approveDepositRequest(
        requestId: requestId,
        userId: userId,
        amount: amount,
        adminNote: adminNote,
      );

      _successMessage = 'تمت الموافقة على طلب الشحن وإضافة الرصيد للعميل بنجاح!';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Admin approveDeposit error: $e');
      _errorMessage = 'تعذر اعتماد طلب الشحن حالياً. يرجى المحاولة لاحقاً.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Reject deposit
  Future<bool> rejectDeposit({
    required String requestId,
    required String userId,
    required double amount,
    String adminNote = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _adminService.rejectDepositRequest(
        requestId: requestId,
        userId: userId,
        amount: amount,
        adminNote: adminNote,
      );

      _successMessage = 'تم رفض طلب الشحن';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Admin rejectDeposit error: $e');
      _errorMessage = 'تعذر رفض الطلب حالياً. يرجى المحاولة لاحقاً.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Upload Bulk Cards
  Future<bool> uploadCardsBulk(List<Map<String, dynamic>> cardsData) async {
    if (cardsData.isEmpty) return false;
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final count = await _adminService.addCardsBulk(cardsData);
      _successMessage = 'تم إضافة $count كارت بنجاح إلى المخزون!';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Admin uploadCardsBulk error: $e');
      _errorMessage = 'تعذر رفع الكروت حالياً. يرجى المحاولة لاحقاً.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Manage Bank Accounts
  Future<bool> addBankAccount(BankAccount account) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _adminService.addBankAccount(account);
      _successMessage = 'تم إضافة الحساب المصرفي بنجاح';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Admin addBankAccount error: $e');
      _errorMessage = 'تعذر إضافة الحساب المصرفي حالياً.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBankAccount(BankAccount account) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _adminService.updateBankAccount(account);
      _successMessage = 'تم تعديل الحساب المصرفي بنجاح';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Admin updateBankAccount error: $e');
      _errorMessage = 'تعذر تعديل الحساب المصرفي حالياً.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> uploadBankLogo(Uint8List bytes, String filename) async {
    return await _adminService.uploadBankLogo(bytes, filename);
  }

  Future<void> deleteBankAccount(String accountId) async {
    try {
      await _adminService.deleteBankAccount(accountId);
      _successMessage = 'تم حذف الحساب المصرفي';
      notifyListeners();
    } catch (e) {
      debugPrint('Admin deleteBankAccount error: $e');
      _errorMessage = 'تعذر حذف الحساب المصرفي حالياً.';
      notifyListeners();
    }
  }

  // Toggle User Block Status
  Future<bool> toggleUserBlock(String userId, bool isBlocked) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _adminService.toggleUserBlockStatus(userId, isBlocked);
      _successMessage = isBlocked ? 'تم إيقاف حساب المستخدم بنجاح' : 'تم إعادة تفعيل حساب المستخدم بنجاح';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Admin toggleUserBlock error: $e');
      _errorMessage = 'تعذر تغيير حالة الحساب حالياً.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Reset User Wallet Security PIN
  Future<bool> resetUserWalletPin(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _adminService.resetUserWalletPin(userId);
      _successMessage = 'تم إلغاء وإعادة ضبط رمز حماية المحفظة للعميل بنجاح!';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Admin resetUserWalletPin error: $e');
      _errorMessage = 'تعذر إعادة ضبط رمز المحفظة حالياً.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Manage Packages

  Future<bool> addPackage(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _adminService.addPackage(data);
      _successMessage = 'تم إضافة الباقة بنجاح';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Admin addPackage error: $e');
      _errorMessage = 'تعذر إضافة الباقة حالياً.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePackage(String packageId, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _adminService.updatePackage(packageId, data);
      _successMessage = 'تم تحديث الباقة بنجاح';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Admin updatePackage error: $e');
      _errorMessage = 'تعذر تحديث الباقة حالياً.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> deletePackage(String packageId) async {
    try {
      await _adminService.deletePackage(packageId);
      _successMessage = 'تم حذف الباقة بنجاح';
      notifyListeners();
    } catch (e) {
      debugPrint('Admin deletePackage error: $e');
      _errorMessage = 'تعذر حذف الباقة حالياً.';
      notifyListeners();
    }
  }

  // Card Inventory

  Future<bool> deleteCard(String cardId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _adminService.deleteCard(cardId);
      _successMessage = 'تم حذف الكارت من المخزون بنجاح';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Admin deleteCard error: $e');
      _errorMessage = 'تعذر حذف الكارت حالياً.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAvailableCardsForProfile(String profilePrice) async {
    _isLoading = true;
    notifyListeners();
    try {
      final count = await _adminService.deleteAvailableCardsForProfile(profilePrice);
      _successMessage = 'تم حذف $count كارت غير مباع من فئة $profilePrice بنجاح';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Admin deleteAvailableCardsForProfile error: $e');
      _errorMessage = 'تعذر حذف الكروت حالياً.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }


}
