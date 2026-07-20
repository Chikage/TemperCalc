import 'dart:math' as math;

/// An exact rational number backed by arbitrary-precision integers.
final class Rational implements Comparable<Rational> {
  factory Rational(BigInt numerator, [BigInt? denominator]) {
    var n = numerator;
    var d = denominator ?? BigInt.one;

    if (d == BigInt.zero) {
      throw ArgumentError.value(denominator, 'denominator', 'Must not be zero');
    }
    if (d < BigInt.zero) {
      n = -n;
      d = -d;
    }

    final divisor = n.abs().gcd(d);
    return Rational._(n ~/ divisor, d ~/ divisor);
  }

  factory Rational.fromInt(int numerator, [int denominator = 1]) =>
      Rational(BigInt.from(numerator), BigInt.from(denominator));

  factory Rational.parse(String source) {
    final match = RegExp(
      r'^\s*([+-]?\d+)\s*(?:[/:]\s*([+-]?\d+))?\s*$',
    ).firstMatch(source);
    if (match == null) {
      throw FormatException('Invalid rational number', source);
    }

    final numerator = BigInt.parse(match.group(1)!);
    final denominator = match.group(2) == null
        ? BigInt.one
        : BigInt.parse(match.group(2)!);
    return Rational(numerator, denominator);
  }

  const Rational._(this.numerator, this.denominator);

  static final zero = Rational._(BigInt.zero, BigInt.one);
  static final one = Rational._(BigInt.one, BigInt.one);

  final BigInt numerator;
  final BigInt denominator;

  bool get isZero => numerator == BigInt.zero;
  bool get isInteger => denominator == BigInt.one;
  bool get isNegative => numerator < BigInt.zero;
  int get sign => numerator.sign;

  Rational get abs => isNegative ? -this : this;

  Rational reciprocal() {
    if (isZero) {
      throw StateError('Zero has no reciprocal');
    }
    return Rational(denominator, numerator);
  }

  Rational pow(int exponent) {
    if (exponent == 0) {
      return one;
    }
    if (exponent < 0) {
      return reciprocal().pow(-exponent);
    }
    return Rational(numerator.pow(exponent), denominator.pow(exponent));
  }

  BigInt floor() {
    final quotient = numerator ~/ denominator;
    final remainder = numerator.remainder(denominator);
    return remainder != BigInt.zero && numerator < BigInt.zero
        ? quotient - BigInt.one
        : quotient;
  }

  /// Rounds to the nearest integer, resolving exact half ties to an even value.
  BigInt roundTiesToEven() {
    final lower = floor();
    final remainder = numerator - lower * denominator;
    final doubled = remainder * BigInt.two;
    if (doubled < denominator) {
      return lower;
    }
    if (doubled > denominator) {
      return lower + BigInt.one;
    }
    return lower.isEven ? lower : lower + BigInt.one;
  }

  BigInt toBigIntExact() {
    if (!isInteger) {
      throw StateError('$this is not an integer');
    }
    return numerator;
  }

  double toDouble() {
    if (isZero) {
      return 0.0;
    }
    final absoluteNumerator = numerator.abs();
    final numeratorShift = math.max(0, absoluteNumerator.bitLength - 53);
    final denominatorShift = math.max(0, denominator.bitLength - 53);
    final leadingNumerator = (absoluteNumerator >> numeratorShift).toDouble();
    final leadingDenominator = (denominator >> denominatorShift).toDouble();
    final exponent = numeratorShift - denominatorShift;
    final magnitude =
        (leadingNumerator / leadingDenominator) * math.pow(2.0, exponent);
    return isNegative ? -magnitude : magnitude;
  }

  Rational operator -() => Rational._(-numerator, denominator);

  Rational operator +(Rational other) => Rational(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );

  Rational operator -(Rational other) => this + (-other);

  Rational operator *(Rational other) =>
      Rational(numerator * other.numerator, denominator * other.denominator);

  Rational operator /(Rational other) {
    if (other.isZero) {
      throw StateError('Division by zero');
    }
    return Rational(
      numerator * other.denominator,
      denominator * other.numerator,
    );
  }

  @override
  int compareTo(Rational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  bool operator <(Rational other) => compareTo(other) < 0;
  bool operator <=(Rational other) => compareTo(other) <= 0;
  bool operator >(Rational other) => compareTo(other) > 0;
  bool operator >=(Rational other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Rational &&
      numerator == other.numerator &&
      denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => isInteger ? '$numerator' : '$numerator/$denominator';
}
