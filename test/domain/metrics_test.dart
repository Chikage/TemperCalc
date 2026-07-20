import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/core/double_matrix.dart';
import 'package:temper_calc/core/int_matrix.dart';
import 'package:temper_calc/core/rational.dart';
import 'package:temper_calc/domain/metrics.dart';

void main() {
  test('badness remains finite and invariant under row orientation', () {
    final subgroup = [
      Rational.fromInt(2),
      Rational.fromInt(3),
      Rational.fromInt(5),
    ];
    final badness = temperamentBadness(
      IntMatrix.fromInts([
        [1000000, 0, 1],
        [1000001, 1, 1],
      ]),
      subgroup,
    );
    final flipped = temperamentBadness(
      IntMatrix.fromInts([
        [1000000, 0, 1],
        [-1000001, -1, -1],
      ]),
      subgroup,
    );
    expect(badness, isNotNull);
    expect(badness!.isFinite, isTrue);
    expect(badness, greaterThan(1e18));
    expect(flipped, isNotNull);
    expect(flipped!, closeTo(badness, badness * 1e-12));
  });

  test('height rejects a volume that overflows double precision', () {
    final matrix = DoubleMatrix.diagonal([1e200, 1e200]);
    expect(height(matrix, DoubleMatrix.identity(2)), isNull);
  });
}
