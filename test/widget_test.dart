import 'package:flutter_test/flutter_test.dart';
import 'package:tajnet_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TajNetApp());

    // Verify that the app builds without errors
    expect(find.byType(TajNetApp), findsOneWidget);
  });
}
