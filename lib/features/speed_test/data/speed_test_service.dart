import 'dart:async';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:http/http.dart' as http;

class SpeedTestService {
  static const String defaultGatewayUrl = 't.net';

  // Return t.net directly as requested by the user
  Future<String> _getGatewayUrl() async {
    return defaultGatewayUrl;
  }

  Future<int> checkPing() async {
    String gateway = await _getGatewayUrl();
    Uri url;
    try {
      url = Uri.parse('http://$gateway/status.html?var=1');
    } on FormatException catch (e) {
      debugPrint("FormatException parsing ping URL: $e. Falling back to default gateway.");
      gateway = defaultGatewayUrl;
      url = Uri.parse('http://$gateway/status.html?var=1');
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 3));
      stopwatch.stop();
      if (response.statusCode == 200) {
        return stopwatch.elapsedMilliseconds;
      }
    } catch (e) {
      stopwatch.stop();
    }
    return -1; // -1 means failed
  }

  Future<double> checkDownloadSpeed({Function(double)? onProgress}) async {
    String gateway = await _getGatewayUrl();
    String testFileUrl = 'http://$gateway/img/bg-stadium.png';

    // Verify URI can be parsed safely
    try {
      Uri.parse(testFileUrl);
    } on FormatException catch (e) {
      debugPrint("FormatException parsing speed test URL: $e. Falling back to default gateway.");
      gateway = defaultGatewayUrl;
      testFileUrl = 'http://$gateway/img/bg-stadium.png';
    }

    final stopwatch = Stopwatch()..start();
    int totalBytes = 0;
    const double testDurationSeconds = 5.0; // Run test for exactly 5 seconds
    final client = http.Client();
    bool abortedPrematurely = false;

    try {
      // Loop repeatedly downloading the background image to calculate speed
      while (stopwatch.elapsedMilliseconds < testDurationSeconds * 1000) {
        final request = http.Request(
          'GET',
          Uri.parse(
            '$testFileUrl?nocache=${DateTime.now().millisecondsSinceEpoch}',
          ),
        );

        final response = await client.send(request);
        if (response.statusCode != 200) {
          // If the router redirects (e.g. 302 to login page) or blocks, we abort
          abortedPrematurely = true;
          break; 
        }

        final completer = Completer<void>();
        late StreamSubscription<List<int>> subscription;

        subscription = response.stream.listen(
          (List<int> chunk) {
            totalBytes += chunk.length;
            final double elapsedSeconds = stopwatch.elapsedMilliseconds / 1000.0;
            if (elapsedSeconds > 0.1) {
              final double currentSpeed = (totalBytes * 8) / (1000000 * elapsedSeconds);
              if (onProgress != null) onProgress(currentSpeed);
            }

            // Cancel the stream if duration limit reached
            if (stopwatch.elapsedMilliseconds >= testDurationSeconds * 1000) {
              subscription.cancel();
              if (!completer.isCompleted) completer.complete();
            }
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
          onError: (e) {
            abortedPrematurely = true;
            if (!completer.isCompleted) completer.completeError(e);
          },
          cancelOnError: true,
        );

        // Wait for this file download stream to finish or get aborted
        await completer.future.catchError((e) {
          abortedPrematurely = true;
          debugPrint("Speed test stream error: $e");
        });

        if (stopwatch.elapsedMilliseconds >= testDurationSeconds * 1000 || abortedPrematurely) {
          break;
        }
      }
    } catch (e) {
      abortedPrematurely = true;
      debugPrint("Speed test error: $e");
    } finally {
      stopwatch.stop();
      client.close();
    }

    final double finalSeconds = stopwatch.elapsedMilliseconds / 1000.0;
    // Only count as success if it ran for at least 3.5 seconds and collected bytes
    if (!abortedPrematurely && finalSeconds >= 3.5 && totalBytes > 0) {
      return (totalBytes * 8) / (1000000 * finalSeconds);
    }
    
    // Fallback: If it aborted but we collected data for at least 3.5 seconds, we can still show it
    if (finalSeconds >= 3.5 && totalBytes > 1024 * 500) {
      return (totalBytes * 8) / (1000000 * finalSeconds);
    }
    
    return -1.0;
  }
}
