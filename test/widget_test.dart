import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/main.dart';

void main() {
  testWidgets('shows both primary workflows', (tester) async {
    await tester.pumpWidget(const TemperCalcApp());

    expect(find.text('Temper Calc'), findsNothing);
    expect(find.text('Temperament calculator'), findsOneWidget);
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
  });
}
