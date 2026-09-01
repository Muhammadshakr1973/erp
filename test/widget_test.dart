import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/main.dart';

void main() {
  testWidgets('PosApp initializes correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PosApp(),
      ),
    );

    expect(find.byType(PosApp), findsOneWidget);
  });
}
