import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/app_user.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../data/biometric_service.dart';
import '../data/firebase_auth_service.dart';
import '../data/mikrotik_service.dart';

class AuthViewModel with ChangeNotifier, WidgetsBindingObserver {
  final MikrotikService _mikrotikService = MikrotikService();
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();
  final BiometricService _biometricService = BiometricService();
  // ✅ Secure storage for MikroTik PINs (encrypted on device)
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Firebase Auth & User profile
  AppUser? _appUser;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<AppUser?>? _userProfileSubscription;
  bool _isAuthLoading = false;
  String? _authError;
  bool _canUseBiometrics = false;
  bool _hasSavedBiometricCredentials = false;
  bool _autoLoginEnabled = true;
  bool _isExplicitlyLoggedInThisSession = false;

  AppUser? get appUser => _appUser;
  bool get isAppUserLoggedIn => _appUser != null && (_autoLoginEnabled || _isExplicitlyLoggedInThisSession);
  bool get autoLoginEnabled => _autoLoginEnabled;
  bool get isAdmin => _appUser?.isAdmin ?? false;
  bool get isAuthLoading => _isAuthLoading;
  String? get authError => _authError;
  bool get canUseBiometrics => _canUseBiometrics;
  bool get hasSavedBiometricCredentials => _hasSavedBiometricCredentials;

  // Mikrotik Hotspot Auth
  bool _isLoggedIn = false;
  bool _isLoading = true; // initially true to check status on startup
  String? _errorMessage;
  
  // User data
  String _username = '';
  String _remainBytes = '';
  String _timeRemain = '';
  String _uptime = '';
  String _bytesIn = '';
  String _bytesOut = '';

  // Saved pins history
  List<String> _savedPins = [];
  List<String> get savedPins => _savedPins;

  // Raw values for charts
  int _rawBytesIn = 0;
  int _rawBytesOut = 0;
  int _rawRemainBytes = 0;
  int _rawLimitBytes = 0;
  
  Duration _rawUptime = Duration.zero;
  Duration _rawRemainTime = Duration.zero;
  Duration _rawLimitTime = Duration.zero;

  // Polling timers
  Timer? _pollingTimer;
  Timer? _localTickTimer; // For smooth second-by-second updates

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  String get username => _username;
  String get remainBytes => _remainBytes;
  String get timeRemain => _timeRemain;
  String get uptime => _uptime;
  String get bytesIn => _bytesIn;
  String get bytesOut => _bytesOut;

  // Chart progress getters (0.0 to 1.0)
  double get dataProgress {
    if (_rawRemainBytes <= 0) return 0.0; // Unlimited or no data
    int consumed = _rawBytesIn + _rawBytesOut;
    int total = _rawLimitBytes > 0 ? _rawLimitBytes : (consumed + _rawRemainBytes);
    if (total == 0) return 0.0;
    return (consumed / total).clamp(0.0, 1.0);
  }

  double get timeProgress {
    if (_rawRemainTime.inSeconds <= 0) return 0.0; // Unlimited or no time
    int totalSeconds = _rawLimitTime.inSeconds > 0 ? _rawLimitTime.inSeconds : (_rawUptime.inSeconds + _rawRemainTime.inSeconds);
    if (totalSeconds == 0) return 0.0;
    return (_rawUptime.inSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  AuthViewModel() {
    WidgetsBinding.instance.addObserver(this);
    _loadInitialCachedUser();
    _initFirebaseAuthListener();
    _initAuthCheck();
  }

  void _loadInitialCachedUser() async {
    try {
      final cached = await OfflineCacheService.getCachedUserProfile();
      if (_appUser == null && cached != null) {
        _appUser = cached;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading initial cached user: $e');
    }
  }

  void _initFirebaseAuthListener() {
    _authSubscription =
        _firebaseAuthService.authStateChanges.listen((User? user) async {
      _userProfileSubscription?.cancel();
      if (user != null) {
        _userProfileSubscription = _firebaseAuthService
            .streamUserProfile(user.uid)
            .listen((AppUser? appUser) async {
          if (appUser != null && appUser.isBlocked) {
            // ✅ FIX: The stream may emit a stale cached value (isBlocked:true)
            // even after the admin has unblocked the user. Always confirm from
            // the server before signing out to avoid a false block on re-login.
            final freshProfile = await _firebaseAuthService
                .getUserProfile(user.uid, forceServer: true);

            if (freshProfile != null && freshProfile.isBlocked) {
              // Server confirmed — user is genuinely blocked
              if (_firebaseAuthService.currentFirebaseUser != null) {
                _appUser = null;
                _authError =
                    'عفواً، تم إيقاف وتعطيل هذا الحساب من قبل الإدارة. يرجى التواصل مع الدعم الفني.';
                _firebaseAuthService.signOut();
                notifyListeners();
              }
            } else {
              // Server says NOT blocked — stale cache, update with fresh data
              _appUser = freshProfile ?? appUser;
              _authError = null;
              notifyListeners();
            }
            return;
          }
          // ✅ User is valid and not blocked — clear any previous auth error
          _appUser = appUser;
          _authError = null;
          if (appUser != null) {
            OfflineCacheService.cacheUserProfile(appUser);
            if (appUser.isAdmin) {
              NotificationService().syncAdminFCMToken(appUser.uid);
            }
          }
          notifyListeners();
        }, onError: (e) async {
          // Stream error (e.g. offline) — try fallback to local cached user profile
          debugPrint('streamUserProfile error (ignored): $e');
          if (_appUser == null) {
            final cached = await OfflineCacheService.getCachedUserProfile();
            if (cached != null) {
              _appUser = cached;
              notifyListeners();
            }
          }
        });
      } else {
        // FirebaseAuth is null (e.g. offline) — preserve local cached user profile if present
        final cached = await OfflineCacheService.getCachedUserProfile();
        if (cached != null) {
          _appUser = cached;
          notifyListeners();
        } else {
          _appUser = null;
          notifyListeners();
        }
      }
    });
  }

  void _initAuthCheck() async {
    await _loadAutoLoginSetting();
    await _loadNotificationsSetting();
    await _checkBiometricStatus();
    await _loadSavedPins();

    // Check offline cached user profile if needed
    if (_appUser == null) {
      final cached = await OfflineCacheService.getCachedUserProfile();
      if (cached != null) {
        _appUser = cached;
        notifyListeners();
      }
    }

    await checkStatus();
    if (_isLoggedIn) {
      _startTimers();
    }
  }

  // ─── Notification Settings ────────────────────────────────────────────────
  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  Future<void> _loadNotificationsSetting() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading notifications setting: $e");
    }
  }

  Future<void> toggleNotifications(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', value);

      // Update in Firestore if logged in
      if (_appUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_appUser!.uid)
            .update({'notificationsEnabled': value});
      }

      // Update NotificationService
      if (value) {
        await NotificationService().enableNotifications();
      } else {
        await NotificationService().disableNotifications();
      }
    } catch (e) {
      debugPrint("Error toggling notifications: $e");
    }
  }

  Future<void> _loadAutoLoginSetting() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _autoLoginEnabled = prefs.getBool('auto_login_enabled') ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading auto login setting: $e");
    }
  }

  Future<void> setAutoLoginEnabled(bool value) async {
    _autoLoginEnabled = value;
    notifyListeners();
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_login_enabled', value);
    } catch (e) {
      debugPrint("Error saving auto login setting: $e");
    }
  }

  Future<void> _checkBiometricStatus() async {
    try {
      _canUseBiometrics = await _biometricService.isBiometricsAvailable();
      _hasSavedBiometricCredentials = await _biometricService.isBiometricEnabled();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleBiometricLock(bool enable) async {
    await _biometricService.setBiometricEnabled(enable);
    await _checkBiometricStatus();
  }

  Future<bool> loginWithBiometrics() async {
    _isAuthLoading = true;
    _authError = null;
    notifyListeners();

    try {
      final isEnabled = await _biometricService.isBiometricEnabled();
      if (!isEnabled) {
        _authError = 'يرجى تسجيل الدخول أولاً وتفعيل الدخول بالبصمة';
        _isAuthLoading = false;
        notifyListeners();
        return false;
      }

      final authenticated = await _biometricService.authenticate(
        localizedReason: 'يرجى تأكيد بصمتك للدخول إلى حساب تاج نت',
      );
      if (!authenticated) {
        _isAuthLoading = false;
        notifyListeners();
        return false;
      }

      // If active Firebase session exists, load fresh profile
      final currentFirebaseUser = _firebaseAuthService.currentUser;
      if (currentFirebaseUser != null) {
        final profile = await _firebaseAuthService.getUserProfile(
          currentFirebaseUser.uid,
          forceServer: true,
        );

        if (profile != null) {
          if (profile.isBlocked) {
            await _firebaseAuthService.signOut();
            _appUser = null;
            _authError = 'عفواً، تم إيقاف وتعطيل هذا الحساب من قبل الإدارة.';
            _isAuthLoading = false;
            notifyListeners();
            return false;
          }

          _appUser = profile;
          _isExplicitlyLoggedInThisSession = true;
          _isAuthLoading = false;
          notifyListeners();
          return true;
        }
      }

      _authError = 'انتهت الجلسة السابقة. يرجى تسجيل الدخول بالبريد وكلمة المرور';
      _isAuthLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _authError = _translateFirebaseError(e.toString());
      _isAuthLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadSavedPins() async {
    try {
      // ✅ Read from SecureStorage (encrypted) instead of SharedPreferences
      final stored = await _secureStorage.read(key: 'saved_pins_list');
      if (stored != null && stored.isNotEmpty) {
        _savedPins = stored.split(',').where((p) => p.isNotEmpty).toList();
      } else {
        // One-time migration: read old SharedPreferences data and move to SecureStorage
        final prefs = await SharedPreferences.getInstance();
        final oldList = prefs.getStringList('saved_pins_list');
        final oldSingle = prefs.getString('saved_pin');
        if (oldList != null && oldList.isNotEmpty) {
          _savedPins = oldList;
        } else if (oldSingle != null && oldSingle.isNotEmpty) {
          _savedPins = [oldSingle];
        }
        if (_savedPins.isNotEmpty) {
          // Migrate to secure storage and clean up old prefs
          await _secureStorage.write(
            key: 'saved_pins_list',
            value: _savedPins.join(','),
          );
          await prefs.remove('saved_pins_list');
          await prefs.remove('saved_pin');
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading saved pins: $e");
    }
  }

  // --- WhatsApp & Phone Operations ---

  Future<AppUser?> findUserByPhone(String phone) async {
    return await _firebaseAuthService.findUserByPhone(phone);
  }

  Future<bool> loginWithExistingUser(AppUser user) async {
    if (user.isBlocked) {
      _authError = 'عفواً، تم إيقاف وتعطيل هذا الحساب من قبل الإدارة. يرجى التواصل مع الدعم الفني.';
      notifyListeners();
      return false;
    }
    _appUser = user;
    _isExplicitlyLoggedInThisSession = true;
    _authError = null;
    notifyListeners();
    return true;
  }

  /// Returns true if phone belongs to an already active user account
  Future<bool> isPhoneRegisteredInUsers(String phone) async {
    try {
      return await _firebaseAuthService.isPhoneRegisteredInUsers(phone);
    } catch (_) {
      return false;
    }
  }

  /// Returns true if email belongs to an already active user account
  Future<bool> isEmailRegisteredInUsers(String email) async {
    try {
      return await _firebaseAuthService.isEmailRegisteredInUsers(email);
    } catch (_) {
      return false;
    }
  }

  /// Returns active registration request details if any exists (pending or approved)
  Future<Map<String, dynamic>?> getRegistrationRequest(String phone) async {
    try {
      return await _firebaseAuthService.getRegistrationRequest(phone);
    } catch (_) {
      return null;
    }
  }

  /// Returns active registration request details by email if any exists (pending or approved)
  Future<Map<String, dynamic>?> getRegistrationRequestByEmail(String email) async {
    try {
      return await _firebaseAuthService.getRegistrationRequestByEmail(email);
    } catch (_) {
      return null;
    }
  }

  /// Cancel a pending registration request so the user can start over
  Future<void> cancelRegistrationRequest(String phone) async {
    try {
      await _firebaseAuthService.cancelRegistrationRequest(phone);
      notifyListeners();
    } catch (e) {
      debugPrint('Error in AuthViewModel.cancelRegistrationRequest: $e');
    }
  }

  /// Returns true if phone is taken (checks Firestore phone_registry + users collection + active requests)
  Future<bool> isPhoneRegistered(String phone) async {
    try {
      return await _firebaseAuthService.isPhoneInRegistry(phone);
    } catch (_) {
      return false;
    }
  }

  /// Submit registration request to Admin and return {requestId, phone}
  Future<Map<String, String>> submitRegistrationRequest({
    required String name,
    required String email,
    required String phone,
    String bankName = '',
    String bankAccountName = '',
    String bankAccountNumber = '',
  }) async {
    _isAuthLoading = true;
    _authError = null;
    notifyListeners();

    try {
      final result = await _firebaseAuthService.submitRegistrationRequest(
        name: name,
        email: email,
        phone: phone,
        bankName: bankName,
        bankAccountName: bankAccountName,
        bankAccountNumber: bankAccountNumber,
      );
      _isAuthLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isAuthLoading = false;
      final err = e.toString();
      if (err.contains('phone_already_registered')) {
        _authError = 'عفواً، رقم الجوال هذا مسجل لدينا بالفعل. يرجى استخدام رقم آخر أو تسجيل الدخول.';
      } else if (err.contains('invalid_phone_format')) {
        _authError = 'رقم الهاتف غير صالح. يجب أن يتكون من 9 أرقام ويبدأ بـ 77 أو 78 أو 73 أو 71.';
      } else if (err.contains('email_already_registered')) {
        _authError = 'عفواً، البريد الإلكتروني هذا مسجل لدينا بالفعل. يرجى استخدام بريد آخر أو تسجيل الدخول.';
      } else if (err.contains('phone_has_pending_request')) {
        _authError = 'يوجد طلب إنشاء حساب قيد المعالجة لهذا الرقم بالفعل. يرجى الانتظار لموافقة الإدارة.';
      } else if (err.contains('email_has_pending_request')) {
        _authError = 'عفواً، يوجد طلب إنشاء حساب سابق قيد المعالجة بهذا البريد الإلكتروني.';
      } else if (err.contains('phone_has_approved_request')) {
        _authError = 'تمت الموافقة على طلبك السابق بالفعل! يرجى تسجيل الدخول بكلمة المرور المرسلة إليك.';
      } else {
        _authError = 'فشل في إرسال طلب إنشاء الحساب. يرجى التحقق من اتصال الإنترنت.';
      }
      notifyListeners();
      rethrow;
    }
  }

  /// Mark registration request as completed
  Future<void> completeRegistrationRequest(String requestId) async {
    await _firebaseAuthService.completeRegistrationRequest(requestId);
  }

  /// Clean up completed registration request
  Future<void> removeRegistrationRequest(String requestId) async {
    await _firebaseAuthService.removeRegistrationRequest(requestId);
  }

  // --- Firebase Account Operations ---

  Future<bool> registerAccount({
    required String email,
    required String password,
    required String name,
    required String phone,
    String bankName = '',
    String bankAccountName = '',
    String bankAccountNumber = '',
  }) async {
    _isAuthLoading = true;
    _authError = null;
    notifyListeners();

    try {
      final newUser = await _firebaseAuthService.registerUser(
        email: email,
        password: password,
        name: name,
        phone: phone,
        bankName: bankName,
        bankAccountName: bankAccountName,
        bankAccountNumber: bankAccountNumber,
      );
      _appUser = newUser;
      _isExplicitlyLoggedInThisSession = true;
      _isAuthLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('phone_already_registered')) {
        _authError = 'تعذر إتمام التسجيل بهذه البيانات. يرجى التأكد والمحاولة مجدداً.';
      } else if (errStr.contains('invalid_phone_format')) {
        _authError = 'رقم الهاتف غير صالح. يجب أن يتكون من 9 أرقام ويبدأ بـ 77 أو 78 أو 73 أو 71.';
      } else {
        _authError = _translateFirebaseError(errStr);
      }
      _isAuthLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginAccount(String email, String password) async {
    _isAuthLoading = true;
    _authError = null;
    notifyListeners();

    try {
      final user = await _firebaseAuthService.loginUser(email, password).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('تأخرت الاستجابة من الخادم، يرجى الفحص وتأكيد الاتصال بالإنترنت'),
      );
      if (user == null) {
        _authError = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
        _isAuthLoading = false;
        notifyListeners();
        return false;
      }

      if (user.isBlocked) {
        await _firebaseAuthService.signOut();
        _appUser = null;
        _authError = 'عفواً، تم إيقاف وتعطيل هذا الحساب من قبل الإدارة. يرجى التواصل مع الدعم الفني.';
        _isAuthLoading = false;
        notifyListeners();
        return false;
      }

      _appUser = user;
      _isExplicitlyLoggedInThisSession = true;
      _isAuthLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('user-profile-not-found')) {
        _authError = 'الحساب غير نشط أو تم حذفه. يرجى التواصل مع إدارة الشبكة.';
      } else {
        _authError = _translateFirebaseError(errStr);
      }
      _isAuthLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _isAuthLoading = true;
    _authError = null;
    notifyListeners();

    try {
      await _firebaseAuthService.sendPasswordResetEmail(email);
      _isAuthLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isAuthLoading = false;
      notifyListeners();
      return true; // Always succeed user-facing message to prevent enumeration
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isAuthLoading = true;
    _authError = null;
    notifyListeners();

    try {
      await _firebaseAuthService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _isAuthLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _authError = _translateFirebaseError(e.toString());
      _isAuthLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateBankDetails({
    required String bankName,
    required String bankAccountName,
    required String bankAccountNumber,
  }) async {
    if (_appUser == null) return;
    _isAuthLoading = true;
    notifyListeners();

    try {
      await _firebaseAuthService.updateBankDetails(
        uid: _appUser!.uid,
        bankName: bankName,
        bankAccountName: bankAccountName,
        bankAccountNumber: bankAccountNumber,
      );
      _isAuthLoading = false;
      notifyListeners();
    } catch (e) {
      _authError = "تعذر تحديث بيانات الحساب المصرفي حالياً";
      _isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOutAccount() async {
    await OfflineCacheService.clearUserProfileCache();
    await _firebaseAuthService.signOut();
    _appUser = null;
    _isExplicitlyLoggedInThisSession = false;
    notifyListeners();
  }

  /// Force-refresh user profile from server for Pull-to-Refresh (Fix L-02)
  Future<void> refreshUserProfile() async {
    final user = _firebaseAuthService.currentFirebaseUser;
    if (user != null) {
      try {
        final freshProfile = await _firebaseAuthService.getUserProfile(user.uid, forceServer: true);
        if (freshProfile != null) {
          _appUser = freshProfile;
          await OfflineCacheService.cacheUserProfile(freshProfile);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('refreshUserProfile error: $e');
      }
    }
  }

  String _translateFirebaseError(String error) {
    final lowerError = error.toLowerCase();
    // ✅ OWASP Anti-Enumeration: Unified credential error message
    if (lowerError.contains('wrong-password') ||
        lowerError.contains('invalid-credential') ||
        lowerError.contains('invalid-login-credentials') ||
        lowerError.contains('invalid_password') ||
        lowerError.contains('user-not-found') ||
        lowerError.contains('user-disabled')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    } else if (lowerError.contains('email-already-in-use')) {
      return 'تعذر استخدام هذا البريد الإلكتروني. يرجى المحاولة ببريد آخر.';
    } else if (lowerError.contains('weak-password')) {
      return 'كلمة المرور ضعيفة. يجب أن تتكون من 8 خانات على الأقل وتحتوي على أحرف وأرقام.';
    } else if (lowerError.contains('invalid-email')) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    } else if (lowerError.contains('too-many-requests')) {
      return 'تمت عدة محاولات غير ناجحة. يرجى الانتظار بضع دقائق والمحاولة مجدداً.';
    } else if (lowerError.contains('requires-recent-login')) {
      return 'يرجى تسجيل الخروج وإعادة الدخول لتأكيد هذه العملية الحساسة';
    } else if (lowerError.contains('network') || lowerError.contains('unavailable') || lowerError.contains('timeout')) {
      return 'يرجى التأكد من الاتصال بالإنترنت والمحاولة مجدداً';
    }
    return 'تعذر إتمام العملية حالياً. يرجى المحاولة لاحقاً.';
  }

  // --- Mikrotik Operations ---

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Always query router status immediately when returning to the app (e.g. after browser login)
      checkStatus(isPolling: true);
    } else if (state == AppLifecycleState.paused) {
      _stopTimers();
    }
  }

  void _stopTimers() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _localTickTimer?.cancel();
    _localTickTimer = null;
  }

  void _startTimers() {
    _stopTimers();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isLoading && _isLoggedIn) {
        checkStatus(isPolling: true);
      } else if (!_isLoggedIn) {
        _stopTimers();
      }
    });

    _localTickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isLoggedIn) {
        bool changed = false;
        if (_uptime.isNotEmpty) {
          _uptime = _addOneSecond(_uptime);
          _rawUptime = Duration(seconds: _rawUptime.inSeconds + 1);
          changed = true;
        }
        if (_timeRemain.isNotEmpty) {
          _timeRemain = _subtractOneSecond(_timeRemain);
          if (_rawRemainTime.inSeconds > 0) {
            _rawRemainTime = Duration(seconds: _rawRemainTime.inSeconds - 1);
          }
          changed = true;
        }
        if (changed) notifyListeners();
      } else {
        _stopTimers();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _userProfileSubscription?.cancel();
    _stopTimers();
    super.dispose();
  }

  Duration _parseMikrotikTime(String time) {
    if (time.isEmpty) return Duration.zero;
    int w = 0, d = 0, h = 0, m = 0, s = 0;
    
    final RegExp regex = RegExp(r'(?:(\d+)w)?(?:(\d+)d)?(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?');
    final match = regex.firstMatch(time);
    
    if (match != null) {
      if (match.group(1) != null) w = int.parse(match.group(1)!);
      if (match.group(2) != null) d = int.parse(match.group(2)!);
      if (match.group(3) != null) h = int.parse(match.group(3)!);
      if (match.group(4) != null) m = int.parse(match.group(4)!);
      if (match.group(5) != null) s = int.parse(match.group(5)!);
    }
    return Duration(days: (w * 7) + d, hours: h, minutes: m, seconds: s);
  }

  String _formatMikrotikTime(Duration duration) {
    if (duration.inSeconds <= 0) return '0s';
    
    String res = '';
    int days = duration.inDays;
    int weeks = days ~/ 7;
    days = days % 7;
    int hours = duration.inHours % 24;
    int minutes = duration.inMinutes % 60;
    int seconds = duration.inSeconds % 60;
    
    if (weeks > 0) res += '${weeks}w';
    if (days > 0) res += '${days}d';
    if (hours > 0) res += '${hours}h';
    if (minutes > 0) res += '${minutes}m';
    if (seconds > 0) res += '${seconds}s';
    
    return res;
  }

  String _addOneSecond(String timeStr) {
    final dur = _parseMikrotikTime(timeStr);
    return _formatMikrotikTime(Duration(seconds: dur.inSeconds + 1));
  }

  String _subtractOneSecond(String timeStr) {
    final dur = _parseMikrotikTime(timeStr);
    if (dur.inSeconds <= 0) return '0s';
    return _formatMikrotikTime(Duration(seconds: dur.inSeconds - 1));
  }

  String _formatBytes(String? bytesStr) {
    if (bytesStr == null || bytesStr.isEmpty) return '';
    int bytes = int.tryParse(bytesStr) ?? 0;
    if (bytes == 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> checkStatus({bool isPolling = false}) async {
    if (!isPolling) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    final data = await _mikrotikService.checkStatus();
    
    if (data['error'] != null) {
      _errorMessage = data['error'];
      _isLoggedIn = false;
      _stopTimers();
    } else if (data['logged_in'] == 'yes') {
      _isLoggedIn = true;
      _username = data['username'] ?? '';
      
      _rawRemainBytes = int.tryParse(data['remain_bytes_total'] ?? '') ?? 0;
      _rawLimitBytes = int.tryParse(data['limit_bytes_total'] ?? '') ?? 0;
      _rawBytesIn = int.tryParse(data['bytes_in'] ?? '') ?? 0;
      _rawBytesOut = int.tryParse(data['bytes_out'] ?? '') ?? 0;
      _rawUptime = _parseMikrotikTime(data['uptime'] ?? '');
      _rawRemainTime = _parseMikrotikTime(data['session_time_left'] ?? '');
      _rawLimitTime = _parseMikrotikTime(data['limit_uptime'] ?? '');

      _remainBytes = _formatBytes(data['remain_bytes_total']);
      _timeRemain = data['session_time_left'] ?? '';
      _uptime = data['uptime'] ?? '';
      _bytesIn = _formatBytes(data['bytes_in']);
      _bytesOut = _formatBytes(data['bytes_out']);
      _errorMessage = null;

      // Automatically ensure real-time timers are active whenever user is logged in
      if (_pollingTimer == null || _localTickTimer == null) {
        _startTimers();
      }
    } else {
      _isLoggedIn = false;
      _stopTimers();
    }

    if (!isPolling) {
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<bool> login(String pin) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _mikrotikService.login(pin, '').timeout(
        const Duration(seconds: 8),
        onTimeout: () => {'error': 'تأخر الاتصال بالسيرفر. يرجى التأكد من اتصالك بشبكة الواي فاي الخاصة بالتطبيقات (t.net)'},
      );

      if (data['action'] == 'onLoggedIn' || data['logged_in'] == 'yes') {
        // ✅ Save PINs to SecureStorage (encrypted)
        _savedPins.remove(pin);
        _savedPins.insert(0, pin);
        if (_savedPins.length > 3) {
          _savedPins = _savedPins.sublist(0, 3);
        }
        await _secureStorage.write(
          key: 'saved_pins_list',
          value: _savedPins.join(','),
        );
        
        await checkStatus();
        if (_isLoggedIn) {
          _startTimers();
        }
        return true;
      } else {
        String rawError = data['error_orig'] ?? data['error'] ?? 'بيانات الدخول غير صحيحة';
        _errorMessage = _translateMikrotikError(rawError);
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ في الشبكة أثناء تسجيل الدخول';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _translateMikrotikError(String error) {
    final lowerError = error.toLowerCase();
    
    if (lowerError.contains('failed host lookup') ||
        lowerError.contains('socketexception') ||
        lowerError.contains('clientexception') ||
        lowerError.contains('connection refused') ||
        lowerError.contains('network is unreachable')) {
      return 'يرجى التأكد من اتصالك بشبكة الواي فاي الخاصة بالشبكة (TajNet)، وإيقاف بيانات الهاتف (4G/3G)';
    } else if (lowerError.contains('not found')) {
      return 'عفواً، هذا الكرت غير موجود';
    } else if (lowerError.contains('invalid password') || lowerError.contains('wrong password')) {
      return 'رمز الدخول غير صحيح، تأكد من كتابة الأرقام بشكل صحيح';
    } else if (lowerError.contains('simultaneous session')) {
      return 'الكرت مستخدم حالياً في جهاز آخر';
    } else if (lowerError.contains('uptime limit')) {
      return 'انتهت صلاحية وقت هذا الكرت';
    } else if (lowerError.contains('traffic limit') || lowerError.contains('byte limit')) {
      return 'نفد رصيد البيانات لهذا الكرت';
    } else if (lowerError.contains('calling station id') || lowerError.contains('mac address')) {
      return 'عفواً، هذا الكرت مقترن بجهاز آخر';
    } else if (lowerError.contains('no valid profile')) {
      return 'لا توجد باقة صالحة لهذا الكرت';
    } else if (lowerError.contains('radius')) {
      return 'تعذر الوصول لخادم الشبكة حالياً، يرجى المحاولة لاحقاً';
    }
    
    // Sanitize any remaining raw error tags
    final cleaned = error.replaceAll('&lt;', '').replaceAll('&gt;', '').trim();
    if (cleaned.contains('Exception') || cleaned.contains('Error:')) {
      return 'تعذر الاتصال بصفحة البوابة، يرجى التأكد من الاتصال بالواي فاي والمحاولة مجدداً';
    }
    return cleaned;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    _stopTimers();
    await _mikrotikService.logout();
    
    _isLoggedIn = false;
    _username = '';
    _remainBytes = '';
    _timeRemain = '';
    _isLoading = false;
    notifyListeners();
  }

  // Wallet Security PIN Methods
  Future<bool> setWalletPin(String newPin) async {
    if (_appUser == null) return false;
    _isAuthLoading = true;
    notifyListeners();
    try {
      await _firebaseAuthService.updateWalletPin(
        uid: _appUser!.uid,
        walletPin: newPin.trim(),
      );
      _isAuthLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _authError = 'فشل في حفظ رمز المحفظة: $e';
      _isAuthLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyAccountPassword(String password) async {
    return await _firebaseAuthService.verifyPassword(password);
  }

  bool verifyWalletPin(String enteredPin) {
    if (_appUser == null) return false;
    final storedPin = _appUser!.walletPin?.trim();
    if (storedPin == null || storedPin.isEmpty) {
      return true; // No PIN configured yet
    }

    final cleanEntered = enteredPin.trim();
    final enteredHash = FirebaseAuthService.hashPin(cleanEntered);

    // Case 1: Stored PIN is already SHA-256 hashed (64 hex characters)
    if (_appUser!.isPinHashed) {
      return storedPin == enteredHash;
    }

    // Case 2: Legacy plain-text PIN (4 digits) — verify and auto-upgrade to SHA-256
    if (storedPin == cleanEntered) {
      // Non-blocking auto-upgrade to hashed PIN
      setWalletPin(cleanEntered).catchError((e) {
        debugPrint("Auto PIN hash migration error: $e");
        return false;
      });
      return true;
    }

    return false;
  }
}
