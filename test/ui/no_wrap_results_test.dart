import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/domain/models.dart';
import 'package:temper_calc/ui/result_page.dart';
import 'package:temper_calc/ui/search_page.dart';

const _info = TemperamentInfo(
  rank: 2,
  subgroup: '2.3.5.7',
  commaBasis: [],
  equalDivisionsLabel: 'EDOs',
  equalDivisions: ['12, 19, 31, 41, 53, 65, temperament with a long label'],
  mapping: [
    [1, 1, 0, -3],
  ],
  preimage: [],
  tunings: {},
  errors: {},
  primes: {},
  badness: '0.347',
  complexity: '3.800000000',
);

void main() {
  testWidgets('allows search result labels to wrap naturally', (tester) async {
    const label = 'a very long comma result that should stay on one line';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchPage(
            active: true,
            onCalculate: (_) async => _info,
            onSearch: (_) async => const TemperamentSearchResult(
              groups: [
                SearchGroup(
                  rank: 2,
                  candidates: [
                    SearchCandidate(
                      rank: 2,
                      label: label,
                      source: CalculationSource.commas,
                      families: [],
                      badness: 0.778,
                      complexity: 3.8,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('search-subgroup')), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await tester.pumpAndSettle();

    final resultText = tester.widget<Text>(find.text(label));
    expect(resultText.maxLines, isNull);
    expect(resultText.softWrap, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('allows long detail values to wrap naturally', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ResultPage(result: _info)));

    final value = tester.widget<SelectableText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data == _info.equalDivisions.join(', '),
      ),
    );
    expect(value.maxLines, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps result row geometry stable while opening', (tester) async {
    final calculation = Completer<TemperamentInfo>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchPage(
            active: true,
            onCalculate: (_) => calculation.future,
            onSearch: (_) async => const TemperamentSearchResult(
              groups: [
                SearchGroup(
                  rank: 2,
                  candidates: [
                    SearchCandidate(
                      rank: 2,
                      label: '19 & 53',
                      source: CalculationSource.commas,
                      families: [],
                      badness: 0.778,
                      complexity: 3.8,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('search-subgroup')), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('search-result-2-19 & 53'));
    final before = tester.getSize(row);
    await tester.tap(row);
    await tester.pump();
    expect(tester.getSize(row), before);

    calculation.complete(_info);
    await tester.pumpAndSettle();
    expect(find.text('Temperament info'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
