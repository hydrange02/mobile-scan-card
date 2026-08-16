import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart' as app;

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const app.NFCWalletApp());

    // Verify app title or widgets exist
    expect(find.byType(app.NFCWalletApp), findsOneWidget);
  });
}
