import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/domain/models.dart';
import 'package:temper_calc/ui/app_theme.dart';
import 'package:temper_calc/ui/search_page.dart';

const _searchResult = TemperamentSearchResult(
  groups: [
    SearchGroup(
      rank: 2,
      candidates: [
        SearchCandidate(
          rank: 2,
          label: '81/80',
          source: CalculationSource.commas,
          families: ['meantone'],
          badness: 0.778,
          complexity: 3.8,
        ),
      ],
    ),
    SearchGroup(
      rank: 3,
      candidates: [
        SearchCandidate(
          rank: 3,
          label: '12 & 19',
          source: CalculationSource.edos,
          families: [],
          badness: null,
          complexity: 12.4,
        ),
      ],
    ),
  ],
);

const _temperamentInfo = TemperamentInfo(
  rank: 2,
  subgroup: '2.3.5',
  commaBasis: [],
  equalDivisionsLabel: 'EDOs',
  equalDivisions: [],
  mapping: [
    [1, 0, -4],
    [0, 1, 4],
  ],
  preimage: [],
  tunings: {},
  errors: {},
  primes: {},
  badness: '0.778',
);

void main() {
  testWidgets('groups results into mobile-width rank tables that still open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CalculatorInput? openedInput;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SearchPage(
            active: true,
            onSearch: (_) async => _searchResult,
            onCalculate: (input) async {
              openedInput = input;
              return _temperamentInfo;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('search-subgroup')), '5');
    final searchButton = find.widgetWithText(FilledButton, 'Search');
    await tester.ensureVisible(searchButton);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    expect(find.text('Rank 2'), findsOneWidget);
    expect(find.text('Rank 3'), findsOneWidget);
    expect(find.text('Results'), findsNWidgets(2));
    expect(find.text('Families'), findsNWidgets(2));
    expect(find.text('Badness'), findsNWidgets(3));
    expect(find.text('Complexity'), findsNWidgets(2));
    expect(find.text('0.778'), findsOneWidget);
    expect(find.text('3.8'), findsOneWidget);
    expect(
      tester.getSize(find.text('12 & 19')).height,
      greaterThan(tester.getSize(find.text('81/80')).height),
    );

    final rankTwoTable = find.byKey(const ValueKey('search-results-table-2'));
    for (final label in ['Results', 'Families', 'Badness', 'Complexity']) {
      final heading = tester.widget<Text>(
        find.descendant(of: rankTwoTable, matching: find.text(label)),
      );
      expect(heading.maxLines, 1);
      expect(heading.softWrap, isFalse);
      expect(heading.style?.fontSize, 12);
      expect(heading.style?.letterSpacing, 0);
    }

    final tableRect = tester.getRect(rankTwoTable);
    expect(tableRect.left, greaterThanOrEqualTo(0));
    expect(tableRect.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);

    final candidate = find.byKey(const ValueKey('search-result-2-81/80'));
    await tester.scrollUntilVisible(
      candidate,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(candidate);
    await tester.pumpAndSettle();

    expect(openedInput, isNotNull);
    expect(openedInput!.commas, '81/80');
    expect(find.text('Temperament info'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
