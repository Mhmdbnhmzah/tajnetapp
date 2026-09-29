import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/speed_test_viewmodel.dart';
import '../../../core/theme/theme.dart';

class SpeedTestDialog extends StatelessWidget {
  const SpeedTestDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SpeedTestViewModel>(
      builder: (context, viewModel, child) {
        return AlertDialog(
          backgroundColor: AppTheme.backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Center(
            child: Text('فحص جودة الاتصال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 30),
              // Speedometer
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: viewModel.downloadSpeed),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return SizedBox(
                    width: 200,
                    height: 150,
                    child: CustomPaint(
                      painter: SpeedometerPainter(value),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 20),
                            Text(
                              value > 0 ? value.toStringAsFixed(1) : '--',
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                            ),
                            const Text('Mbps', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('البنج (Ping): ', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 16)),
                  Text(viewModel.ping > 0 ? '${viewModel.ping} ms' : '--', style: const TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                viewModel.status,
                style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 16),
              ),
              const SizedBox(height: 10),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: viewModel.isTesting ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('إغلاق', style: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: viewModel.isTesting ? null : () => viewModel.startTest(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: viewModel.isTesting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('ابدأ الفحص', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class SpeedometerPainter extends CustomPainter {
  final double speed;
  SpeedometerPainter(this.speed);

  @override
  void paint(Canvas canvas, Size size) {
    Paint bgPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Paint activePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Offset center = Offset(size.width / 2, size.height - 20); // shift center down
    double radius = size.width / 2;
    
    // Draw background arc (240 degrees sweep from 150 deg to 30 deg)
    double startAngle = 150 * pi / 180;
    double sweepAngle = 240 * pi / 180;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, bgPaint);

    // Draw active arc based on speed (assuming max gauge visually fills at 50 Mbps)
    double cappedSpeed = speed > 50 ? 50 : speed;
    double activeSweep = (cappedSpeed / 50) * sweepAngle;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, activeSweep, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant SpeedometerPainter oldDelegate) {
    return oldDelegate.speed != speed;
  }
}
