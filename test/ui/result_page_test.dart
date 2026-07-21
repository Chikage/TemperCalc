import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      tunings: {},
      errors: {},
      primes: {},
      badness: '0.471',
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('aligns each preimage with both tuning values', (tester) async {
    const result = TemperamentInfo(
      rank: 3,
      subgroup: '2.3.5.7',
      commaBasis: [],
      equalDivisionsLabel: 'EDOs',
      equalDivisions: [],
      mapping: [],
      preimage: ['2', '3/2', '13/8'],
      tunings: {
        'WE tuning': ['1201.391', '697.045', '836.333'],
        'CWE tuning': ['1200.000', '696.651', '837.548'],
      },
      errors: {},
      primes: {},
      badness: '0.000',
    );

    await tester.pumpWidget(MaterialApp(home: ResultPage(result: result)));

    for (var column = 0; column < result.preimage.length; column++) {
      final leftEdges = [
        for (final label in ['preimage', ...result.tunings.keys])
          tester
              .getTopLeft(find.byKey(ValueKey('aligned-value-$label-$column')))
              .dx,
      ];
      expect(leftEdges.toSet(), hasLength(1));
    }
    expect(find.text(', '), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
