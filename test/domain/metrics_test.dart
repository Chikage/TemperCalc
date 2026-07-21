import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/core/double_matrix.dart';
import 'package:temper_calc/core/int_matrix.dart';
import 'package:temper_calc/core/rational.dart';
import 'package:temper_calc/domain/metrics.dart';
import 'package:temper_calc/domain/models.dart';

void main() {
  test('WE tuning keeps nine-decimal precision for a high EDO mapping', () {
    final mapping = IntMatrix.fromInts([
      [1, 397, -415],
      [0, -4350, 4591],
    ]);
    final subgroup = [
      Rational.fromInt(2),
      Rational.fromInt(3),
      Rational.fromInt(5),
    ];
    final solution = leastSquaresTuning(
      mapping,
      subgroup,
      weight: TuningWeight.weil,
    );
    final constrained = constrainedTuning(
      mapping,
      subgroup,
      weight: TuningWeight.weil,
    );

    expect(cents(solution.generators[0], precision: 9), '1199.997720626');
    expect(cents(solution.generators[1], precision: 9), '109.079801971');
    expect(cents(constrained.generators[0], precision: 9), '1200.000000000');
    expect(cents(constrained.generators[1], precision: 9), '109.080009205');
  });

  test('codimension-one badness avoids cancellation at high EDOs', () {
    final badness = temperamentBadness(
      IntMatrix.fromInts([
        [1, 397, -415],
        [0, -4350, 4591],
      ]),
      [Rational.fromInt(2), Rational.fromInt(3), Rational.fromInt(5)],
    );

    expect(badness, isNotNull);
    expect(badness!, closeTo(3580323.193512816, 1e-3));
  });

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
