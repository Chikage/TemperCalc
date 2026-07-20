import 'dart:math' as math;

import '../core/double_matrix.dart';
import '../core/int_matrix.dart';
import '../core/rational.dart';
import 'interval.dart';
import 'models.dart';

class TuningSolution {
  const TuningSolution({required this.generators, required this.errors});

  final List<double> generators;
  final List<double> errors;
}

DoubleMatrix tuningMetric(List<Rational> subgroup, TuningWeight weight) =>
    switch (weight) {
      TuningWeight.unweighted => DoubleMatrix.identity(subgroup.length),
      TuningWeight.tenney => metricTenney(subgroup),
      TuningWeight.weil => metricWeil(subgroup),
    };

DoubleMatrix metricTenney(List<Rational> subgroup) {
  final logs = logSubgroup(subgroup);
  return DoubleMatrix.diagonal(logs.map((value) => 1.0 / (value * value)));
}

DoubleMatrix metricWilson(List<Rational> subgroup) => DoubleMatrix.diagonal(
  subgroup.map((value) {
    final number = value.toDouble();
    return 1.0 / (number * number);
  }),
);

DoubleMatrix metricWeil(List<Rational> subgroup) => metricWeilK(subgroup, 1.0);

DoubleMatrix metricWeilK(List<Rational> subgroup, double k) {
  final logs = logSubgroup(subgroup);
  final kSquared = k * k;
  final dual = DoubleMatrix.fromRows(
    List.generate(
      logs.length,
      (row) => List.generate(logs.length, (column) {
        final diagonal = row == column ? logs[row] * logs[row] : 0.0;
        return diagonal + kSquared * logs[row] * logs[column];
      }),
    ),
    columnCount: logs.length,
  );
  final metric = dual.inverse();
  return metric.scaled(1.0 / metric[0][0]);
}

TuningSolution leastSquaresTuning(
  IntMatrix mapping,
  List<Rational> subgroup, {
  TuningWeight weight = TuningWeight.tenney,
  DoubleMatrix? targets,
}) {
  final m = DoubleMatrix.fromIntMatrix(mapping);
  final j = logSubgroup(subgroup);
  final jColumn = _column(j);
  final metric = targets == null
      ? tuningMetric(subgroup, weight)
      : targets.multiply(targets.transpose());
  final normal = m.multiply(metric).multiply(m.transpose());
  final right = m.multiply(metric).multiply(jColumn);
  final generators = normal.solve(right).column(0);
  final tuned = m.transpose().multiplyVector(generators);
  final errors = List<double>.generate(
    j.length,
    (index) => tuned[index] - j[index],
  );
  return TuningSolution(
    generators: List.unmodifiable(generators),
    errors: List.unmodifiable(errors),
  );
}

TuningSolution constrainedTuning(
  IntMatrix mapping,
  List<Rational> subgroup, {
  TuningWeight weight = TuningWeight.tenney,
  DoubleMatrix? constraints,
}) {
  final m = DoubleMatrix.fromIntMatrix(mapping);
  final rank = mapping.rowCount;
  final dimension = mapping.columnCount;
  final j = logSubgroup(subgroup);
  final jColumn = _column(j);
  final metric = tuningMetric(subgroup, weight);
  final v =
      constraints ??
      DoubleMatrix.fromRows(
        List.generate(dimension, (row) => [row == 0 ? 1.0 : 0.0]),
        columnCount: 1,
      );
  if (v.rowCount != dimension || v.columnCount == 0) {
    throw ArgumentError('Constraint vectors must be dimension x count');
  }

  final c = m.multiply(v).transpose();
  final normal = m.multiply(metric).multiply(m.transpose());
  final system = DoubleMatrix.fromRows(
    List.generate(rank + c.rowCount, (row) {
      if (row < rank) {
        return <double>[...normal[row], ...c.column(row)];
      }
      return <double>[
        ...c[row - rank],
        ...List<double>.filled(c.rowCount, 0.0),
      ];
    }),
    columnCount: rank + c.rowCount,
  );
  final topRight = m.multiply(metric).multiply(jColumn).column(0);
  final bottomRight = v.transpose().multiply(jColumn).column(0);
  final solution = system.solveVector([...topRight, ...bottomRight]);
  final generators = solution.sublist(0, rank);
  final tuned = m.transpose().multiplyVector(generators);
  final errors = List<double>.generate(
    j.length,
    (index) => tuned[index] - j[index],
  );
  return TuningSolution(
    generators: List.unmodifiable(generators),
    errors: List.unmodifiable(errors),
  );
}

double? height(DoubleMatrix matrix, DoubleMatrix weight) {
  if (weight.rowCount != matrix.columnCount ||
      weight.columnCount != matrix.columnCount) {
    throw ArgumentError('Weight matrix dimension does not match the vectors');
  }
  if (matrix.rowCount > matrix.columnCount) return null;
  if (matrix.rowCount == 0) return 1.0;

  final lower = _cholesky(weight);
  if (lower == null) return null;
  final transformed = matrix.multiply(lower);
  final work = transformed.transpose().toMutableRows();
  var logVolume = 0.0;

  for (var column = 0; column < matrix.rowCount; column++) {
    final norm = _stableNorm(
      List<double>.generate(
        work.length - column,
        (offset) => work[column + offset][column],
      ),
    );
    if (!norm.isFinite || norm == 0.0) return null;
    logVolume += math.log(norm);

    final alpha = work[column][column] >= 0.0 ? -norm : norm;
    final reflector = List<double>.generate(
      work.length - column,
      (offset) => work[column + offset][column],
    );
    reflector[0] -= alpha;
    final reflectorNorm = _stableNorm(reflector);
    if (reflectorNorm == 0.0 || !reflectorNorm.isFinite) return null;
    for (var index = 0; index < reflector.length; index++) {
      reflector[index] /= reflectorNorm;
    }
    for (var target = column; target < matrix.rowCount; target++) {
      var projection = 0.0;
      for (var index = 0; index < reflector.length; index++) {
        projection += reflector[index] * work[column + index][target];
      }
      for (var index = 0; index < reflector.length; index++) {
        work[column + index][target] -= 2.0 * projection * reflector[index];
      }
    }
  }

  if (logVolume <= math.log(1e-4)) return null;
  final volume = math.exp(logVolume);
  return volume.isFinite ? volume : null;
}

DoubleMatrix? _cholesky(DoubleMatrix matrix) {
  if (!matrix.isSquare) return null;
  final size = matrix.rowCount;
  final lower = List.generate(size, (_) => List<double>.filled(size, 0.0));
  for (var row = 0; row < size; row++) {
    for (var column = 0; column <= row; column++) {
      var value = (matrix[row][column] + matrix[column][row]) / 2.0;
      for (var index = 0; index < column; index++) {
        value -= lower[row][index] * lower[column][index];
      }
      if (row == column) {
        if (!value.isFinite || value <= 0.0) return null;
        lower[row][column] = math.sqrt(value);
      } else {
        lower[row][column] = value / lower[column][column];
      }
    }
  }
  return DoubleMatrix.fromRows(lower, columnCount: size);
}

double _stableNorm(List<double> values) {
  var scale = 0.0;
  var sumSquares = 1.0;
  for (final value in values) {
    final magnitude = value.abs();
    if (magnitude == 0.0) continue;
    if (scale < magnitude) {
      final ratio = scale / magnitude;
      sumSquares = 1.0 + sumSquares * ratio * ratio;
      scale = magnitude;
    } else {
      final ratio = magnitude / scale;
      sumSquares += ratio * ratio;
    }
  }
  return scale == 0.0 ? 0.0 : scale * math.sqrt(sumSquares);
}

double? temperamentBadness(
  IntMatrix mapping,
  List<Rational> subgroup, {
  DoubleMatrix? weight,
}) {
  final rank = mapping.rowCount;
  final dimension = mapping.columnCount;
  if (dimension <= rank || dimension == 0) return null;
  final logs = logSubgroup(subgroup);
  var metric =
      weight ??
      DoubleMatrix.diagonal(logs.map((value) => 1.0 / (value * value)));
  final determinant = metric.determinant();
  if (!determinant.isFinite || determinant <= 0) return null;
  metric = metric.scaled(1.0 / math.pow(determinant, 1.0 / dimension));

  final m = DoubleMatrix.fromIntMatrix(mapping);
  final j = DoubleMatrix.fromRows([logs]);
  final withJust = DoubleMatrix.verticalStack([m, j]);
  final errorHeight = height(withJust, metric);
  final mapHeight = height(m, metric);
  final justHeight = height(j, metric);
  if (errorHeight == null || mapHeight == null || justHeight == null) {
    return null;
  }
  final exponent = rank / (dimension - rank);
  return errorHeight * math.pow(mapHeight, exponent) / justHeight;
}

DoubleMatrix projectedSubgroupMetric(
  IntMatrix basis,
  DoubleMatrix expandedMetric,
) {
  final basisDouble = DoubleMatrix.fromIntMatrix(basis);
  return basisDouble
      .transpose()
      .multiply(expandedMetric.inverse())
      .multiply(basisDouble);
}

DoubleMatrix normalizeDeterminant(DoubleMatrix matrix) {
  final determinant = matrix.determinant();
  if (!determinant.isFinite || determinant <= 0) {
    throw const TemperamentException('Metric is not positive definite');
  }
  return matrix.scaled(1.0 / math.pow(determinant, 1.0 / matrix.rowCount));
}

String cents(double octaves, {int precision = 3}) =>
    (1200.0 * octaves).toStringAsFixed(precision);

DoubleMatrix _column(List<double> values) =>
    DoubleMatrix.fromRows(values.map((value) => [value]), columnCount: 1);
