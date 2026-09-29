import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Holds the result of a version check
class UpdateCheckResult {
  final bool needsUpdate;        // Must update (mandatory/force)
  final bool suggestUpdate;      // Optional update available
  final String currentVersion;
  final String latestVersion;
  final String minVersion;
  final String downloadUrl;
  final String updateMessage;

  const UpdateCheckResult({
    this.needsUpdate = false,
    this.suggestUpdate = false,
    this.currentVersion = '1.0.0',
    this.latestVersion = '1.0.0',
    this.minVersion = '1.0.0',
    this.downloadUrl = '',
    this.updateMessage = '',
  });
}

class ForceUpdateService {
  static const String _collection = 'app_config';
  static const String _document = 'version';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Compares two semantic version strings (e.g. "1.2.3").
  /// Returns negative if a < b, 0 if equal, positive if a > b.
  static int compareVersions(String a, String b) {
    final aParts = a.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
    final bParts = b.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();

    while (aParts.length < 3) {
      aParts.add(0);
    }
    while (bParts.length < 3) {
      bParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (aParts[i] != bParts[i]) return aParts[i] - bParts[i];
    }
    return 0;
  }

  /// Opens the download / update URL in external browser or app store
  static Future<bool> launchUpdateUrl(String urlString) async {
    final cleanUrl = urlString.trim();
    if (cleanUrl.isEmpty) return false;

    try {
      final Uri uri = Uri.parse(cleanUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback try without canLaunchUrl check
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching update URL: $e');
      return false;
    }
  }

  /// Real-time stream checking current app version against Firestore config.
  Stream<UpdateCheckResult> streamUpdateCheck() async* {
    if (kIsWeb) {
      yield const UpdateCheckResult();
      return;
    }
    final PackageInfo info = await PackageInfo.fromPlatform();
    final String currentVersion = info.version; // e.g. "1.0.0"

    yield* _db.collection(_collection).doc(_document).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return UpdateCheckResult(currentVersion: currentVersion);
      }

      final data = snapshot.data()!;
      final String minVersion = (data['min_version'] ?? '1.0.0').toString().trim();
      final String latestVersion = (data['latest_version'] ?? '1.0.0').toString().trim();
      final String downloadUrl = (data['download_url'] ?? '').toString().trim();
      final String updateMessage = (data['update_message'] ??
              'يتوفر تحديث جديد ومهم للتطبيق. يرجى التحديث للاستمرار في الاستخدام.')
          .toString()
          .trim();

      debugPrint('🔍 VersionCheck: current=$currentVersion min=$minVersion latest=$latestVersion');

      // Forced / Mandatory Update: current version is below minimum required
      if (compareVersions(currentVersion, minVersion) < 0) {
        return UpdateCheckResult(
          needsUpdate: true,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          minVersion: minVersion,
          downloadUrl: downloadUrl,
          updateMessage: updateMessage,
        );
      }

      // Optional Update: current version is below latest but above or equal to min
      if (compareVersions(currentVersion, latestVersion) < 0) {
        return UpdateCheckResult(
          suggestUpdate: true,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          minVersion: minVersion,
          downloadUrl: downloadUrl,
          updateMessage: updateMessage.isNotEmpty
              ? updateMessage
              : 'يتوفر إصدار جديد ($latestVersion). هل تريد التحديث الآن؟',
        );
      }

      // Up to date
      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        minVersion: minVersion,
      );
    });
  }

  /// One-off check for current app version against Firestore config.
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final doc = await _db.collection(_collection).doc(_document).get();

      if (!doc.exists || doc.data() == null) {
        return const UpdateCheckResult();
      }

      final data = doc.data()!;
      final String minVersion = (data['min_version'] ?? '1.0.0').toString().trim();
      final String latestVersion = (data['latest_version'] ?? '1.0.0').toString().trim();
      final String downloadUrl = (data['download_url'] ?? '').toString().trim();
      final String updateMessage = (data['update_message'] ??
              'يتوفر تحديث جديد ومهم للتطبيق. يرجى التحديث للاستمرار في الاستخدام.')
          .toString()
          .trim();

      final PackageInfo info = await PackageInfo.fromPlatform();
      final String currentVersion = info.version;

      if (compareVersions(currentVersion, minVersion) < 0) {
        return UpdateCheckResult(
          needsUpdate: true,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          minVersion: minVersion,
          downloadUrl: downloadUrl,
          updateMessage: updateMessage,
        );
      }

      if (compareVersions(currentVersion, latestVersion) < 0) {
        return UpdateCheckResult(
          suggestUpdate: true,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          minVersion: minVersion,
          downloadUrl: downloadUrl,
          updateMessage: updateMessage.isNotEmpty
              ? updateMessage
              : 'يتوفر إصدار جديد ($latestVersion). هل تريد التحديث الآن؟',
        );
      }

      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        minVersion: minVersion,
      );
    } catch (e) {
      debugPrint('ForceUpdate check error: $e');
      return const UpdateCheckResult();
    }
  }
}
