import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/core/int_matrix.dart';

void main() {
  group('IntMatrix', () {
    test('validates rectangular input', () {
      expect(
        () => IntMatrix.fromInts([
          [1, 2],
          [3],
        ]),
        throwsArgumentError,
      );
    });

    test('preserves explicit zero-dimensional shapes', () {
      final matrix = IntMatrix.zero(3, 0);
      final transposed = matrix.transpose();
      expect(transposed.rowCount, 0);
      expect(transposed.columnCount, 3);
      expect(transposed.transpose(), matrix);
    });

    test('transposes, slices, and removes zero rows', () {
      final matrix = IntMatrix.fromInts([
        [1, 2, 3],
        [0, 0, 0],
        [4, 5, 6],
      ]);
      expect(
        matrix.transpose(),
        IntMatrix.fromInts([
          [1, 0, 4],
          [2, 0, 5],
          [3, 0, 6],
        ]),
      );
      expect(
        matrix.submatrix(0, 2, 1, 3),
        IntMatrix.fromInts([
          [2, 3],
          [0, 0],
        ]),
      );
      expect(
        matrix.withoutZeroRows(),
        IntMatrix.fromInts([
          [1, 2, 3],
          [4, 5, 6],
        ]),
      );
    });

    test('adds and multiplies exactly', () {
      final left = IntMatrix.fromInts([
        [1, 2],
        [3, 4],
      ]);
      final right = IntMatrix.fromInts([
        [5, 6],
        [7, 8],
      ]);
      expect(
        left.add(right),
        IntMatrix.fromInts([
          [6, 8],
          [10, 12],
        ]),
      );
      expect(
        left.multiply(right),
        IntMatrix.fromInts([
          [19, 22],
          [43, 50],
        ]),
      );
      expect(left.multiplyVector([BigInt.one, BigInt.two]), [
        BigInt.from(5),
        BigInt.from(11),
      ]);
    });

    test('stacks blocks and preserves shape', () {
      final top = IntMatrix.fromInts([
        [1, 2],
      ]);
      final bottom = IntMatrix.fromInts([
        [3, 4],
      ]);
      expect(
        IntMatrix.verticalStack([top, bottom]),
        IntMatrix.fromInts([
          [1, 2],
          [3, 4],
        ]),
      );
      expect(
        IntMatrix.horizontalStack([top.transpose(), bottom.transpose()]),
        IntMatrix.fromInts([
          [1, 3],
          [2, 4],
        ]),
      );
    });

    test('checks conversion to native int', () {
      expect(
        IntMatrix.fromInts([
          [1, -2],
        ]).toIntsChecked(),
        [
          [1, -2],
        ],
      );
      final tooLarge = IntMatrix.fromRows([
        [BigInt.one << 80],
      ]);
      expect(tooLarge.toIntsChecked, throwsRangeError);
    });

    test('does not expose mutable storage', () {
      final source = <List<BigInt>>[
        [BigInt.one],
      ];
      final matrix = IntMatrix(source);
      source[0][0] = BigInt.two;
      expect(matrix[0][0], BigInt.one);
      expect(() => matrix.values[0][0] = BigInt.two, throwsUnsupportedError);
    });
  });
}
