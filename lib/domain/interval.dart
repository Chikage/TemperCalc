import 'dart:math' as math;

import '../core/int_matrix.dart';
import '../core/rational.dart';
import 'models.dart';

class SubgroupDefinition {
  const SubgroupDefinition({required this.basis, required this.expanded});

  final IntMatrix basis;
  final List<int> expanded;

  List<Rational> get subgroup => subgroupFromBasis(basis, expanded);
}

List<int> primeLimit(int limit) {
  if (limit <= 1 || limit >= 7920) {
    throw const TemperamentException('Prime limit must be between 2 and 7919');
  }
  return allSupportedPrimes
      .where((prime) => prime <= limit)
      .toList(growable: false);
}

final List<int> allSupportedPrimes = List<int>.unmodifiable(_primesTo(7919));

List<int> _primesTo(int limit) {
  final composite = List<bool>.filled(limit + 1, false);
  final result = <int>[];
  for (var value = 2; value <= limit; value++) {
    if (composite[value]) continue;
    result.add(value);
    if (value * value <= limit) {
      for (var multiple = value * value; multiple <= limit; multiple += value) {
        composite[multiple] = true;
      }
    }
  }
  return result;
}

Rational ratioFromVector(List<BigInt> vector, List<Rational> subgroup) {
  if (vector.length != subgroup.length) {
    throw ArgumentError('Vector and subgroup dimensions differ');
  }
  var result = Rational.one;
  for (var index = 0; index < vector.length; index++) {
    final exponent = vector[index];
    if (exponent == BigInt.zero) continue;
    if (exponent.abs().bitLength > 31) {
      throw const TemperamentException('Interval exponent is too large');
    }
    result *= subgroup[index].pow(exponent.toInt());
  }
  return result;
}

IntMatrix factorInterval(Rational interval, List<int> subgroup) {
  if (interval.numerator <= BigInt.zero ||
      interval.denominator <= BigInt.zero) {
    throw const TemperamentException('Intervals must be positive');
  }
  var numerator = interval.numerator;
  var denominator = interval.denominator;
  final vector = List<BigInt>.filled(subgroup.length, BigInt.zero);
  for (var index = 0; index < subgroup.length; index++) {
    final factor = BigInt.from(subgroup[index]);
    while (numerator.remainder(factor) == BigInt.zero) {
      numerator ~/= factor;
      vector[index] += BigInt.one;
    }
    while (denominator.remainder(factor) == BigInt.zero) {
      denominator ~/= factor;
      vector[index] -= BigInt.one;
    }
  }
  if (numerator != BigInt.one || denominator != BigInt.one) {
    throw TemperamentException('Decomposition of $interval is not in subgroup');
  }
  return IntMatrix.fromRows(vector.map((value) => [value]), columnCount: 1);
}

List<int> primeFactors(Rational interval) {
  var numerator = interval.numerator.abs();
  var denominator = interval.denominator.abs();
  final result = <int>{};
  for (final prime in allSupportedPrimes) {
    final divisor = BigInt.from(prime);
    while (numerator.remainder(divisor) == BigInt.zero) {
      numerator ~/= divisor;
      result.add(prime);
    }
    while (denominator.remainder(divisor) == BigInt.zero) {
      denominator ~/= divisor;
      result.add(prime);
    }
    if (numerator == BigInt.one && denominator == BigInt.one) break;
  }
  if (numerator != BigInt.one || denominator != BigInt.one) {
    throw const TemperamentException('Prime decomposition failed');
  }
  final sorted = result.toList()..sort();
  return sorted;
}

SubgroupDefinition subgroupBasis(List<Rational> subgroup) {
  final expandedSet = <int>{};
  for (final interval in subgroup) {
    expandedSet.addAll(primeFactors(interval));
  }
  final expanded = expandedSet.toList()..sort();
  final columns = [
    for (final value in subgroup) factorInterval(value, expanded),
  ];
  return SubgroupDefinition(
    basis: IntMatrix.horizontalStack(columns, rowCount: expanded.length),
    expanded: List.unmodifiable(expanded),
  );
}

List<Rational> subgroupFromBasis(IntMatrix basis, List<int> expanded) {
  if (basis.rowCount != expanded.length) {
    throw ArgumentError('Basis row count must match expanded subgroup');
  }
  final primeBasis = expanded.map(Rational.fromInt).toList(growable: false);
  return List<Rational>.unmodifiable(
    List.generate(
      basis.columnCount,
      (column) => ratioFromVector(basis.column(column), primeBasis),
    ),
  );
}

double log2Rational(Rational value) {
  if (value.numerator <= BigInt.zero || value.denominator <= BigInt.zero) {
    throw const TemperamentException('Logarithms require positive intervals');
  }
  final converted = value.toDouble();
  if (converted.isFinite && converted > 0.0) {
    return math.log(converted) / math.ln2;
  }
  return _log2BigInt(value.numerator) - _log2BigInt(value.denominator);
}

double _log2BigInt(BigInt value) {
  final shift = math.max(0, value.bitLength - 53);
  final leading = (value >> shift).toDouble();
  return math.log(leading) / math.ln2 + shift;
}

List<double> logSubgroup(List<Rational> subgroup) =>
    subgroup.map(log2Rational).toList(growable: false);

double logInterval(List<BigInt> vector, List<Rational> subgroup) {
  if (vector.length != subgroup.length) {
    throw ArgumentError('Vector and subgroup dimensions differ');
  }
  final logs = logSubgroup(subgroup);
  var result = 0.0;
  for (var index = 0; index < vector.length; index++) {
    result += vector[index].toDouble() * logs[index];
  }
  return result;
}

List<BigInt> makePositive(List<BigInt> vector, List<Rational> subgroup) {
  if (logInterval(vector, subgroup) < 0) {
    return vector.map((value) => -value).toList(growable: false);
  }
  return List<BigInt>.unmodifiable(vector);
}
