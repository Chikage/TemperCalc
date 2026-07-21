import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/core/int_matrix.dart';
import 'package:temper_calc/core/rational.dart';
import 'package:temper_calc/domain/input_parser.dart';

void main() {
  test('parses prime limits and rational subgroups', () {
    final primeLimit = parseSubgroup('7');
    expect(primeLimit.expanded, [2, 3, 5, 7]);
    expect(primeLimit.basis, IntMatrix.identity(4));

    final commaSeparated = parseSubgroup('2,3,5,7');
    expect(commaSeparated.expanded, [2, 3, 5, 7]);
    expect(commaSeparated.basis, IntMatrix.identity(4));

    final rational = parseSubgroup('2.5/3.7/3.11/3');
    expect(rational.expanded, [2, 3, 5, 7, 11]);
    expect(
      rational.basis,
      IntMatrix.fromInts([
        [1, 0, 0, 0],
        [0, -1, -1, -1],
        [0, 1, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1],
      ]),
    );
    expect(rational.subgroup.map((value) => '$value'), [
      '2',
      '5/3',
      '7/3',
      '11/3',
    ]);
    expect(() => parseSubgroup('-5'), throwsA(isA<Exception>()));
  });

  test('parses EDO adjustments and wart notation', () {
    final subgroup = parseSubgroup('7').subgroup;
    expect(parseEdos('12,17[+5,-7],22', subgroup), [
      IntMatrix.fromInts([
        [12, 19, 28, 34],
      ]),
      IntMatrix.fromInts([
        [17, 27, 40, 47],
      ]),
      IntMatrix.fromInts([
        [22, 35, 51, 62],
      ]),
    ]);
    expect(parseEdos('17c,17cc,17ccc', subgroup), [
      IntMatrix.fromInts([
        [17, 27, 40, 48],
      ]),
      IntMatrix.fromInts([
        [17, 27, 38, 48],
      ]),
      IntMatrix.fromInts([
        [17, 27, 41, 48],
      ]),
    ]);

    final rationalSubgroup = parseSubgroup('2.5/3.7/3.11/3').subgroup;
    expect(parseEdos('17p', rationalSubgroup), [
      IntMatrix.fromInts([
        [17, 13, 21, 32],
      ]),
    ]);
  });

  test(
    'parses ratios, square superparticulars, and vectors by syntax class',
    () {
      final subgroup = parseSubgroup('7');
      final intervals = parseIntervals(
        '[1 0 0],81/80,S5,(4,5,6,7,8)',
        subgroup.basis,
        subgroup.expanded,
      );
      expect(intervals, [
        IntMatrix.fromInts([
          [-4],
          [4],
          [-1],
          [0],
        ]),
        IntMatrix.fromInts([
          [-3],
          [-1],
          [2],
          [0],
        ]),
        IntMatrix.fromInts([
          [1],
          [0],
          [0],
          [0],
        ]),
        IntMatrix.fromInts([
          [4],
          [5],
          [6],
          [7],
        ]),
      ]);
    },
  );

  test('preserves floating distinctions around ties and tiny equaves', () {
    final nearHalfSubgroup = [
      Rational.fromInt(4),
      Rational(BigInt.from(8796093022208), BigInt.from(4398046511103)),
    ];
    expect(edoMapNotation([BigInt.one, BigInt.one], nearHalfSubgroup), '1');

    final tinyEquaveSubgroup = [
      Rational(BigInt.from(8000000000000001), BigInt.from(8000000000000000)),
      Rational.fromInt(2),
    ];
    expect(
      patentMap(1, tinyEquaveSubgroup),
      IntMatrix.fromInts([
        [1, 3121657384082680],
      ]),
    );
  });
}
