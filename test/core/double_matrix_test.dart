import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/core/double_matrix.dart';

void main() {
  group('DoubleMatrix', () {
    test('multiplies and transposes', () {
      final left = DoubleMatrix.fromNums([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      final right = DoubleMatrix.fromNums([
        [1, 2],
        [0, 1],
        [1, 0],
      ]);
      expect(
        left
            .multiply(right)
            .approximatelyEquals(
              DoubleMatrix.fromNums([
                [4, 4],
                [10, 13],
              ]),
            ),
        isTrue,
      );
      expect(left.transpose().rowCount, 3);
      expect(left.transpose().columnCount, 2);
    });

    test('computes determinant and inverse with pivoting', () {
      final matrix = DoubleMatrix.fromNums([
        [4, 7],
        [2, 6],
      ]);
      expect(matrix.determinant(), closeTo(10.0, 1e-12));
      expect(
        matrix.inverse().approximatelyEquals(
          DoubleMatrix.fromNums([
            [0.6, -0.7],
            [-0.2, 0.4],
          ]),
        ),
        isTrue,
      );
      expect(
        matrix
            .multiply(matrix.inverse())
            .approximatelyEquals(DoubleMatrix.identity(2)),
        isTrue,
      );
    });

    test('solves matrix and vector right-hand sides', () {
      final matrix = DoubleMatrix.fromNums([
        [3, 1],
        [1, 2],
      ]);
      expect(matrix.solveVector([9, 8]), orderedEquals([2.0, 3.0]));
      final solution = matrix.solve(
        DoubleMatrix.fromNums([
          [9, 1],
          [8, 0],
        ]),
      );
      expect(
        matrix
            .multiply(solution)
            .approximatelyEquals(
              DoubleMatrix.fromNums([
                [9, 1],
                [8, 0],
              ]),
            ),
        isTrue,
      );
    });

    test('handles consistently scaled small matrices', () {
      final matrix = DoubleMatrix.diagonal([1e-20, 2e-20]);
      expect(matrix.determinant(), closeTo(2e-40, 1e-52));
      expect(
        matrix
            .multiply(matrix.inverse())
            .approximatelyEquals(DoubleMatrix.identity(2)),
        isTrue,
      );
    });

    test('solves deterministic random diagonally dominant systems', () {
      final random = math.Random(65537);
      for (var iteration = 0; iteration < 40; iteration++) {
        final size = 1 + random.nextInt(6);
        final rows = List.generate(
          size,
          (row) => List.generate(size, (column) {
            if (row == column) {
              return 10.0 + random.nextDouble();
            }
            return random.nextDouble() * 2.0 - 1.0;
          }),
        );
        final matrix = DoubleMatrix.fromRows(rows);
        final expected = List.generate(
          size,
          (_) => random.nextDouble() * 10.0 - 5.0,
        );
        final right = matrix.multiplyVector(expected);
        final actual = matrix.solveVector(right);
        for (var index = 0; index < size; index++) {
          expect(
            actual[index],
            closeTo(expected[index], 1e-10),
            reason: 'iteration $iteration, index $index',
          );
        }
      }
    });

    test('rejects singular, malformed, and non-finite matrices', () {
      final singular = DoubleMatrix.fromNums([
        [1, 2],
        [2, 4],
      ]);
      expect(singular.inverse, throwsStateError);
      expect(
        () => DoubleMatrix.fromRows([
          [double.nan],
        ]),
        throwsArgumentError,
      );
      expect(
        () => DoubleMatrix.fromNums([
          [1, 2],
          [3],
        ]),
        throwsArgumentError,
      );
    });

    test('preserves empty dimensions', () {
      final matrix = DoubleMatrix.zero(2, 0);
      expect(matrix.transpose().rowCount, 0);
      expect(matrix.transpose().columnCount, 2);
      expect(DoubleMatrix.zero(0, 0).determinant(), 1.0);
    });
  });
}
