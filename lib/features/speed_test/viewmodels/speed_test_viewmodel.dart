import 'package:flutter/material.dart';
import '../data/speed_test_service.dart';

class SpeedTestViewModel extends ChangeNotifier {
  final SpeedTestService _speedTestService = SpeedTestService();

  bool _isTesting = false;
  int _ping = 0;
  double _downloadSpeed = 0.0;
  String _status = 'جاهز للفحص';

  bool get isTesting => _isTesting;
  int get ping => _ping;
  double get downloadSpeed => _downloadSpeed;
  String get status => _status;

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  Future<void> startTest() async {
    _isTesting = true;
    _ping = 0;
    _downloadSpeed = 0.0;
    _status = 'جاري قياس البنج...';
    notifyListeners();

    // 1. Check Ping
    int pingResult = await _speedTestService.checkPing();
    if (_isDisposed) return;
    
    if (pingResult == -1) {
      _isTesting = false;
      _status = 'فشل الاتصال بالسيرفر';
      notifyListeners();
      return;
    }

    _ping = pingResult;
    _status = 'جاري قياس سرعة التحميل...';
    notifyListeners();

    // 2. Check Download Speed
    double speedResult = await _speedTestService.checkDownloadSpeed(
      onProgress: (currentSpeed) {
        if (_isDisposed) return;
        _downloadSpeed = currentSpeed;
        notifyListeners();
      },
    );

    if (_isDisposed) return;
    _isTesting = false;
    if (speedResult == -1.0) {
      _status = 'فشل التحميل، قد يكون الملف غير موجود';
    } else {
      _downloadSpeed = speedResult;
      _status = 'اكتمل الفحص!';
    }
    notifyListeners();
  }
}
