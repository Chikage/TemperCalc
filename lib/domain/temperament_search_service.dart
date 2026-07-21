import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import '../core/double_matrix.dart';
import '../core/int_matrix.dart';
import '../core/lattice.dart';
import '../core/rational.dart';
import 'family_catalog.dart';
import 'input_parser.dart';
import 'interval.dart';
import 'metrics.dart';
import 'models.dart';
import 'temperament_builder.dart';

const _maximumCommaCoefficient = 2000;
const _combinationBudget = 320;

class TemperamentSearchService {
  const TemperamentSearchService();

  TemperamentSearchResult search(SearchInput input) {
    return _handleSearchErrors(() => _completeSearch(_prepareSearch(input)));
  }
}

class ParallelTemperamentSearchService {
  const ParallelTemperamentSearchService({this.maximumWorkers = 4})
    : assert(maximumWorkers >= 1);

  final int maximumWorkers;

  Future<TemperamentSearchResult> search(
    SearchInput input, {
    required Duration timeout,
  }) async {
    final manager = _SearchWorkerManager();
    final availableWorkers = math.max(1, Platform.numberOfProcessors - 1);
    final workerLimit = math.min(maximumWorkers, availableWorkers);
    try {
      return await _run(manager, input, workerLimit).timeout(timeout);
    } on TimeoutException {
      throw const TemperamentException('Search took too long');
    } finally {
      manager.close();
    }
  }

  Future<TemperamentSearchResult> _run(
    _SearchWorkerManager manager,
    SearchInput input,
    int workerLimit,
  ) async {
    final plan = await manager.run(
      _prepareSearchWorker,
      _PrepareSearchRequest(input, workerLimit > 1),
    );
    final completed = plan.result;
    if (completed != null) return completed;

    final prepared = plan.prepared!;
    final workerCount = math.min(workerLimit, plan.ranks.length);
    final batches = List.generate(workerCount, (_) => <int>[]);
    for (var index = 0; index < plan.ranks.length; index++) {
      batches[index % workerCount].add(plan.ranks[index]);
    }
    final results = await Future.wait(
      batches.map(
        (ranks) => manager.run(
          _searchRankBatchWorker,
          _SearchRankBatch(prepared, List.unmodifiable(ranks)),
        ),
      ),
      eagerError: true,
    );
    final groups = results.expand((batch) => batch).toList()
      ..sort((left, right) => left.rank.compareTo(right.rank));
    return TemperamentSearchResult(groups: List.unmodifiable(groups));
  }
}

T _handleSearchErrors<T>(T Function() body) {
  try {
    return body();
  } on TemperamentException {
    rethrow;
  } on RangeError {
    throw const TemperamentException('A search exceeded the supported range');
  } on ArgumentError catch (error) {
    throw TemperamentException(error.message?.toString() ?? 'Invalid search');
  } on StateError catch (error) {
    throw TemperamentException(error.message);
  }
}

_SearchPlan _prepareSearch(SearchInput input) {
  final subgroupDefinition = parseSubgroup(input.subgroup);
  final basis = subgroupDefinition.basis;
  final expanded = subgroupDefinition.expanded;
  final subgroup = subgroupDefinition.subgroup;
  final expandedSubgroup = expanded
      .map(Rational.fromInt)
      .toList(growable: false);
  final nonPrimeSubgroup =
      basis.rowCount != basis.columnCount ||
      basis != IntMatrix.identity(basis.rowCount);

  var initialMap = IntMatrix.identity(subgroup.length);
  var searchUp = false;
  if (input.edos.trim().isNotEmpty) {
    initialMap = temperamentFromEdos(input.edos, basis, expanded).mapping;
    searchUp = true;
  } else if (input.commas.trim().isNotEmpty) {
    initialMap = temperamentFromCommas(input.commas, basis, expanded).mapping;
  }

  final rank = initialMap.rowCount;
  final dimension = initialMap.columnCount;
  if (dimension > input.parameters.maximumDimension) {
    return _SearchPlan.completed(
      TemperamentSearchResult(
        groups: const [],
        warning:
            'Search is limited to subgroup dimensions of '
            '${input.parameters.maximumDimension} or less',
      ),
    );
  }

  final subgroupSize = expanded
      .map((prime) => math.log(prime) / math.ln2)
      .reduce(math.max);
  final tenney = projectedSubgroupMetric(basis, metricTenney(expandedSubgroup));
  final tenneyInverse = normalizeDeterminant(_symmetric(tenney.inverse()));
  final cangwuK = 800.0 * math.sqrt(rank / 4.0);
  final weil = projectedSubgroupMetric(
    basis,
    metricWeilK(expandedSubgroup, cangwuK),
  );
  final weilInverse = normalizeDeterminant(_symmetric(weil.inverse()));
  final wilson = _symmetric(
    projectedSubgroupMetric(basis, metricWilson(expandedSubgroup)),
  );
  final edoMetric = _symmetric(
    projectedSubgroupMetric(
      basis,
      metricWeilK(expandedSubgroup, 1200.0 * subgroupSize),
    ).inverse(),
  );
  final calibration = height(
    DoubleMatrix.fromIntMatrix(patentMap(41.0, subgroup)),
    tenneyInverse,
  );
  if (calibration == null) {
    throw const TemperamentException('Could not calibrate search complexity');
  }
  final complexityFactor = 41.0 / calibration;

  final checked = <String>{};
  // LLL exploration is stateful; the completed rank jobs are independent.
  late final List<int> ranks;
  late final List<_SearchEntry> baseEntries;
  late final List<_SearchEntry> combinationEntries;
  late final int baseRank;
  late final int maximumPerRank;

  if (searchUp) {
    if (rank + 1 >= dimension) {
      return const _SearchPlan.completed(
        TemperamentSearchResult(groups: [], warning: 'Empty search'),
      );
    }
    ranks = List.generate(dimension - rank - 1, (index) => rank + index + 1);
    var lattice = kernel(initialMap);
    var factor = 8.0 * subgroupSize;
    final growth = math.min(1.4 * math.pow(1.1, dimension - 1), 2.0);
    final commas = <_SearchEntry>[];
    for (
      var iteration = 0;
      iteration < input.parameters.explorationIterations;
      iteration++
    ) {
      try {
        final metric = _symmetric(
          projectedSubgroupMetric(basis, metricWeilK(expandedSubgroup, factor)),
        );
        lattice = weightedLll(lattice, weight: metric);
      } on StateError {
        break;
      } on ArgumentError {
        break;
      }
      if (lattice.flatten().any(
        (value) => value.abs() > BigInt.from(_maximumCommaCoefficient),
      )) {
        break;
      }
      factor *= growth;
      for (var column = 0; column < lattice.columnCount; column++) {
        final comma = makePositive(lattice.column(column), subgroup);
        final commaMatrix = IntMatrix.fromRows(
          comma.map((value) => [value]),
          columnCount: 1,
        );
        var label = ratioFromVector(comma, subgroup).toString();
        if (label.length >= 11) label = '[${comma.join(' ')}]';
        final mapping = cokernel(commaMatrix);
        final entry = _SearchEntry(
          label,
          mapping,
          _mappingBadness(
            input.badness,
            mapping,
            subgroup,
            tenneyInverse,
            weilInverse,
          ),
        );
        final key = _vectorKey(comma);
        if (checked.add(key)) {
          commas.add(entry.copyWithVector(comma));
        }
      }
    }
    final baseRankEntries = List<_SearchEntry>.of(commas);
    commas.sort((left, right) => left.badness.compareTo(right.badness));
    maximumPerRank = math.max(
      input.parameters.resultsPerRank,
      _combinationBudget ~/ math.max(1, dimension - 2),
    );
    baseEntries = List.unmodifiable(baseRankEntries);
    combinationEntries = List.unmodifiable(commas);
    baseRank = dimension - 1;
  } else {
    if (rank == 1) {
      return const _SearchPlan.completed(
        TemperamentSearchResult(groups: [], warning: 'Empty search'),
      );
    }
    ranks = List.generate(rank - 1, (index) => index + 1);
    var factor = 16.0 * math.sqrt(rank) * subgroupSize;
    final growth = 1.4 * math.pow(1.1, dimension - 1);
    var lattice = initialMap;
    final edos = <_SearchEntry>[];
    for (
      var iteration = 0;
      iteration < input.parameters.explorationIterations;
      iteration++
    ) {
      try {
        final metric = _symmetric(
          projectedSubgroupMetric(
            basis,
            metricWeilK(expandedSubgroup, factor),
          ).inverse(),
        );
        lattice = weightedLll(lattice.transpose(), weight: metric).transpose();
      } on StateError {
        break;
      } on ArgumentError {
        break;
      }
      factor *= growth;
      final found = _absolute(lattice);
      if (found.values.any(
        (row) => row.first > BigInt.from(input.parameters.maximumEdo * 2),
      )) {
        break;
      }
      for (final row in found.values) {
        if (row.first < BigInt.two ||
            row.first > BigInt.from(input.parameters.maximumEdo)) {
          continue;
        }
        final mapping = IntMatrix.fromRows([row]);
        final entry = _SearchEntry(
          edoMapNotation(row, subgroup),
          mapping,
          _mappingBadness(
            input.badness,
            mapping,
            subgroup,
            tenneyInverse,
            weilInverse,
          ),
        );
        if (checked.add(_matrixKey(mapping))) {
          edos.add(entry);
        }
      }
    }
    final baseRankEntries = List<_SearchEntry>.of(edos);
    edos.sort((left, right) => left.badness.compareTo(right.badness));
    maximumPerRank = math.max(
      input.parameters.resultsPerRank,
      _combinationBudget ~/ math.max(1, rank - 2),
    );
    baseEntries = List.unmodifiable(baseRankEntries);
    combinationEntries = List.unmodifiable(edos);
    baseRank = 1;
  }

  return _SearchPlan.ready(
    _PreparedSearch(
      badnessType: input.badness,
      searchUp: searchUp,
      dimension: dimension,
      subgroup: List.unmodifiable(subgroup),
      expanded: List.unmodifiable(expanded),
      basis: basis,
      nonPrimeSubgroup: nonPrimeSubgroup,
      tenneyInverse: tenneyInverse,
      weilInverse: weilInverse,
      wilson: wilson,
      edoMetric: edoMetric,
      complexityFactor: complexityFactor,
      resultsPerRank: input.parameters.resultsPerRank,
      maximumPerRank: maximumPerRank,
      baseRank: baseRank,
      baseEntries: baseEntries,
      combinationEntries: combinationEntries,
    ),
    List.unmodifiable(ranks),
  );
}

TemperamentSearchResult _completeSearch(_SearchPlan plan) {
  final completed = plan.result;
  if (completed != null) return completed;
  final prepared = plan.prepared!;
  final groups = plan.ranks
      .map((rank) => _searchRank(prepared, rank))
      .whereType<SearchGroup>()
      .toList(growable: false);
  return TemperamentSearchResult(groups: List.unmodifiable(groups));
}

SearchGroup? _searchRank(_PreparedSearch prepared, int candidateRank) {
  final entries = <_SearchEntry>[];
  if (candidateRank == prepared.baseRank) {
    entries.addAll(prepared.baseEntries);
  } else if (prepared.searchUp) {
    final checked = <String>{};
    final commaCount = prepared.dimension - candidateRank;
    var count = 0;
    for (final indices in combinationsBySum(
      commaCount,
      0,
      prepared.combinationEntries.length - 1,
    )) {
      final selected = indices
          .map((index) => prepared.combinationEntries[index])
          .toList();
      final commaMatrix = IntMatrix.fromRows(
        List.generate(
          prepared.dimension,
          (row) => selected.map((entry) => entry.vector![row]),
        ),
        columnCount: selected.length,
      );
      final mapping = cokernel(commaMatrix);
      if (_hasZeroColumn(mapping) || !checked.add(_matrixKey(mapping))) {
        continue;
      }
      entries.add(
        _SearchEntry(
          selected.map((entry) => entry.label).join(', '),
          mapping,
          _mappingBadness(
            prepared.badnessType,
            mapping,
            prepared.subgroup,
            prepared.tenneyInverse,
            prepared.weilInverse,
          ),
        ),
      );
      count++;
      if (count >= prepared.maximumPerRank) break;
    }
  } else {
    final checked = <String>{};
    var count = 0;
    for (final indices in combinationsBySum(
      candidateRank,
      0,
      prepared.combinationEntries.length - 1,
    )) {
      final selected = indices
          .map((index) => prepared.combinationEntries[index])
          .toList();
      final mapping = hnf(
        IntMatrix.verticalStack(selected.map((entry) => entry.mapping)),
      );
      if (mapping.values.any(_isZeroVector) ||
          !checked.add(_matrixKey(mapping))) {
        continue;
      }
      selected.sort(
        (left, right) => left.mapping[0][0].compareTo(right.mapping[0][0]),
      );
      entries.add(
        _SearchEntry(
          selected.map((entry) => entry.label).join(' & '),
          mapping,
          _mappingBadness(
            prepared.badnessType,
            mapping,
            prepared.subgroup,
            prepared.tenneyInverse,
            prepared.weilInverse,
          ),
        ),
      );
      count++;
      if (count >= prepared.maximumPerRank) break;
    }
  }

  entries.sort((left, right) => left.badness.compareTo(right.badness));
  final candidates = <SearchCandidate>[];
  for (final entry in entries) {
    if (candidates.length >= prepared.resultsPerRank) break;
    if (factorOrder(entry.mapping) > BigInt.one) continue;
    final mapHeight = height(
      DoubleMatrix.fromIntMatrix(entry.mapping),
      prepared.tenneyInverse,
    );
    if (mapHeight == null) continue;
    final complexity =
        math.pow(2.0, entry.mapping.rowCount - 1) *
        mapHeight *
        prepared.complexityFactor;
    final expandedMapping = prepared.nonPrimeSubgroup
        ? hnf(cokernel(prepared.basis.multiply(kernel(entry.mapping))))
        : entry.mapping;
    final matches = searchFamilies(prepared.expanded, expandedMapping);
    final familyNames = <String>[
      ...matches.strong.toList()..sort(),
      if (matches.strong.isEmpty)
        ...((matches.weak.toList()..sort()).map((name) => '($name)')),
    ];

    var label = entry.label;
    var source = prepared.searchUp
        ? CalculationSource.commas
        : CalculationSource.edos;
    if (prepared.searchUp &&
        candidateRank <= prepared.dimension - candidateRank) {
      var newBasis = weightedLll(
        entry.mapping.transpose(),
        weight: prepared.edoMetric,
      ).transpose();
      newBasis = _positiveFirstEntryRows(newBasis);
      final rows = newBasis.values.map(List<BigInt>.of).toList()
        ..sort((left, right) => left.first.compareTo(right.first));
      label = rows
          .map((row) => edoMapNotation(row, prepared.subgroup))
          .join(' & ');
      source = CalculationSource.edos;
    } else if (!prepared.searchUp &&
        candidateRank > prepared.dimension - candidateRank) {
      final reducedCommas = weightedLll(
        kernel(entry.mapping),
        weight: prepared.wilson,
      );
      final labels = <String>[];
      for (var column = 0; column < reducedCommas.columnCount; column++) {
        final comma = makePositive(
          reducedCommas.column(column),
          prepared.subgroup,
        );
        var commaLabel = ratioFromVector(comma, prepared.subgroup).toString();
        if (commaLabel.length >= 11) commaLabel = '[${comma.join(' ')}]';
        labels.add(commaLabel);
      }
      label = labels.join(', ');
      source = CalculationSource.commas;
    }
    candidates.add(
      SearchCandidate(
        rank: candidateRank,
        label: label,
        source: source,
        families: List.unmodifiable(familyNames),
        badness: entry.badness == 0.0 ? null : entry.badness,
        complexity: complexity.toDouble(),
      ),
    );
  }
  return candidates.isEmpty
      ? null
      : SearchGroup(rank: candidateRank, candidates: candidates);
}

double _mappingBadness(
  BadnessType type,
  IntMatrix mapping,
  List<Rational> subgroup,
  DoubleMatrix tenneyInverse,
  DoubleMatrix weilInverse,
) {
  if (type == BadnessType.dirichlet) {
    return temperamentBadness(mapping, subgroup, weight: tenneyInverse) ?? 0.0;
  }
  return height(DoubleMatrix.fromIntMatrix(mapping), weilInverse) ?? 0.0;
}

final class _SearchPlan {
  const _SearchPlan.completed(this.result) : prepared = null, ranks = const [];

  const _SearchPlan.ready(this.prepared, this.ranks) : result = null;

  final TemperamentSearchResult? result;
  final _PreparedSearch? prepared;
  final List<int> ranks;
}

final class _PreparedSearch {
  const _PreparedSearch({
    required this.badnessType,
    required this.searchUp,
    required this.dimension,
    required this.subgroup,
    required this.expanded,
    required this.basis,
    required this.nonPrimeSubgroup,
    required this.tenneyInverse,
    required this.weilInverse,
    required this.wilson,
    required this.edoMetric,
    required this.complexityFactor,
    required this.resultsPerRank,
    required this.maximumPerRank,
    required this.baseRank,
    required this.baseEntries,
    required this.combinationEntries,
  });

  final BadnessType badnessType;
  final bool searchUp;
  final int dimension;
  final List<Rational> subgroup;
  final List<int> expanded;
  final IntMatrix basis;
  final bool nonPrimeSubgroup;
  final DoubleMatrix tenneyInverse;
  final DoubleMatrix weilInverse;
  final DoubleMatrix wilson;
  final DoubleMatrix edoMetric;
  final double complexityFactor;
  final int resultsPerRank;
  final int maximumPerRank;
  final int baseRank;
  final List<_SearchEntry> baseEntries;
  final List<_SearchEntry> combinationEntries;
}

final class _PrepareSearchRequest {
  const _PrepareSearchRequest(this.input, this.useParallelRanks);

  final SearchInput input;
  final bool useParallelRanks;
}

final class _SearchRankBatch {
  const _SearchRankBatch(this.prepared, this.ranks);

  final _PreparedSearch prepared;
  final List<int> ranks;
}

void _prepareSearchWorker((SendPort, _PrepareSearchRequest) message) {
  _sendSearchWorkerResult(message.$1, () {
    final plan = _handleSearchErrors(() => _prepareSearch(message.$2.input));
    if (!message.$2.useParallelRanks || plan.ranks.length < 2) {
      return _SearchPlan.completed(
        _handleSearchErrors(() => _completeSearch(plan)),
      );
    }
    return plan;
  });
}

void _searchRankBatchWorker((SendPort, _SearchRankBatch) message) {
  _sendSearchWorkerResult(
    message.$1,
    () => _handleSearchErrors(
      () => message.$2.ranks
          .map((rank) => _searchRank(message.$2.prepared, rank))
          .whereType<SearchGroup>()
          .toList(growable: false),
    ),
  );
}

void _sendSearchWorkerResult<T>(SendPort sendPort, T Function() body) {
  try {
    sendPort.send([true, body()]);
  } catch (error) {
    sendPort.send([false, error.toString()]);
  }
}

final class _SearchWorkerManager {
  final Set<void Function()> _cancellations = {};
  bool _closed = false;

  Future<T> run<T, I>(void Function((SendPort, I)) worker, I input) async {
    if (_closed) throw const _SearchWorkersCancelled();

    final receivePort = ReceivePort();
    final completer = Completer<T>();
    StreamSubscription<Object?>? subscription;
    Isolate? isolate;
    var stopped = false;
    late final void Function() cancel;
    cancel = () {
      stopped = true;
      isolate?.kill(priority: Isolate.immediate);
      unawaited(subscription?.cancel());
      receivePort.close();
      if (!completer.isCompleted) {
        completer.completeError(const _SearchWorkersCancelled());
      }
    };
    _cancellations.add(cancel);

    try {
      subscription = receivePort.listen((message) {
        if (completer.isCompleted) return;
        if (message case [true, final T result]) {
          completer.complete(result);
        } else if (message case [false, final Object error]) {
          completer.completeError(TemperamentException(error.toString()));
        } else {
          completer.completeError(
            const TemperamentException('Search worker returned invalid data'),
          );
        }
      });
      unawaited(
        Isolate.spawn(worker, (
          receivePort.sendPort,
          input,
        ), debugName: 'Temper Calc search worker').then<void>(
          (spawned) {
            if (stopped || _closed) {
              spawned.kill(priority: Isolate.immediate);
            } else {
              isolate = spawned;
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          },
        ),
      );
      return await completer.future;
    } finally {
      stopped = true;
      _cancellations.remove(cancel);
      isolate?.kill(priority: Isolate.immediate);
      unawaited(subscription?.cancel());
      receivePort.close();
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final cancel in _cancellations.toList(growable: false)) {
      cancel();
    }
    _cancellations.clear();
  }
}

final class _SearchWorkersCancelled implements Exception {
  const _SearchWorkersCancelled();
}

class _SearchEntry {
  const _SearchEntry(this.label, this.mapping, this.badness, [this.vector]);

  final String label;
  final IntMatrix mapping;
  final double badness;
  final List<BigInt>? vector;

  _SearchEntry copyWithVector(List<BigInt> value) =>
      _SearchEntry(label, mapping, badness, List.unmodifiable(value));
}

Iterable<List<int>> combinationsBySum(
  int size,
  int minimum,
  int maximum,
) sync* {
  if (size <= 0 || maximum < minimum || size > maximum - minimum + 1) return;
  final minimumTotal = minimum * size + size * (size - 1) ~/ 2;
  final maximumTotal = maximum * size - size * (size - 1) ~/ 2;
  for (var total = minimumTotal; total <= maximumTotal; total++) {
    yield* _combinationsOfSum(total, size, minimum, maximum);
  }
}

Iterable<List<int>> _combinationsOfSum(
  int total,
  int size,
  int minimum,
  int maximum,
) sync* {
  if (size == 1) {
    if (total >= minimum && total <= maximum) yield [total];
    return;
  }
  final base = List<int>.generate(size, (index) => minimum + index);
  base[size - 1] = math
      .min(
        total - base.take(size - 1).fold<int>(0, (sum, value) => sum + value),
        maximum,
      )
      .toInt();
  var maximumOffset = base[size - 1] - base[size - 2] - 1;
  var totalOffset = total - base.fold<int>(0, (sum, value) => sum + value);
  final minimumLast = (total + size * (size - 1) ~/ 2) ~/ size;
  while (base[size - 1] > base[size - 2] && base[size - 1] >= minimumLast) {
    for (final offsets in _offsets(size - 1, totalOffset, maximumOffset)) {
      yield List<int>.generate(
        size,
        (index) => base[index] + (index < offsets.length ? offsets[index] : 0),
      );
    }
    base[size - 1]--;
    totalOffset++;
    maximumOffset--;
  }
}

Iterable<List<int>> _offsets(int size, int total, int maximum) sync* {
  if (total == 0) {
    yield List<int>.filled(size, 0);
    return;
  }
  if (size == 1 && total == maximum) {
    yield [maximum];
    return;
  }
  var value = maximum;
  while (total >= 0 && total <= size * value) {
    for (final prefix in _offsets(size - 1, total - value, value)) {
      yield [...prefix, value];
    }
    value--;
  }
}

bool _hasZeroColumn(IntMatrix matrix) {
  for (var column = 0; column < matrix.columnCount; column++) {
    if (_isZeroVector(matrix.column(column))) return true;
  }
  return false;
}

bool _isZeroVector(List<BigInt> vector) =>
    vector.every((value) => value == BigInt.zero);

String _vectorKey(List<BigInt> vector) => vector.join(',');
String _matrixKey(IntMatrix matrix) =>
    '${matrix.rowCount}x${matrix.columnCount}:${matrix.flatten().join(',')}';

IntMatrix _absolute(IntMatrix matrix) => IntMatrix.fromRows(
  matrix.values.map((row) => row.map((value) => value.abs())),
  columnCount: matrix.columnCount,
);

IntMatrix _positiveFirstEntryRows(IntMatrix matrix) => IntMatrix.fromRows(
  matrix.values.map((row) {
    if (row.isNotEmpty && row.first < BigInt.zero) {
      return row.map((value) => -value);
    }
    return row;
  }),
  columnCount: matrix.columnCount,
);

DoubleMatrix _symmetric(DoubleMatrix matrix) => DoubleMatrix.fromRows(
  List.generate(
    matrix.rowCount,
    (row) => List.generate(
      matrix.columnCount,
      (column) => (matrix[row][column] + matrix[column][row]) / 2.0,
    ),
  ),
  columnCount: matrix.columnCount,
);
