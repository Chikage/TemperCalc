import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/domain/models.dart';
import 'package:temper_calc/domain/temperament_info_service.dart';

void main() {
  const service = TemperamentInfoService();

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
    expect(result.tunings['WE tuning'], ['99.868']);
    expect(result.tunings['CWE tuning'], ['100.000']);
    expect(result.badness, '0.471');
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
    expect(result.tunings['WE tuning'], ['1201.236', '697.212']);
    expect(result.tunings['CWE tuning'], ['1200.000', '696.656']);
    expect(result.badness, '0.347');
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
    expect(rational.badness, '0.030');

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
    expect(result.errors['target errors'], [
      '-0.438',
      '4.285',
      '-0.501',
      '1.296',
    ]);
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
    expect(result.badness, '3580323.097');
  });
}
