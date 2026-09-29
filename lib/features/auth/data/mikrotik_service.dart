import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MikrotikService {
  static const String defaultGatewayUrl = '3.3.3.1';

  Future<String> _getGatewayUrl() async {
    return defaultGatewayUrl;
  }

  // Parse the Mikrotik output format to a normal JSON map
  Map<String, dynamic>? _extractJson(String rawBody) {
    try {
      final clean = rawBody.trim();
      return json.decode(clean);
    } catch (_) {
      try {
        int startIndex = rawBody.indexOf('{');
        int endIndex = rawBody.lastIndexOf('}');
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          String jsonString = rawBody.substring(startIndex, endIndex + 1);
          return json.decode(jsonString);
        }
      } catch (e) {
        debugPrint("JSON parsing error: $e");
      }
    }
    return null;
  }

  // Helper to translate network & socket errors to friendly Arabic
  String _friendlyNetworkError(Object error) {
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('failed host lookup') ||
        errStr.contains('socketexception') ||
        errStr.contains('connection refused') ||
        errStr.contains('unreachable') ||
        errStr.contains('network is unreachable')) {
      return 'يرجى التأكد من اتصالك بشبكة الواي فاي الخاصة بالشبكة (TajNet)، وإيقاف بيانات الهاتف (4G/3G)';
    }
    if (errStr.contains('timeoutexception') || errStr.contains('timed out')) {
      return 'تأخرت الاستجابة من بوابة الشبكة. يرجى التحقق من اتصالك والمحاولة مجدداً';
    }
    return 'تعذر الاتصال ببوابة الشبكة حالياً. يرجى التأكد من الاتصال بشبكة الواي فاي والمحاولة لاحقاً';
  }

  // Status check
  Future<Map<String, dynamic>> checkStatus() async {
    String gateway = await _getGatewayUrl();
    debugPrint("DEBUG (checkStatus): Using gateway -> $gateway");

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    Uri url;
    try {
      url = Uri.parse('http://$gateway/status.html?var=1&_t=$timestamp');
    } catch (e) {
      gateway = defaultGatewayUrl;
      url = Uri.parse('http://$gateway/status.html?var=1&_t=$timestamp');
    }

    try {
      final response = await http.get(
        url,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = _extractJson(response.body);
        if (data != null) {
          return data;
        } else {
          if (response.body.contains('window.location.href')) {
            return {'logged_in': 'no'};
          }
          return {'error': 'غير متصل بالبوابة حالياً'};
        }
      }
      return {'error': 'تعذر الاتصال ببوابة الشبكة (رمز: ${response.statusCode})'};
    } catch (e) {
      debugPrint("DEBUG (checkStatus): Exception -> $e");
      return {'error': _friendlyNetworkError(e)};
    }
  }

  // Login
  Future<Map<String, dynamic>> login(String username, String password) async {
    String gateway = await _getGatewayUrl();
    debugPrint("DEBUG (login): Using gateway -> $gateway");

    Uri url;
    try {
      url = Uri.parse('http://$gateway/login');
    } catch (e) {
      gateway = defaultGatewayUrl;
      url = Uri.parse('http://$gateway/login');
    }

    try {
      final response = await http.post(
        url,
        body: {
          'username': username,
          'password': password,
          'var': '1',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = _extractJson(response.body);
        if (data != null) {
          return data;
        } else {
          return {'error': 'بيانات الدخول غير صحيحة أو تم إدخال رمز خاطئ'};
        }
      }
      return {'error': 'تعذر الاتصال ببوابة الشبكة. يرجى المحاولة لاحقاً'};
    } catch (e) {
      debugPrint("DEBUG (login): Exception -> $e");
      return {'error': _friendlyNetworkError(e)};
    }
  }

  // Logout
  Future<Map<String, dynamic>> logout() async {
    String gateway = await _getGatewayUrl();
    Uri url;
    try {
      url = Uri.parse('http://$gateway/logout.html?var=1');
    } catch (e) {
      gateway = defaultGatewayUrl;
      url = Uri.parse('http://$gateway/logout.html?var=1');
    }

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = _extractJson(response.body);
        if (data != null) {
          return data;
        }
      }
      return {'error': 'تم تسجيل الخروج'};
    } catch (e) {
      return {'error': _friendlyNetworkError(e)};
    }
  }
}
