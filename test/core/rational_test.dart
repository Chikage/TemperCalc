import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/core/rational.dart';

void main() {
  group('Rational', () {
    test('normalizes signs and common factors', () {
      expect(Rational.fromInt(6, -8), Rational.fromInt(-3, 4));
      expect(Rational.parse('-6/-8'), Rational.fromInt(3, 4));
      expect(Rational.fromInt(0, -7), Rational.zero);
    });

    test('parses slash, colon, and integer forms', () {
      expect(Rational.parse(' 81/80 '), Rational.fromInt(81, 80));
      expect(Rational.parse('7:4'), Rational.fromInt(7, 4));
      expect(Rational.parse('-12'), Rational.fromInt(-12));
      expect(() => Rational.parse('1.5'), throwsFormatException);
      expect(() => Rational.parse('1/0'), throwsArgumentError);
    });

    test('performs exact arithmetic with large integers', () {
      final huge = BigInt.parse('582076609134674072265625');
      final value = Rational(huge, BigInt.from(3));
      expect(
        value * Rational(BigInt.from(3), BigInt.from(7)),
        Rational(huge, BigInt.from(7)),
      );
      expect(
        Rational.fromInt(3, 4) + Rational.fromInt(5, 6),
        Rational.fromInt(19, 12),
      );
      expect(Rational.fromInt(2, 3).pow(-2), Rational.fromInt(9, 4));
    });

    test('converts ratios whose components exceed double range', () {
      final numerator = (BigInt.one << 2000) + (BigInt.one << 1948);
      final denominator = BigInt.one << 1900;
      final expected = 1.0000000000000002 * 1.2676506002282294e30;
      expect(
        Rational(numerator, denominator).toDouble(),
        closeTo(expected, 1e15),
      );
    });

    test('uses ties-to-even rounding', () {
      expect(Rational.fromInt(1, 2).roundTiesToEven(), BigInt.zero);
      expect(Rational.fromInt(3, 2).roundTiesToEven(), BigInt.two);
      expect(Rational.fromInt(-1, 2).roundTiesToEven(), BigInt.zero);
      expect(Rational.fromInt(-3, 2).roundTiesToEven(), -BigInt.two);
      expect(Rational.fromInt(-7, 3).floor(), BigInt.from(-3));
    });

    test('compares canonical values', () {
      expect(Rational.fromInt(2, 3) < Rational.fromInt(3, 4), isTrue);
      expect(Rational.fromInt(6, 8), Rational.fromInt(3, 4));
      expect(() => Rational.zero.reciprocal(), throwsStateError);
      expect(() => Rational.fromInt(1, 2).toBigIntExact(), throwsStateError);
    });
  });
}
