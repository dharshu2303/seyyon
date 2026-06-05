import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/main.dart';

void main() {
  testWidgets('App launches correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SosApp());
    await tester.pump();

    // Verify that the app title is displayed
    expect(find.text('Seyyon'), findsOneWidget);
  });
}
