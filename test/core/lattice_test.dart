import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/core/double_matrix.dart';
import 'package:temper_calc/core/int_matrix.dart';
import 'package:temper_calc/core/lattice.dart';

void main() {
  group('row HNF', () {
    test('uses positive pivots and reduced entries above them', () {
      expect(
        hnf(
          IntMatrix.fromInts([
            [2, 4],
            [4, 6],
          ]),
        ),
        IntMatrix.fromInts([
          [2, 0],
          [0, 2],
        ]),
      );
      expect(
        hnf(
          IntMatrix.fromInts([
            [-2, -4],
          ]),
        ),
        IntMatrix.fromInts([
          [2, 4],
        ]),
      );
    });

    test('handles arbitrary-precision entries and removes zero rows', () {
      final huge = BigInt.parse('1000000000000000000000000000001');
      final matrix = IntMatrix.fromRows([
        [huge, huge * BigInt.two],
        [huge + BigInt.one, (huge + BigInt.one) * BigInt.two],
      ]);
      expect(
        hnf(matrix, removeZeroRows: true),
        IntMatrix.fromInts([
          [1, 2],
        ]),
      );
    });

    test('is idempotent for deterministic random matrices', () {
      final random = math.Random(4171);
      for (var iteration = 0; iteration < 60; iteration++) {
        final rows = 1 + random.nextInt(5);
        final columns = 1 + random.nextInt(6);
        final matrix = IntMatrix.fromInts(
          List.generate(
            rows,
            (_) => List.generate(columns, (_) => random.nextInt(17) - 8),
          ),
        );
        final reduced = hnf(matrix);
        expect(hnf(reduced), reduced, reason: 'iteration $iteration');
      }
    });
  });

  group('exact integer lattice operations', () {
    test('computes Bareiss determinant including a row swap', () {
      final huge = BigInt.parse('1000000000000000000000000000000');
      final matrix = IntMatrix.fromRows([
        [BigInt.zero, BigInt.one, BigInt.zero],
        [huge, BigInt.zero, BigInt.zero],
        [BigInt.zero, BigInt.zero, BigInt.from(3)],
      ]);
      expect(integerDeterminant(matrix), -(huge * BigInt.from(3)));
      expect(integerDeterminant(IntMatrix.zero(0, 0)), BigInt.one);
    });

    test('finds kernel and the dual cokernel', () {
      final mapping = IntMatrix.fromInts([
        [12, 19, 28],
      ]);
      final commas = kernel(mapping);
      expect(commas.rowCount, 3);
      expect(commas.columnCount, 2);
      expect(mapping.multiply(commas).isZero, isTrue);
      expect(hnf(cokernel(commas)), hnf(mapping));

      final dependent = IntMatrix.fromInts([
        [1, 2],
        [2, 4],
      ]);
      final dependentKernel = kernel(dependent);
      expect(dependentKernel.rowCount, 2);
      expect(dependentKernel.columnCount, 1);
      expect(dependent.multiply(dependentKernel).isZero, isTrue);
    });

    test('returns an explicitly shaped empty kernel for full rank', () {
      final result = kernel(IntMatrix.identity(3));
      expect(result.rowCount, 3);
      expect(result.columnCount, 0);
      expect(cokernel(IntMatrix.identity(3)).rowCount, 0);
      expect(cokernel(IntMatrix.identity(3)).columnCount, 3);
    });

    test('saturates factored mappings', () {
      final factored = IntMatrix.fromInts([
        [2, 4, 6],
      ]);
      expect(factorOrder(factored), BigInt.two);
      expect(
        defactoredHnf(factored),
        IntMatrix.fromInts([
          [1, 2, 3],
        ]),
      );
      expect(factorOrder(defactoredHnf(factored)), BigInt.one);
    });

    test('solves full-column-rank Diophantine systems', () {
      final a = IntMatrix.fromInts([
        [1, 0],
        [0, 1],
        [1, 1],
      ]);
      final expected = IntMatrix.fromInts([
        [2, -1],
        [3, 4],
      ]);
      final b = a.multiply(expected);
      expect(solveDiophantine(a, b), expected);
      expect(
        () => solveDiophantine(
          IntMatrix.fromInts([
            [2],
          ]),
          IntMatrix.fromInts([
            [1],
          ]),
        ),
        throwsStateError,
      );
    });

    test('recovers deterministic random known integer solutions', () {
      final random = math.Random(8128);
      for (var iteration = 0; iteration < 40; iteration++) {
        final columns = 1 + random.nextInt(4);
        final rows = columns + random.nextInt(3);
        final aRows = List.generate(
          rows,
          (row) => List.generate(columns, (column) {
            if (row < columns && row == column) {
              return 1 + random.nextInt(5);
            }
            return random.nextInt(11) - 5;
          }),
        );
        final a = IntMatrix.fromInts(aRows);
        final expected = IntMatrix.fromInts(
          List.generate(
            columns,
            (_) => List.generate(3, (_) => random.nextInt(15) - 7),
          ),
        );
        expect(
          solveDiophantine(a, a.multiply(expected)),
          expected,
          reason: 'iteration $iteration',
        );
      }
    });

    test('finds and validates an integer preimage', () {
      final mapping = IntMatrix.fromInts([
        [1, 2, 3],
        [0, 1, 4],
      ]);
      final generators = preimage(mapping);
      expect(mapping.multiply(generators), IntMatrix.identity(2));
      expect(
        () => preimage(
          IntMatrix.fromInts([
            [2],
          ]),
        ),
        throwsStateError,
      );
    });

    test('cokernel mappings have integer preimages', () {
      final random = math.Random(1729);
      for (var iteration = 0; iteration < 30; iteration++) {
        final dimension = 2 + random.nextInt(4);
        final commaCount = 1 + random.nextInt(dimension - 1);
        final commas = IntMatrix.fromInts(
          List.generate(
            dimension,
            (_) => List.generate(commaCount, (_) => random.nextInt(9) - 4),
          ),
        );
        final mapping = cokernel(commas);
        if (mapping.rowCount == 0) {
          continue;
        }
        expect(
          mapping.multiply(preimage(mapping)),
          IntMatrix.identity(mapping.rowCount),
          reason: 'iteration $iteration',
        );
      }
    });
  });

  group('weighted lattice reduction', () {
    test('reduces columns and orders them by weighted length', () {
      final basis = IntMatrix.fromInts([
        [1, 10],
        [0, 1],
      ]);
      expect(weightedLll(basis), IntMatrix.identity(2));

      final weighted = weightedLll(
        IntMatrix.fromInts([
          [1, 1],
          [0, 2],
        ]),
        weight: DoubleMatrix.diagonal([4, 1]),
      );
      expect(integerDeterminant(weighted).abs(), BigInt.two);
      expect(
        _weightedLength(weighted.column(0), [4, 1]),
        lessThanOrEqualTo(_weightedLength(weighted.column(1), [4, 1])),
      );
    });

    test('nearest plane follows ties-to-even behavior', () {
      final basis = IntMatrix.fromInts([
        [2, 0],
        [0, 2],
      ]);
      expect(nearestPlane([BigInt.one, BigInt.one], basis), [
        BigInt.zero,
        BigInt.zero,
      ]);
      expect(nearestPlane([BigInt.from(3), BigInt.from(3)], basis), [
        BigInt.from(4),
        BigInt.from(4),
      ]);
    });

    test('simplifies interval columns modulo commas', () {
      final intervals = IntMatrix.fromInts([
        [3],
        [3],
      ]);
      final commas = IntMatrix.fromInts([
        [2, 0],
        [0, 2],
      ]);
      expect(
        simplifyIntervals(intervals, commas),
        IntMatrix.fromInts([
          [-1],
          [-1],
        ]),
      );
    });

    test('rejects dependent bases and invalid metrics', () {
      expect(
        () => weightedLllRows(
          IntMatrix.fromInts([
            [1, 0],
            [2, 0],
          ]),
          weight: DoubleMatrix.identity(2),
        ),
        throwsStateError,
      );
      expect(
        () => weightedLll(
          IntMatrix.identity(2),
          weight: DoubleMatrix.fromNums([
            [1, 1],
            [0, 1],
          ]),
        ),
        throwsArgumentError,
      );
    });
  });
}

double _weightedLength(List<BigInt> vector, List<num> diagonal) {
  var result = 0.0;
  for (var index = 0; index < vector.length; index++) {
    final value = vector[index].toDouble();
    result += diagonal[index].toDouble() * value * value;
  }
  return result;
}
