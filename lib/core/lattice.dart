import 'dart:math' as math;

import 'double_matrix.dart';
import 'int_matrix.dart';
import 'rational.dart';

/// Computes row-style Hermite normal form.
///
/// Pivot columns increase from left to right, pivots are positive, and entries
/// above a pivot are reduced to the half-open range `[0, pivot)`.
IntMatrix hnf(IntMatrix matrix, {bool removeZeroRows = false}) {
  final rows = matrix.toMutableRows();
  final rowCount = matrix.rowCount;
  final columnCount = matrix.columnCount;

  var pivotRow = 0;
  var pivotColumn = 0;
  while (pivotRow < rowCount && pivotColumn < columnCount) {
    final selected = _smallestNonZeroPivot(rows, pivotRow, pivotColumn);
    if (selected == null) {
      pivotColumn++;
      continue;
    }

    if (selected != pivotRow) {
      final temporary = rows[pivotRow];
      rows[pivotRow] = rows[selected];
      rows[selected] = temporary;
    }

    for (var row = pivotRow + 1; row < rowCount; row++) {
      if (rows[row][pivotColumn] == BigInt.zero) {
        continue;
      }
      final quotient = _floorDivide(
        rows[row][pivotColumn],
        rows[pivotRow][pivotColumn],
      );
      for (var column = 0; column < columnCount; column++) {
        rows[row][column] -= quotient * rows[pivotRow][column];
      }
    }

    final columnIsReduced = Iterable<int>.generate(
      rowCount - pivotRow - 1,
      (offset) => pivotRow + offset + 1,
    ).every((row) => rows[row][pivotColumn] == BigInt.zero);
    if (!columnIsReduced) {
      continue;
    }

    if (rows[pivotRow][pivotColumn] < BigInt.zero) {
      for (var column = 0; column < columnCount; column++) {
        rows[pivotRow][column] = -rows[pivotRow][column];
      }
    }

    final pivot = rows[pivotRow][pivotColumn];
    for (var row = 0; row < pivotRow; row++) {
      final quotient = _floorDivide(rows[row][pivotColumn], pivot);
      if (quotient == BigInt.zero) {
        continue;
      }
      for (var column = 0; column < columnCount; column++) {
        rows[row][column] -= quotient * rows[pivotRow][column];
      }
    }

    pivotRow++;
    pivotColumn++;
  }

  final result = IntMatrix.fromRows(rows, columnCount: columnCount);
  return removeZeroRows ? result.withoutZeroRows() : result;
}

/// Returns a column basis for the integer nullspace of [matrix].
IntMatrix kernel(IntMatrix matrix) {
  final independentRows = hnf(matrix, removeZeroRows: true);
  final rank = independentRows.rowCount;
  final dimension = matrix.columnCount;
  if (rank > dimension) {
    throw StateError('Matrix rank cannot exceed its column count');
  }
  if (dimension == 0) {
    return IntMatrix.zero(0, 0);
  }

  final augmented = IntMatrix.verticalStack([
    independentRows,
    IntMatrix.identity(dimension),
  ]);
  final transformed = hnf(augmented.transpose()).transpose();
  final result = transformed.submatrix(
    rank,
    transformed.rowCount,
    rank,
    transformed.columnCount,
  );

  if (!matrix.multiply(result).isZero) {
    throw StateError('Failed to construct an integer kernel');
  }
  return result;
}

/// Returns a row basis for the integer right nullspace of [matrix].
IntMatrix cokernel(IntMatrix matrix) => kernel(matrix.transpose()).transpose();

/// Exact determinant using fraction-free Bareiss elimination.
BigInt integerDeterminant(IntMatrix matrix) {
  if (!matrix.isSquare) {
    throw ArgumentError('Determinant requires a square matrix');
  }
  final size = matrix.rowCount;
  if (size == 0) {
    return BigInt.one;
  }
  if (size == 1) {
    return matrix[0][0];
  }

  final rows = matrix.toMutableRows();
  var sign = BigInt.one;
  var previousPivot = BigInt.one;

  for (var pivotIndex = 0; pivotIndex < size - 1; pivotIndex++) {
    if (rows[pivotIndex][pivotIndex] == BigInt.zero) {
      int? swapWith;
      for (var row = pivotIndex + 1; row < size; row++) {
        if (rows[row][pivotIndex] != BigInt.zero) {
          swapWith = row;
          break;
        }
      }
      if (swapWith == null) {
        return BigInt.zero;
      }
      final temporary = rows[pivotIndex];
      rows[pivotIndex] = rows[swapWith];
      rows[swapWith] = temporary;
      sign = -sign;
    }

    final pivot = rows[pivotIndex][pivotIndex];
    for (var row = pivotIndex + 1; row < size; row++) {
      final eliminatedEntry = rows[row][pivotIndex];
      for (var column = pivotIndex + 1; column < size; column++) {
        final numerator =
            rows[row][column] * pivot -
            eliminatedEntry * rows[pivotIndex][column];
        if (numerator.remainder(previousPivot) != BigInt.zero) {
          throw StateError('Bareiss division was not exact');
        }
        rows[row][column] = numerator ~/ previousPivot;
      }
      rows[row][pivotIndex] = BigInt.zero;
    }
    previousPivot = pivot;
  }

  return sign * rows[size - 1][size - 1];
}

/// Saturates a row lattice and returns it in Hermite normal form.
IntMatrix defactoredHnf(IntMatrix matrix) {
  final reduced = hnf(matrix, removeZeroRows: true);
  final rank = reduced.rowCount;
  if (rank == 0) {
    return reduced;
  }
  if (rank > reduced.columnCount) {
    throw ArgumentError('Cannot saturate a row lattice with rank > dimension');
  }

  final columnHnf = hnf(reduced.transpose());
  final factor = columnHnf.submatrix(0, rank, 0, rank).transpose();
  final order = integerDeterminant(factor).abs();
  if (order == BigInt.zero) {
    throw StateError('Cannot saturate a rank-deficient matrix');
  }
  if (order == BigInt.one) {
    return hnf(reduced);
  }

  final saturated = _solveSquareExactly(factor, reduced);
  return hnf(saturated);
}

/// Index of the row lattice in its saturation.
BigInt factorOrder(IntMatrix matrix) {
  final reduced = hnf(matrix, removeZeroRows: true);
  final rank = reduced.rowCount;
  if (rank == 0) {
    return BigInt.one;
  }
  if (rank > reduced.columnCount) {
    throw ArgumentError('Row rank exceeds matrix dimension');
  }
  final factor = hnf(
    reduced.transpose(),
  ).submatrix(0, rank, 0, rank).transpose();
  return integerDeterminant(factor).abs();
}

IntMatrix antitranspose(IntMatrix matrix) {
  final transposed = matrix.transpose();
  return IntMatrix.fromRows(
    List.generate(
      transposed.rowCount,
      (row) => List.generate(
        transposed.columnCount,
        (column) =>
            transposed[transposed.rowCount - row - 1][transposed.columnCount -
                column -
                1],
      ),
    ),
    columnCount: transposed.columnCount,
  );
}

IntMatrix canonical(IntMatrix matrix) => matrix.rowCount > matrix.columnCount
    ? antitranspose(defactoredHnf(antitranspose(matrix)))
    : defactoredHnf(matrix);

/// Solves `A * X = B` exactly when [a] has full column rank.
IntMatrix solveDiophantine(IntMatrix a, IntMatrix b) {
  if (a.rowCount != b.rowCount) {
    throw ArgumentError('A and B must have the same row count');
  }
  final unknownCount = a.columnCount;
  if (unknownCount == 0) {
    if (!b.isZero) {
      throw StateError('Integer system has no solution');
    }
    return IntMatrix.zero(0, b.columnCount);
  }
  if (a.rowCount < unknownCount) {
    throw ArgumentError('A must have full column rank');
  }

  final augmented = IntMatrix.horizontalStack([a, b]);
  final transformed = hnf(augmented);
  final factor = transformed.submatrix(0, unknownCount, 0, unknownCount);
  final transformedRight = transformed.submatrix(
    0,
    unknownCount,
    unknownCount,
    unknownCount + b.columnCount,
  );
  final solution = _solveSquareExactly(factor, transformedRight);

  if (a.multiply(solution) != b) {
    throw StateError('Integer system has no solution');
  }
  return solution;
}

/// Finds an integer right inverse `X` such that `matrix * X = I`.
IntMatrix preimage(IntMatrix matrix) {
  final rank = matrix.rowCount;
  final dimension = matrix.columnCount;
  if (rank > dimension) {
    throw ArgumentError('A right inverse requires rows <= columns');
  }
  if (rank == 0) {
    return IntMatrix.zero(dimension, 0);
  }

  final augmented = IntMatrix.horizontalStack([
    matrix.transpose(),
    IntMatrix.identity(dimension),
  ]);
  final transformed = hnf(augmented);
  final solution = transformed
      .submatrix(0, rank, rank, rank + dimension)
      .transpose();

  if (matrix.multiply(solution) != IntMatrix.identity(rank)) {
    throw StateError('Matrix has no integer right inverse');
  }
  return solution;
}

/// Weighted LLL reduction on the columns of [basis].
IntMatrix weightedLll(
  IntMatrix basis, {
  DoubleMatrix? weight,
  double delta = 0.75,
  int maxIterations = 800,
}) {
  final metric = weight ?? DoubleMatrix.identity(basis.rowCount);
  final reducedRows = weightedLllRows(
    basis.transpose(),
    weight: metric,
    delta: delta,
    maxIterations: maxIterations,
  );
  final reduced = reducedRows.transpose();

  final norms = List<double>.generate(
    reduced.columnCount,
    (column) => _weightedNormSquared(reduced.column(column), metric),
  );
  final order = List<int>.generate(reduced.columnCount, (index) => index)
    ..sort((left, right) {
      final comparison = norms[left].compareTo(norms[right]);
      return comparison != 0 ? comparison : left.compareTo(right);
    });

  return IntMatrix.fromRows(
    List.generate(
      reduced.rowCount,
      (row) => order.map((column) => reduced[row][column]),
    ),
    columnCount: reduced.columnCount,
  );
}

/// Weighted LLL reduction on row basis vectors.
IntMatrix weightedLllRows(
  IntMatrix basis, {
  required DoubleMatrix weight,
  double delta = 0.75,
  int maxIterations = 800,
}) {
  _validateMetric(weight, basis.columnCount);
  if (delta <= 0.25 || delta > 1.0 || !delta.isFinite) {
    throw ArgumentError.value(delta, 'delta', 'Must satisfy 0.25 < delta <= 1');
  }
  if (maxIterations <= 0) {
    throw ArgumentError.value(
      maxIterations,
      'maxIterations',
      'Must be positive',
    );
  }
  if (basis.rowCount <= 1) {
    return basis;
  }

  final rows = basis.toMutableRows();
  var orthogonal = _gramSchmidt(rows, weight);

  double mu(int row, int previous) {
    final denominator = _inner(
      orthogonal[previous],
      orthogonal[previous],
      weight,
    );
    if (!denominator.isFinite || denominator <= 0.0) {
      throw StateError('LLL basis is linearly dependent or metric is invalid');
    }
    return _inner(orthogonal[previous], _toFiniteDoubles(rows[row]), weight) /
        denominator;
  }

  var iterations = 0;
  var row = 1;
  while (row < rows.length) {
    for (var previous = row - 1; previous >= 0; previous--) {
      final coefficient = mu(row, previous);
      if (coefficient.abs() > 0.5) {
        final rounded = _roundTiesToEven(coefficient);
        for (var column = 0; column < basis.columnCount; column++) {
          rows[row][column] -= rows[previous][column] * rounded;
        }
        orthogonal = _gramSchmidt(rows, weight);
      }
    }

    final previousNorm = _inner(
      orthogonal[row - 1],
      orthogonal[row - 1],
      weight,
    );
    final currentNorm = _inner(orthogonal[row], orthogonal[row], weight);
    final coefficient = mu(row, row - 1);
    final lovaszBound = (delta - coefficient * coefficient) * previousNorm;
    if (currentNorm >= lovaszBound) {
      row++;
    } else {
      final temporary = rows[row - 1];
      rows[row - 1] = rows[row];
      rows[row] = temporary;
      orthogonal = _gramSchmidt(rows, weight);
      row = math.max(row - 1, 1);
    }

    iterations++;
    if (iterations > maxIterations) {
      throw StateError('LLL reduction exceeded $maxIterations iterations');
    }
  }

  return IntMatrix.fromRows(rows, columnCount: basis.columnCount);
}

/// Babai nearest-plane approximation using row basis vectors.
///
/// Returns the lattice point, not the residual from [target].
List<BigInt> nearestPlane(
  List<BigInt> target,
  IntMatrix rowBasis, {
  DoubleMatrix? weight,
}) {
  if (rowBasis.columnCount != target.length) {
    throw ArgumentError(
      'Basis dimension ${rowBasis.columnCount} does not match '
      'target length ${target.length}',
    );
  }
  final metric = weight ?? DoubleMatrix.identity(target.length);
  _validateMetric(metric, target.length);
  if (rowBasis.rowCount == 0) {
    return List<BigInt>.filled(target.length, BigInt.zero, growable: false);
  }

  final rows = rowBasis.toMutableRows();
  final orthogonal = _gramSchmidt(rows, metric);
  final residual = List<BigInt>.of(target);

  for (var row = rows.length - 1; row >= 0; row--) {
    final denominator = _inner(orthogonal[row], orthogonal[row], metric);
    if (!denominator.isFinite || denominator <= 0.0) {
      throw StateError('Basis is linearly dependent or metric is invalid');
    }
    final coefficient =
        _inner(orthogonal[row], _toFiniteDoubles(residual), metric) /
        denominator;
    final rounded = _roundTiesToEven(coefficient);
    for (var column = 0; column < target.length; column++) {
      residual[column] -= rounded * rows[row][column];
    }
  }

  return List<BigInt>.unmodifiable(
    List.generate(target.length, (index) => target[index] - residual[index]),
  );
}

/// Simplifies interval columns modulo a reduced comma column basis.
IntMatrix simplifyIntervals(
  IntMatrix intervals,
  IntMatrix commaBasis, {
  DoubleMatrix? weight,
}) {
  if (intervals.rowCount != commaBasis.rowCount) {
    throw ArgumentError('Intervals and commas must have the same dimension');
  }
  final rows = intervals.toMutableRows();
  final commaRows = commaBasis.transpose();
  for (var column = 0; column < intervals.columnCount; column++) {
    final target = intervals.column(column);
    final nearest = nearestPlane(target, commaRows, weight: weight);
    for (var row = 0; row < intervals.rowCount; row++) {
      rows[row][column] -= nearest[row];
    }
  }
  return IntMatrix.fromRows(rows, columnCount: intervals.columnCount);
}

IntMatrix _solveSquareExactly(IntMatrix left, IntMatrix right) {
  if (!left.isSquare || left.rowCount != right.rowCount) {
    throw ArgumentError('Exact solve requires square A and matching B rows');
  }
  final size = left.rowCount;
  if (size == 0) {
    return IntMatrix.zero(0, right.columnCount);
  }
  final totalColumns = size + right.columnCount;
  final rows = List.generate(size, (row) {
    return <Rational>[
      ...left[row].map((value) => Rational(value)),
      ...right[row].map((value) => Rational(value)),
    ];
  });

  for (var column = 0; column < size; column++) {
    int? pivotRow;
    for (var row = column; row < size; row++) {
      if (!rows[row][column].isZero) {
        pivotRow = row;
        break;
      }
    }
    if (pivotRow == null) {
      throw StateError('Matrix is singular');
    }
    if (pivotRow != column) {
      final temporary = rows[column];
      rows[column] = rows[pivotRow];
      rows[pivotRow] = temporary;
    }

    final pivot = rows[column][column];
    for (var k = column; k < totalColumns; k++) {
      rows[column][k] = rows[column][k] / pivot;
    }
    for (var row = 0; row < size; row++) {
      if (row == column) {
        continue;
      }
      final factor = rows[row][column];
      if (factor.isZero) {
        continue;
      }
      for (var k = column; k < totalColumns; k++) {
        rows[row][k] = rows[row][k] - factor * rows[column][k];
      }
    }
  }

  return IntMatrix.fromRows(
    List.generate(size, (row) {
      return List.generate(
        right.columnCount,
        (column) => rows[row][size + column].toBigIntExact(),
      );
    }),
    columnCount: right.columnCount,
  );
}

int? _smallestNonZeroPivot(List<List<BigInt>> rows, int firstRow, int column) {
  int? result;
  BigInt? smallest;
  for (var row = firstRow; row < rows.length; row++) {
    final value = rows[row][column];
    if (value == BigInt.zero) {
      continue;
    }
    final magnitude = value.abs();
    if (smallest == null || magnitude < smallest) {
      result = row;
      smallest = magnitude;
    }
  }
  return result;
}

BigInt _floorDivide(BigInt numerator, BigInt denominator) {
  if (denominator == BigInt.zero) {
    throw StateError('Division by zero');
  }
  var quotient = numerator ~/ denominator;
  final remainder = numerator.remainder(denominator);
  if (remainder != BigInt.zero &&
      (remainder < BigInt.zero) != (denominator < BigInt.zero)) {
    quotient -= BigInt.one;
  }
  return quotient;
}

List<List<double>> _gramSchmidt(List<List<BigInt>> basis, DoubleMatrix weight) {
  final vectors = basis.map(_toFiniteDoubles).toList();
  final orthogonal = vectors.map(List<double>.of).toList();
  for (var row = 1; row < vectors.length; row++) {
    var current = List<double>.of(orthogonal[row]);
    for (var previous = 0; previous < row; previous++) {
      final denominator = _inner(
        orthogonal[previous],
        orthogonal[previous],
        weight,
      );
      if (!denominator.isFinite || denominator <= 0.0) {
        throw StateError('Basis is linearly dependent or metric is invalid');
      }
      final coefficient =
          _inner(orthogonal[previous], vectors[row], weight) / denominator;
      for (var column = 0; column < current.length; column++) {
        current[column] -= coefficient * orthogonal[previous][column];
      }
    }
    orthogonal[row] = current;
  }
  return orthogonal;
}

double _inner(List<double> left, List<double> right, DoubleMatrix weight) {
  var result = 0.0;
  for (var row = 0; row < left.length; row++) {
    var weightedRight = 0.0;
    for (var column = 0; column < right.length; column++) {
      final symmetricWeight = (weight[row][column] + weight[column][row]) * 0.5;
      weightedRight += symmetricWeight * right[column];
    }
    result += left[row] * weightedRight;
  }
  if (!result.isFinite) {
    throw StateError('Floating-point overflow in weighted lattice operation');
  }
  return result;
}

double _weightedNormSquared(List<BigInt> vector, DoubleMatrix weight) {
  final doubles = _toFiniteDoubles(vector);
  return _inner(doubles, doubles, weight);
}

List<double> _toFiniteDoubles(Iterable<BigInt> values) => values
    .map((value) {
      final converted = value.toDouble();
      if (!converted.isFinite) {
        throw StateError(
          'Integer is too large for floating-point lattice reduction',
        );
      }
      return converted;
    })
    .toList(growable: false);

BigInt _roundTiesToEven(double value) {
  if (!value.isFinite) {
    throw StateError('Cannot round a non-finite value');
  }
  final lower = value.floorToDouble();
  final fraction = value - lower;
  final lowerInteger = BigInt.from(lower);
  if (fraction < 0.5) {
    return lowerInteger;
  }
  if (fraction > 0.5) {
    return lowerInteger + BigInt.one;
  }
  return lowerInteger.isEven ? lowerInteger : lowerInteger + BigInt.one;
}

void _validateMetric(DoubleMatrix weight, int dimension) {
  if (weight.rowCount != dimension || weight.columnCount != dimension) {
    throw ArgumentError(
      'Weight matrix must have shape ${dimension}x$dimension',
    );
  }
  const symmetryTolerance = 1e-8;
  for (var row = 0; row < dimension; row++) {
    for (var column = row + 1; column < dimension; column++) {
      final left = weight[row][column];
      final right = weight[column][row];
      final scale = math.max(1.0, math.max(left.abs(), right.abs()));
      if ((left - right).abs() > symmetryTolerance * scale) {
        throw ArgumentError('Weight matrix must be symmetric');
      }
    }
  }

  final lower = List.generate(
    dimension,
    (_) => List<double>.filled(dimension, 0.0),
  );
  for (var row = 0; row < dimension; row++) {
    for (var column = 0; column <= row; column++) {
      var value = (weight[row][column] + weight[column][row]) * 0.5;
      for (var k = 0; k < column; k++) {
        value -= lower[row][k] * lower[column][k];
      }
      if (row == column) {
        if (!value.isFinite || value <= 0.0) {
          throw ArgumentError('Weight matrix must be positive definite');
        }
        lower[row][column] = math.sqrt(value);
      } else {
        lower[row][column] = value / lower[column][column];
      }
    }
  }
}
