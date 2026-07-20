import 'dart:math' as math;

import '../core/int_matrix.dart';
import '../core/rational.dart';
import 'interval.dart';
import 'models.dart';

const _wartPrime = <String, int>{
  'a': 2,
  'b': 3,
  'c': 5,
  'd': 7,
  'e': 11,
  'f': 13,
  'g': 17,
  'h': 19,
  'i': 23,
  'j': 29,
  'k': 31,
  'l': 37,
  'm': 41,
  'n': 43,
  'o': 47,
};

SubgroupDefinition parseSubgroup(String source) {
  final parts = source
      .trim()
      .split(RegExp(r'[.,;\s]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    throw const TemperamentException('Enter a prime limit or subgroup');
  }

  final subgroup = <Rational>[];
  for (final part in parts) {
    Rational value;
    try {
      value = Rational.parse(part);
    } on FormatException {
      throw TemperamentException('Invalid subgroup value: $part');
    }
    if (value.numerator <= BigInt.zero) {
      throw const TemperamentException('Subgroup values must be positive');
    }
    if (value < Rational.one) value = value.reciprocal();
    subgroup.add(value);
  }

  if (subgroup.length == 1) {
    final limit = subgroup.single;
    if (!limit.isInteger) {
      throw const TemperamentException('Prime limit must be an integer');
    }
    if (limit.numerator.bitLength > 31) {
      throw const TemperamentException('Prime limit is too large');
    }
    final expanded = primeLimit(limit.numerator.toInt());
    return SubgroupDefinition(
      basis: IntMatrix.identity(expanded.length),
      expanded: List.unmodifiable(expanded),
    );
  }
  return subgroupBasis(subgroup);
}

List<IntMatrix> parseEdos(String source, List<Rational> subgroup) {
  if (subgroup.isEmpty) {
    throw const TemperamentException('Subgroup must not be empty');
  }
  final result = <IntMatrix>[];
  for (final rawToken in _splitOutsideBrackets(source.toLowerCase().trim())) {
    final token = rawToken.trim();
    if (token.isEmpty) continue;
    final numberMatch = RegExp(r'\d+').firstMatch(token);
    if (numberMatch == null) continue;
    final edo = int.tryParse(numberMatch.group(0)!);
    if (edo == null) {
      throw TemperamentException('Invalid EDO: $token');
    }
    var map = patentMap(edo.toDouble(), subgroup);
    final suffix = token.substring(numberMatch.end);
    if (suffix.isEmpty) {
      result.add(map);
      continue;
    }

    final bracket = RegExp(r'\[.*\]').firstMatch(token);
    if (bracket != null) {
      final contents = bracket
          .group(0)!
          .substring(1, bracket.group(0)!.length - 1);
      for (final adjustment in contents.split(RegExp(r'[.,;&\s]+'))) {
        if (adjustment.isEmpty) continue;
        final match = RegExp(r'^([+-]+)(.+)$').firstMatch(adjustment);
        if (match == null) {
          throw TemperamentException('Invalid EDO adjustment: $adjustment');
        }
        final signs = match.group(1)!;
        Rational target;
        try {
          target = Rational.parse(match.group(2)!);
        } on FormatException {
          throw TemperamentException('Invalid EDO adjustment: $adjustment');
        }
        final index = subgroup.indexOf(target);
        if (index < 0) {
          throw TemperamentException('Adjustment $target is not in subgroup');
        }
        final rows = map.toMutableRows();
        for (final sign in signs.split('')) {
          rows[0][index] += sign == '+' ? BigInt.one : -BigInt.one;
        }
        map = IntMatrix.fromRows(rows, columnCount: subgroup.length);
      }
      result.add(map);
      continue;
    }

    final rows = map.toMutableRows();
    var index = 0;
    while (index < suffix.length) {
      final character = suffix[index];
      var end = index + 1;
      while (end < suffix.length && suffix[end] == character) {
        end++;
      }
      final count = end - index;
      if (character != 'p') {
        if (subgroup.any((value) => !value.isInteger)) {
          throw const TemperamentException(
            'Wart notation cannot be used in rational subgroups',
          );
        }
        final prime = _wartPrime[character];
        if (prime == null) {
          throw TemperamentException('Unknown wart: $character');
        }
        final subgroupIndex = subgroup.indexWhere(
          (value) => value.numerator == BigInt.from(prime),
        );
        if (subgroupIndex < 0) {
          throw TemperamentException('Wart prime $prime is not in subgroup');
        }
        final normalizedLogs = logSubgroup(subgroup);
        final floatPrime =
            edo * normalizedLogs[subgroupIndex] / normalizedLogs[0];
        var sign = floatPrime - (floatPrime + 0.5).floorToDouble() <= 0
            ? -1
            : 1;
        if (count.isEven) sign *= -1;
        rows[0][subgroupIndex] += BigInt.from(sign * ((count + 1) ~/ 2));
      }
      index = end;
    }
    result.add(IntMatrix.fromRows(rows, columnCount: subgroup.length));
  }
  if (result.isEmpty) {
    throw const TemperamentException('Enter at least one EDO');
  }
  return result;
}

List<String> _splitOutsideBrackets(String source) {
  final result = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  for (final rune in source.runes) {
    final character = String.fromCharCode(rune);
    if (character == '[') depth++;
    if (character == ']') depth = math.max(0, depth - 1);
    final separator = depth == 0 && RegExp(r'[.,;&\s]').hasMatch(character);
    if (separator) {
      if (buffer.isNotEmpty) {
        result.add(buffer.toString());
        buffer.clear();
      }
    } else {
      buffer.write(character);
    }
  }
  if (buffer.isNotEmpty) result.add(buffer.toString());
  return result;
}

List<IntMatrix> parseIntervals(
  String source,
  IntMatrix basis,
  List<int> expanded,
) {
  final result = <IntMatrix>[];
  for (final match in RegExp(r'(\d+)[/:](\d+)').allMatches(source)) {
    final numerator = BigInt.parse(match.group(1)!);
    final denominator = BigInt.parse(match.group(2)!);
    result.add(factorInterval(Rational(numerator, denominator), expanded));
  }
  for (final match in RegExp(r'[Ss](\d+)').allMatches(source)) {
    final k = BigInt.parse(match.group(1)!);
    final numerator = k * k;
    final denominator = numerator - BigInt.one;
    if (denominator == BigInt.zero) {
      throw const TemperamentException('S1 is not a valid interval');
    }
    result.add(factorInterval(Rational(numerator, denominator), expanded));
  }
  final vectorPattern = RegExp(r'[\[(<]\s*(-?\d+(?:[,\s]+-?\d+)*)\s*[\])>]');
  for (final match in vectorPattern.allMatches(source)) {
    final entries = match
        .group(1)!
        .replaceAll(',', ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .map(BigInt.parse)
        .toList(growable: false);
    final vector = List<BigInt>.filled(basis.columnCount, BigInt.zero);
    for (
      var index = 0;
      index < math.min(entries.length, vector.length);
      index++
    ) {
      vector[index] = entries[index];
    }
    result.add(
      basis.multiply(
        IntMatrix.fromRows(vector.map((value) => [value]), columnCount: 1),
      ),
    );
  }
  return result;
}

IntMatrix patentMap(double edo, List<Rational> subgroup) {
  if (edo.isNaN || edo.isInfinite) {
    throw const TemperamentException('EDO must be finite');
  }
  final logs = logSubgroup(subgroup);
  if (subgroup.isEmpty || subgroup.first == Rational.one) {
    throw const TemperamentException('The equave must not be 1/1');
  }
  return IntMatrix.fromRows([
    [
      for (final value in logs)
        BigInt.from((edo * value / logs.first + 0.5).floor()),
    ],
  ]);
}

String edoMapNotation(List<BigInt> map, List<Rational> subgroup) {
  if (map.length != subgroup.length || map.isEmpty) {
    throw ArgumentError('Map and subgroup dimensions differ');
  }
  final division = map.first;
  final logs = logSubgroup(subgroup);
  final normalized = logs.map((value) => value / logs.first).toList();
  final adjustments = <String>[];
  for (var index = 0; index < map.length; index++) {
    final patent = BigInt.from(
      roundTiesToEven(division.toDouble() * normalized[index]),
    );
    final difference = map[index] - patent;
    if (difference == BigInt.zero) continue;
    if (difference.abs().bitLength > 20) {
      throw const TemperamentException('EDO adjustment is too large');
    }
    final count = difference.abs().toInt();
    final sign = difference.isNegative ? '-' : '+';
    adjustments.add('${List.filled(count, sign).join()}${subgroup[index]}');
  }
  if (adjustments.isEmpty) return '$division';
  return '$division[${adjustments.join(', ')}]';
}

int roundTiesToEven(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'Must be finite');
  }
  final lower = value.floor();
  final fraction = value - lower;
  if (fraction < 0.5) return lower;
  if (fraction > 0.5) return lower + 1;
  return lower.isEven ? lower : lower + 1;
}
