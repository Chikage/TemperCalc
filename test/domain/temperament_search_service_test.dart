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
    SearchParameters parameters = const SearchParameters(),
  }) => SearchInput(
    subgroup: subgroup,
    badness: badness,
    reduction: GeneratorReduction.octave,
    weight: TuningWeight.weil,
    edos: edos,
    commas: commas,
    parameters: parameters,
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

  test('honors configurable dimension and per-rank result limits', () {
    final limitedDimension = service.search(
      input(
        subgroup: '7',
        badness: BadnessType.cangwu,
        parameters: const SearchParameters(maximumDimension: 3),
      ),
    );
    expect(limitedDimension.groups, isEmpty);
    expect(limitedDimension.warning, contains('3'));

    final limitedResults = service.search(
      input(
        subgroup: '5',
        badness: BadnessType.cangwu,
        edos: '12',
        parameters: const SearchParameters(resultsPerRank: 2),
      ),
    );
    expect(limitedResults.groups.single.candidates, hasLength(2));
  });

  test(
    'parallel search matches serial results across independent ranks',
    () async {
      const parallel = ParallelTemperamentSearchService(maximumWorkers: 2);
      final inputs = [
        input(subgroup: '7', badness: BadnessType.cangwu, edos: '12'),
        input(subgroup: '7', badness: BadnessType.dirichlet, commas: '81/80'),
      ];

      for (final searchInput in inputs) {
        final serialResult = service.search(searchInput);
        final parallelResult = await parallel.search(
          searchInput,
          timeout: const Duration(seconds: 10),
        );
        expect(_resultSnapshot(parallelResult), _resultSnapshot(serialResult));
      }
    },
  );

  test('parallel search can time out and run again', () async {
    const parallel = ParallelTemperamentSearchService(maximumWorkers: 2);
    final searchInput = input(
      subgroup: '89',
      badness: BadnessType.cangwu,
      parameters: const SearchParameters(explorationIterations: 1000),
    );

    await expectLater(
      parallel.search(searchInput, timeout: Duration.zero),
      throwsA(
        isA<TemperamentException>().having(
          (error) => error.message,
          'message',
          'Search took too long',
        ),
      ),
    );

    final recovered = await parallel.search(
      input(subgroup: '3', badness: BadnessType.cangwu, edos: '12'),
      timeout: const Duration(seconds: 5),
    );
    expect(recovered.warning, 'Empty search');
  });
}

Object _resultSnapshot(TemperamentSearchResult result) => {
  'warning': result.warning,
  'groups': [
    for (final group in result.groups)
      {
        'rank': group.rank,
        'candidates': [
          for (final candidate in group.candidates)
            {
              'rank': candidate.rank,
              'label': candidate.label,
              'source': candidate.source.name,
              'families': candidate.families,
              'badness': candidate.badness,
              'complexity': candidate.complexity,
            },
        ],
      },
  ],
};
