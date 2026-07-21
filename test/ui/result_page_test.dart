import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/domain/app_settings.dart';
import 'package:temper_calc/domain/models.dart';
import 'package:temper_calc/ui/result_page.dart';
import 'package:url_launcher/link.dart';

void main() {
  test('aligns comma basis columns and brackets', () {
    final vectors = formatCommaBasisVectors([
      const CommaInfo(vector: [-3, -1, 2, 0], ratio: '25/24'),
      const CommaInfo(vector: [2, -3, 0, 1], ratio: '28/27'),
      const CommaInfo(vector: [6, -2, 0, -1], ratio: '64/63'),
    ]);

    expect(vectors, [
      '[ -3  -1  2   0 ]',
      '[  2  -3  0   1 ]',
      '[  6  -2  0  -1 ]',
    ]);
    expect(vectors.map((vector) => vector.length).toSet(), {17});
    expect(vectors.map((vector) => vector.indexOf('[')).toSet(), {0});
    expect(vectors.map((vector) => vector.indexOf(']')).toSet(), {16});
  });

  testWidgets('shows loading and supports retrying a failed result', (
    tester,
  ) async {
    const result = TemperamentInfo(
      rank: 2,
      subgroup: '2.3.5',
      commaBasis: [],
      equalDivisionsLabel: 'EDOs',
      equalDivisions: ['12'],
      mapping: [
        [1, 1, 0],
      ],
      preimage: [],
      tunings: {},
      errors: {},
      primes: {},
      badness: '0.778',
      complexity: '3.800000000',
    );
    final attempts = <Completer<TemperamentInfo>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ResultPage.loading(
          loadResult: () {
            final attempt = Completer<TemperamentInfo>();
            attempts.add(attempt);
            return attempt.future;
          },
        ),
      ),
    );

    expect(attempts, hasLength(1));
    expect(find.text('Temperament info'), findsOneWidget);
    expect(find.text('Loading'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    attempts.single.completeError(StateError('failed'));
    await tester.pump();
    expect(find.text('Could not load temperament info'), findsOneWidget);
    expect(find.text('Bad state: failed'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();
    expect(attempts, hasLength(2));
    expect(find.text('Loading'), findsOneWidget);

    attempts.last.complete(result);
    await tester.pumpAndSettle();
    expect(find.text('Loading'), findsNothing);
    expect(find.byType(MatrixView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('links result names and ratios to xen wiki', (tester) async {
    const result = TemperamentInfo(
      rank: 1,
      subgroup: '2.3.5',
      families: ['compton'],
      weakFamilies: ['augmented'],
      commaBasis: [
        CommaInfo(vector: [-4, 4, -1], ratio: '81/80'),
        CommaInfo(vector: [7, 0, -3], ratio: '128/125'),
      ],
      equalDivisionsLabel: 'edo',
      equalDivisions: ['12'],
      mapping: [
        [12, 19, 28],
      ],
      preimage: ['16/15'],
      tunings: {
        'WE tuning': ['111.731285270'],
        'CWE tuning': ['111.731285270'],
      },
      errors: {},
      primes: {},
      badness: '0.471479111',
      complexity: '12.000000000',
    );

    await tester.pumpWidget(MaterialApp(home: ResultPage(result: result)));

    final links = tester
        .widgetList<Link>(find.byType(Link))
        .map((link) => link.uri.toString())
        .toList();
    expect(links, [
      'https://en.xen.wiki/w/compton%20family',
      'https://en.xen.wiki/w/augmented%20family',
      'https://en.xen.wiki/w/81/80',
      'https://en.xen.wiki/w/128/125',
      'https://en.xen.wiki/w/16/15',
    ]);
    final familyLinkText = tester.widget<Text>(find.text('compton'));
    expect(familyLinkText.style?.decoration, isNull);
    expect(find.text('preimage'), findsOneWidget);
    expect(find.text('WE tuning'), findsOneWidget);
    expect(find.text('CWE tuning'), findsOneWidget);
    expect(find.text('preimage 0'), findsNothing);
    expect(find.text('WE tuning 0'), findsNothing);
    expect(find.text('CWE tuning 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('formats one bracket pair around a complete mapping matrix', () {
    expect(
      formatMatrixText(const [
        [12, 19, 28],
      ]),
      '[ 12  19  28 ]',
    );
    expect(
      formatMatrixText(const [
        [1, 1, 0, -3],
        [0, 1, 4, 10],
      ]),
      '[ 1  1  0  -3\n  0  1  4  10 ]',
    );
  });

  testWidgets('lists each preimage with its tuning values on separate rows', (
    tester,
  ) async {
    const result = TemperamentInfo(
      rank: 3,
      subgroup: '2.3.5.7',
      commaBasis: [],
      equalDivisionsLabel: 'EDOs',
      equalDivisions: ['12', '19', '31'],
      equalDivisionJoinLabel: 'edo join',
      equalDivisionJoin: '12 & 19 & 31',
      mapping: [
        [1, 1, 0, -3],
        [0, 1, 4, 10],
      ],
      preimage: ['2', '3/2', '13/8'],
      tunings: {
        'WE tuning': ['1201.391000000', '697.045000000', '836.333000000'],
        'CWE tuning': ['1200.000000000', '696.651000000', '837.548000000'],
      },
      errors: {
        'WE errors': ['1.391000000', '-4.910000000', '2.340000000'],
        'CWE errors': ['0.000000000', '-5.304000000', '3.555000000'],
      },
      primes: {
        'WE primes': ['1201.391000000', '1898.436000000', '2787.990000000'],
        'CWE primes': ['1200.000000000', '1896.651000000', '2789.199000000'],
      },
      badness: '0.000000000',
      complexity: '3.800000000',
    );

    await tester.pumpWidget(MaterialApp(home: ResultPage(result: result)));

    for (var index = 0; index < result.preimage.length; index++) {
      final labels = [
        'preimage $index',
        'WE tuning $index',
        'CWE tuning $index',
      ];
      final tops = labels
          .map((label) => tester.getTopLeft(find.text(label)).dy)
          .toList();
      expect(tops[0], lessThan(tops[1]));
      expect(tops[1], lessThan(tops[2]));
      if (index < result.preimage.length - 1) {
        expect(
          tops[2],
          lessThan(tester.getTopLeft(find.text('preimage ${index + 1}')).dy),
        );
      }
    }

    expect(
      tester.getTopLeft(find.text('EDOs')).dy,
      lessThan(tester.getTopLeft(find.text('edo join')).dy),
    );
    expect(
      tester.getTopLeft(find.text('edo join')).dy,
      lessThan(tester.getTopLeft(find.text('mapping')).dy),
    );
    expect(
      tester.getTopLeft(find.text('badness')).dy,
      lessThan(tester.getTopLeft(find.text('complexity')).dy),
    );
    expect(find.byKey(const ValueKey('mapping-left-bracket')), findsOneWidget);
    expect(find.byKey(const ValueKey('mapping-right-bracket')), findsOneWidget);
    expect(find.text('1.391000000\n-4.910000000\n2.340000000'), findsOneWidget);
    expect(
      find.text('1201.391000000\n1898.436000000\n2787.990000000'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('applies precision and temperament info visibility settings', (
    tester,
  ) async {
    const result = TemperamentInfo(
      rank: 2,
      subgroup: '2.3.5',
      commaBasis: [],
      equalDivisionsLabel: 'EDOs',
      equalDivisions: ['12'],
      mapping: [
        [1, 1, 0],
      ],
      preimage: ['2'],
      tunings: {
        'WE tuning': ['1201.236000000'],
        'CWE tuning': ['1200.000000000'],
      },
      errors: {
        'WE errors': ['1.236000000'],
        'CWE errors': ['0.000000000'],
      },
      primes: {
        'WE primes': ['1201.236000000'],
        'CWE primes': ['1200.000000000'],
      },
      badness: '0.347000000',
      complexity: '3.800000000',
    );
    const settings = AppSettings(
      tuningDecimalPlaces: 2,
      errorsDecimalPlaces: 3,
      primesDecimalPlaces: 4,
      badnessDecimalPlaces: 1,
      complexityDecimalPlaces: 5,
      visibleTemperamentInfoFields: {
        TemperamentInfoField.tunings,
        TemperamentInfoField.errors,
        TemperamentInfoField.primes,
        TemperamentInfoField.badness,
        TemperamentInfoField.complexity,
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ResultPage(result: result, settings: settings),
      ),
    );

    expect(find.text('rank'), findsNothing);
    expect(find.text('mapping'), findsNothing);
    expect(find.text('preimage'), findsNothing);
    expect(find.text('WE tuning'), findsOneWidget);
    expect(find.text('CWE tuning'), findsNothing);
    expect(find.text('CWE errors'), findsNothing);
    expect(find.text('CWE primes'), findsNothing);
    expect(find.text('1201.24'), findsOneWidget);
    expect(find.text('1.236'), findsOneWidget);
    expect(find.text('1201.2360'), findsOneWidget);
    expect(find.text('0.3'), findsOneWidget);
    expect(find.text('complexity'), findsOneWidget);
    expect(find.text('3.80000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
