import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/domain/models.dart';
import 'package:temper_calc/domain/temperament_info_service.dart';
import 'package:temper_calc/domain/temperament_search_service.dart';

void main() {
  const service = TemperamentInfoService();
  final nineDecimals = RegExp(r'^-?\d+\.\d{9}$');

  CalculatorInput commaInput({
    required String subgroup,
    required GeneratorReduction reduction,
    String commas = '81/80,225/224',
    String target = '',
  }) => CalculatorInput(
    subgroup: subgroup,
    source: CalculationSource.commas,
    reduction: reduction,
    weight: TuningWeight.weil,
    commas: commas,
    target: target,
  );

  test('matches the 5-limit 12-EDO reference', () {
    final result = service.calculate(
      const CalculatorInput(
        subgroup: '5',
        source: CalculationSource.edos,
        reduction: GeneratorReduction.octave,
        weight: TuningWeight.weil,
        edos: '12',
      ),
    );
    expect(result.mapping, [
      [12, 19, 28],
    ]);
    expect(result.preimage, ['16/15']);
    expect(result.commaBasis.map((value) => value.ratio), ['81/80', '128/125']);
    expect(result.tunings['WE tuning'], ['99.868021226']);
    expect(result.tunings['CWE tuning'], ['100.000000000']);
    expect(result.errors['WE errors'], [
      '-1.583745287',
      '-4.462597570',
      '9.990880465',
    ]);
    expect(result.errors['CWE errors'], [
      '0.000000000',
      '-1.955000865',
      '13.686286135',
    ]);
    expect(result.primes['WE primes'], [
      '1198.416254713',
      '1897.492403295',
      '2796.304594330',
    ]);
    expect(result.primes['CWE primes'], [
      '1200.000000000',
      '1900.000000000',
      '2800.000000000',
    ]);
    expect(result.badness, '0.471479111');
    expect(result.complexity, matches(nineDecimals));
    final searchResult = const TemperamentSearchService().search(
      const SearchInput(
        subgroup: '5',
        badness: BadnessType.dirichlet,
        reduction: GeneratorReduction.octave,
        weight: TuningWeight.weil,
        commas: '81/80',
      ),
    );
    final searchCandidate = searchResult.groups.single.candidates.firstWhere(
      (candidate) => candidate.label == '12',
    );
    expect(
      double.parse(result.complexity),
      closeTo(searchCandidate.complexity, 0.0000000005),
    );
    expect(result.equalDivisionJoinLabel, isNull);
    expect(result.equalDivisionJoin, isNull);
  });

  test('matches septimal meantone mapping, generators, and tuning', () {
    final result = service.calculate(
      commaInput(subgroup: '7', reduction: GeneratorReduction.octave),
    );
    expect(result.mapping, [
      [1, 1, 0, -3],
      [0, 1, 4, 10],
    ]);
    expect(result.preimage, ['2', '3/2']);
    expect(result.tunings['WE tuning'], ['1201.235786007', '697.212160921']);
    expect(result.tunings['CWE tuning'], ['1200.000000000', '696.656198703']);
    expect(result.badness, '0.346892245');
    expect(result.complexity, matches(nineDecimals));
    expect(result.equalDivisionJoinLabel, 'edo join');
    expect(result.equalDivisionJoin, isNotEmpty);
    expect(
      result.equalDivisions.any((value) => value.contains('join:')),
      isFalse,
    );
  });

  test('matches all generator reduction modes', () {
    final expected =
        <GeneratorReduction, ({List<List<int>> map, List<String> gens})>{
          GeneratorReduction.off: (
            map: [
              [1, 0, -4, -13, 0],
              [0, 1, 4, 10, 0],
              [0, 0, 0, 0, 1],
            ],
            gens: ['2', '3', '11'],
          ),
          GeneratorReduction.octave: (
            map: [
              [1, 1, 0, -3, 3],
              [0, 1, 4, 10, 0],
              [0, 0, 0, 0, 1],
            ],
            gens: ['2', '3/2', '11/8'],
          ),
          GeneratorReduction.spine: (
            map: [
              [1, 1, 0, -3, 4],
              [0, 1, 4, 10, -1],
              [0, 0, 0, 0, 1],
            ],
            gens: ['2', '3/2', '33/32'],
          ),
          GeneratorReduction.layout: (
            map: [
              [5, 8, 12, 15, 18],
              [2, 3, 4, 4, 6],
              [0, 0, 0, 0, -1],
            ],
            gens: ['10/9', '16/15', '45/44'],
          ),
        };

    for (final entry in expected.entries) {
      final result = service.calculate(
        commaInput(subgroup: '11', reduction: entry.key),
      );
      expect(result.mapping, entry.value.map, reason: '${entry.key} mapping');
      expect(
        result.preimage,
        entry.value.gens,
        reason: '${entry.key} generators',
      );
    }
  });

  test('supports rational, non-octave, and inferred subgroups', () {
    final rational = service.calculate(
      commaInput(
        subgroup: '2.5.9/7',
        reduction: GeneratorReduction.octave,
        commas: '225/224',
      ),
    );
    expect(rational.mapping, [
      [1, 2, 1],
      [0, 1, -2],
    ]);
    expect(rational.preimage, ['2', '5/4']);
    expect(rational.badness, matches(nineDecimals));
    expect(double.parse(rational.badness), closeTo(0.030, 0.0005));

    final nonOctave = service.calculate(
      const CalculatorInput(
        subgroup: '3.5.7',
        source: CalculationSource.edos,
        reduction: GeneratorReduction.octave,
        weight: TuningWeight.weil,
        edos: '8,13',
      ),
    );
    expect(nonOctave.equalDivisionsLabel, 'edts');
    expect(nonOctave.equalDivisionJoinLabel, 'edt join');
    expect(nonOctave.equalDivisionJoin, isNotEmpty);
    expect(nonOctave.mapping, [
      [1, 1, 2],
      [0, 2, -1],
    ]);

    final inferred = service.calculate(
      commaInput(
        subgroup: '',
        reduction: GeneratorReduction.octave,
        commas: '81/80',
      ),
    );
    expect(inferred.subgroup, '2.3.5');
    expect(inferred.mapping, [
      [1, 1, 0],
      [0, 1, 4],
    ]);
  });

  test('reports target errors in the user subgroup basis', () {
    final result = service.calculate(
      const CalculatorInput(
        subgroup: '2.5/3.7/3.11/3',
        source: CalculationSource.edos,
        reduction: GeneratorReduction.octave,
        weight: TuningWeight.weil,
        edos: '12,19',
        target: '3/2',
      ),
    );
    final errors = result.errors['target errors']!;
    expect(errors, everyElement(matches(nineDecimals)));
    for (final pair in [
      (errors[0], -0.438),
      (errors[1], 4.285),
      (errors[2], -0.501),
      (errors[3], 1.296),
    ]) {
      expect(double.parse(pair.$1), closeTo(pair.$2, 0.0005));
    }
  });

  test('keeps high EDO badness finite and stable', () {
    final result = service.calculate(
      const CalculatorInput(
        subgroup: '5',
        source: CalculationSource.edos,
        reduction: GeneratorReduction.off,
        weight: TuningWeight.tenney,
        edos: '10000,10011',
      ),
    );
    expect(result.mapping, [
      [1, 397, -415],
      [0, -4350, 4591],
    ]);
    expect(result.badness, matches(nineDecimals));
    expect(double.parse(result.badness), closeTo(3580323.193512816, 0.001));
  });
}
