import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/main.dart';

void main() {
  testWidgets('CampRent POS app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CampRentApp(),
      ),
    );

    // Verify app starts and shows CampRent POS
    expect(find.text('CampRent POS'), findsOneWidget);
  });
}
