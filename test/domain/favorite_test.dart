import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/domain/favorite.dart';
import 'package:temper_calc/domain/models.dart';

const _result = TemperamentInfo(
  rank: 2,
  subgroup: '2.3.5.7',
  families: ['meantone'],
  weakFamilies: ['porcupine'],
  commaBasis: [
    CommaInfo(vector: [-4, 4, -1, 0], ratio: '81/80'),
  ],
  equalDivisionsLabel: 'EDOs',
  equalDivisions: ['12', '19'],
  equalDivisionJoinLabel: 'edo join',
  equalDivisionJoin: '12 & 19',
  mapping: [
    [1, 1, 0, -3],
    [0, 1, 4, 10],
  ],
  preimage: ['2', '3/2'],
  tunings: {
    'WE tuning': ['1201.236', '697.212'],
  },
  errors: {
    'WE errors': ['1.236', '-3.507'],
  },
  primes: {
    'WE primes': ['1201.236', '1898.448'],
  },
  badness: '0.347',
  complexity: '3.800000000',
);

void main() {
  test('calculator favorite title combines query and result summary', () {
    final favorite = FavoriteEntry.fromCalculator(
      input: const CalculatorInput(
        subgroup: ' 7 ',
        source: CalculationSource.commas,
        reduction: GeneratorReduction.octave,
        weight: TuningWeight.weil,
        commas: '81/80,  225/224',
        target: '3/2',
      ),
      result: _result,
      savedAt: DateTime.utc(2026, 7, 21),
    );

    expect(
      favorite.title,
      '7 | Commas 81/80, 225/224 | Targets 3/2 - '
      'Rank 2 | meantone, (porcupine) | Badness 0.347',
    );
    expect(favorite.details, 'Calculate | Octave | WE');
  });

  test('search favorite title includes filters and selected result', () {
    final favorite = FavoriteEntry.fromSearch(
      input: const SearchInput(
        subgroup: '5',
        badness: BadnessType.cangwu,
        reduction: GeneratorReduction.spine,
        weight: TuningWeight.tenney,
        edos: '12, 19',
      ),
      candidate: const SearchCandidate(
        rank: 2,
        label: '81/80',
        source: CalculationSource.commas,
        families: ['meantone'],
        badness: 0.778,
        complexity: 3.8,
      ),
      result: _result,
    );

    expect(
      favorite.title,
      '5 | Cangwu | EDOs 12, 19 | 81/80 - '
      'Rank 2 | meantone, (porcupine) | Badness 0.347',
    );
    expect(favorite.details, 'Search | Spine + commas | TE');
  });

  test('round trips the complete temperament result through JSON', () {
    final original = FavoriteEntry.fromCalculator(
      input: const CalculatorInput(
        subgroup: '7',
        source: CalculationSource.edos,
        reduction: GeneratorReduction.layout,
        weight: TuningWeight.unweighted,
        edos: '12, 19',
      ),
      result: _result,
      savedAt: DateTime.utc(2026, 7, 21, 8, 30),
    );
    final decoded = FavoriteEntry.fromJson(
      (jsonDecode(jsonEncode(original.toJson())) as Map<Object?, Object?>)
          .cast<String, Object?>(),
    );

    expect(decoded.id, original.id);
    expect(decoded.title, original.title);
    expect(decoded.savedAt, original.savedAt);
    expect(decoded.result.rank, _result.rank);
    expect(decoded.result.families, _result.families);
    expect(decoded.result.weakFamilies, _result.weakFamilies);
    expect(decoded.result.commaBasis.single.vector, [-4, 4, -1, 0]);
    expect(decoded.result.commaBasis.single.ratio, '81/80');
    expect(decoded.result.equalDivisions, ['12', '19']);
    expect(decoded.result.equalDivisionJoinLabel, 'edo join');
    expect(decoded.result.equalDivisionJoin, '12 & 19');
    expect(decoded.result.mapping, _result.mapping);
    expect(decoded.result.tunings, _result.tunings);
    expect(decoded.result.errors, _result.errors);
    expect(decoded.result.primes, _result.primes);
    expect(decoded.result.complexity, _result.complexity);
  });

  test('loads legacy favorites without complexity', () {
    final original = FavoriteEntry.fromCalculator(
      input: const CalculatorInput(
        subgroup: '7',
        source: CalculationSource.edos,
        reduction: GeneratorReduction.layout,
        weight: TuningWeight.unweighted,
        edos: '12, 19',
      ),
      result: _result,
    );
    final json = original.toJson();
    (json['result']! as Map<String, Object?>).remove('complexity');

    expect(FavoriteEntry.fromJson(json).result.complexity, 'NA');
  });

  test('migrates a legacy EDO join embedded in the EDO list', () {
    final original = FavoriteEntry.fromCalculator(
      input: const CalculatorInput(
        subgroup: '7',
        source: CalculationSource.edos,
        reduction: GeneratorReduction.octave,
        weight: TuningWeight.weil,
        edos: '12, 19',
      ),
      result: _result,
    );
    final json = original.toJson();
    final resultJson = (json['result']! as Map<String, Object?>);
    resultJson
      ..remove('equalDivisionJoinLabel')
      ..remove('equalDivisionJoin')
      ..['equalDivisions'] = ['12', '19', 'edo join: 12 & 19'];

    final decoded = FavoriteEntry.fromJson(json);

    expect(decoded.result.equalDivisions, ['12', '19']);
    expect(decoded.result.equalDivisionJoinLabel, 'edo join');
    expect(decoded.result.equalDivisionJoin, '12 & 19');
  });
}
