import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/domain/models.dart';
import 'package:temper_calc/domain/temperament_search_service.dart';

void main() {
  const service = TemperamentSearchService();

  SearchInput input({
    required String subgroup,
    required BadnessType badness,
    String edos = '',
    String commas = '',
  }) => SearchInput(
    subgroup: subgroup,
    badness: badness,
    reduction: GeneratorReduction.octave,
    weight: TuningWeight.weil,
    edos: edos,
    commas: commas,
  );

  test('combination iterator follows upstream sum order', () {
    expect(combinationsBySum(2, 0, 3), [
      [0, 1],
      [0, 2],
      [0, 3],
      [1, 2],
      [1, 3],
      [2, 3],
    ]);
  });

  test('searches upward from 12-EDO with Cangwu badness', () {
    final result = service.search(
      input(subgroup: '5', badness: BadnessType.cangwu, edos: '12'),
    );
    expect(result.warning, isNull);
    expect(result.groups.single.rank, 2);
    final candidates = result.groups.single.candidates;
    expect(candidates.take(3).map((value) => value.label), [
      '81/80',
      '2048/2025',
      '128/125',
    ]);
    expect(
      candidates.take(3).map((value) => value.badness!.toStringAsFixed(3)),
      ['0.778', '1.099', '1.235'],
    );
  });

  test('searches downward from meantone with Dirichlet badness', () {
    final result = service.search(
      input(subgroup: '5', badness: BadnessType.dirichlet, commas: '81/80'),
    );
    final candidates = result.groups.single.candidates;
    expect(candidates.take(4).map((value) => value.label), [
      '12',
      '7',
      '19',
      '5',
    ]);
    expect(
      candidates.take(4).map((value) => value.badness!.toStringAsFixed(3)),
      ['0.471', '0.514', '0.575', '0.697'],
    );
  });

  test(
    'reports empty searches and supports subgroup dimensions through 24',
    () {
      final empty = service.search(
        input(subgroup: '3', badness: BadnessType.cangwu, edos: '12'),
      );
      expect(empty.groups, isEmpty);
      expect(empty.warning, 'Empty search');

      final largestSupported = service.search(
        input(subgroup: '89', badness: BadnessType.cangwu),
      );
      expect(largestSupported.warning, isNull);
      expect(largestSupported.groups, isNotEmpty);
      expect(
        largestSupported.groups.every((group) => group.candidates.isNotEmpty),
        isTrue,
      );
      expect(
        largestSupported.groups.any((group) => group.candidates.length > 12),
        isTrue,
      );

      final oversized = service.search(
        input(subgroup: '97', badness: BadnessType.cangwu),
      );
      expect(oversized.groups, isEmpty);
      expect(oversized.warning, contains('24'));
    },
  );
}
