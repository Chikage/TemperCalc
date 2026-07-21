import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/ui/calculator_page.dart';

void main() {
  testWidgets('shows a comma-separated subgroup hint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalculatorPage(
            active: true,
            onCalculate: (_) async => throw UnimplementedError(),
          ),
        ),
      ),
    );

    final subgroupDecoration = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const ValueKey('calculator-subgroup')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(subgroupDecoration.decoration.hintText, '11  or  2,3,5,7');
    expect(tester.takeException(), isNull);
  });
}
