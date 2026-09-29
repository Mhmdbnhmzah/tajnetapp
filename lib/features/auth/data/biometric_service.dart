import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyBiometricEnabled = 'bio_app_lock_enabled';

  // Check if device supports biometrics
  Future<bool> isBiometricsAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      debugPrint("Error checking biometrics availability: $e");
      return false;
    }
  }

  // Check if user has enabled biometric authentication
  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _storage.read(key: _keyBiometricEnabled);
      return enabled == 'true';
    } catch (e) {
      debugPrint("Error checking biometric enabled status: $e");
      return false;
    }
  }

  // Enable/Disable biometric authentication preference
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      if (enabled) {
        await _storage.write(key: _keyBiometricEnabled, value: 'true');
      } else {
        await _storage.delete(key: _keyBiometricEnabled);
      }
    } catch (e) {
      debugPrint("Error setting biometric preference: $e");
    }
  }

  // Trigger system biometric prompt (Fingerprint / Face ID)
  Future<bool> authenticate({String localizedReason = 'يرجى وضع بصمتك لتأكيد الهوية'}) async {
    try {
      final isAvailable = await isBiometricsAvailable();
      if (!isAvailable) return false;

      return await _auth.authenticate(
        localizedReason: localizedReason,
      );
    } on PlatformException catch (e) {
      debugPrint("Biometric Auth PlatformException: $e");
      return false;
    } catch (e) {
      debugPrint("Biometric Auth error: $e");
      return false;
    }
  }

  // Clear biometric preferences on sign out
  Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _keyBiometricEnabled);
    } catch (e) {
      debugPrint("Error clearing biometric preference: $e");
    }
  }
}
