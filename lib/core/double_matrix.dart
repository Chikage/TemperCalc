import 'dart:math' as math;

import 'int_matrix.dart';

/// A rectangular, immutable matrix of double-precision values.
final class DoubleMatrix {
  factory DoubleMatrix(List<List<double>> rows, {int? columnCount}) =>
      DoubleMatrix.fromRows(rows, columnCount: columnCount);

  factory DoubleMatrix.fromRows(
    Iterable<Iterable<double>> rows, {
    int? columnCount,
  }) {
    final copied = rows.map((row) => List<double>.of(row)).toList();
    final inferredColumns = copied.isEmpty
        ? (columnCount ?? 0)
        : copied.first.length;
    if (inferredColumns < 0) {
      throw ArgumentError.value(
        columnCount,
        'columnCount',
        'Must be non-negative',
      );
    }
    if (columnCount != null && columnCount != inferredColumns) {
      throw ArgumentError(
        'columnCount $columnCount does not match row width $inferredColumns',
      );
    }
    for (final row in copied) {
      if (row.length != inferredColumns) {
        throw ArgumentError('Matrix rows must all have the same length');
      }
      if (row.any((value) => !value.isFinite)) {
        throw ArgumentError('Matrix entries must be finite');
      }
    }
    return DoubleMatrix._(copied, copied.length, inferredColumns);
  }

  factory DoubleMatrix.fromNums(
    Iterable<Iterable<num>> rows, {
    int? columnCount,
  }) => DoubleMatrix.fromRows(
    rows.map((row) => row.map((value) => value.toDouble())),
    columnCount: columnCount,
  );

  factory DoubleMatrix.fromIntMatrix(IntMatrix matrix) => DoubleMatrix.fromRows(
    matrix.values.map((row) => row.map((value) => value.toDouble())),
    columnCount: matrix.columnCount,
  );

  factory DoubleMatrix.zero(int rowCount, int columnCount) {
    _validateDimensions(rowCount, columnCount);
    return DoubleMatrix._(
      List.generate(rowCount, (_) => List<double>.filled(columnCount, 0.0)),
      rowCount,
      columnCount,
    );
  }

  factory DoubleMatrix.identity(int size) {
    if (size < 0) {
      throw ArgumentError.value(size, 'size', 'Must be non-negative');
    }
    return DoubleMatrix.fromRows(
      List.generate(
        size,
        (row) => List.generate(size, (column) => row == column ? 1.0 : 0.0),
      ),
      columnCount: size,
    );
  }

  factory DoubleMatrix.diagonal(Iterable<double> diagonal) {
    final entries = List<double>.of(diagonal);
    return DoubleMatrix.fromRows(
      List.generate(
        entries.length,
        (row) => List.generate(
          entries.length,
          (column) => row == column ? entries[row] : 0.0,
        ),
      ),
      columnCount: entries.length,
    );
  }

  DoubleMatrix._(List<List<double>> rows, this.rowCount, this.columnCount)
    : _rows = List.unmodifiable(
        rows.map((row) => List<double>.unmodifiable(row)),
      );

  final List<List<double>> _rows;
  final int rowCount;
  final int columnCount;

  bool get isSquare => rowCount == columnCount;
  bool get isEmpty => rowCount == 0 || columnCount == 0;
  List<List<double>> get values => _rows;

  List<double> operator [](int row) => _rows[row];
  double at(int row, int column) => _rows[row][column];
  List<double> row(int index) => _rows[index];

  List<double> column(int index) {
    if (index < 0 || index >= columnCount) {
      throw RangeError.range(index, 0, columnCount - 1, 'index');
    }
    return List<double>.unmodifiable(
      List.generate(rowCount, (row) => _rows[row][index]),
    );
  }

  List<List<double>> toMutableRows() =>
      _rows.map((row) => List<double>.of(row)).toList();

  DoubleMatrix transpose() {
    if (columnCount == 0) {
      return DoubleMatrix.zero(0, rowCount);
    }
    return DoubleMatrix.fromRows(
      List.generate(
        columnCount,
        (column) => List.generate(rowCount, (row) => _rows[row][column]),
      ),
      columnCount: rowCount,
    );
  }

  DoubleMatrix submatrix(
    int rowStart,
    int rowEnd,
    int columnStart,
    int columnEnd,
  ) {
    RangeError.checkValidRange(rowStart, rowEnd, rowCount, 'rows');
    RangeError.checkValidRange(columnStart, columnEnd, columnCount, 'columns');
    return DoubleMatrix.fromRows(
      _rows
          .sublist(rowStart, rowEnd)
          .map((row) => row.sublist(columnStart, columnEnd)),
      columnCount: columnEnd - columnStart,
    );
  }

  DoubleMatrix add(DoubleMatrix other) {
    _requireSameShape(other);
    return DoubleMatrix.fromRows(
      List.generate(
        rowCount,
        (row) => List.generate(
          columnCount,
          (column) => _rows[row][column] + other._rows[row][column],
        ),
      ),
      columnCount: columnCount,
    );
  }

  DoubleMatrix subtract(DoubleMatrix other) {
    _requireSameShape(other);
    return DoubleMatrix.fromRows(
      List.generate(
        rowCount,
        (row) => List.generate(
          columnCount,
          (column) => _rows[row][column] - other._rows[row][column],
        ),
      ),
      columnCount: columnCount,
    );
  }

  DoubleMatrix scaled(double scalar) {
    if (!scalar.isFinite) {
      throw ArgumentError.value(scalar, 'scalar', 'Must be finite');
    }
    return DoubleMatrix.fromRows(
      _rows.map((row) => row.map((value) => value * scalar)),
      columnCount: columnCount,
    );
  }

  DoubleMatrix multiply(DoubleMatrix other) {
    if (columnCount != other.rowCount) {
      throw ArgumentError(
        'Cannot multiply ${rowCount}x$columnCount by '
        '${other.rowCount}x${other.columnCount}',
      );
    }
    return DoubleMatrix.fromRows(
      List.generate(
        rowCount,
        (row) => List.generate(other.columnCount, (column) {
          var sum = 0.0;
          for (var k = 0; k < columnCount; k++) {
            sum += _rows[row][k] * other._rows[k][column];
          }
          return sum;
        }),
      ),
      columnCount: other.columnCount,
    );
  }

  List<double> multiplyVector(List<double> vector) {
    if (vector.length != columnCount) {
      throw ArgumentError(
        'Vector length ${vector.length} does not match $columnCount columns',
      );
    }
    return List<double>.unmodifiable(
      List.generate(rowCount, (row) {
        var sum = 0.0;
        for (var column = 0; column < columnCount; column++) {
          sum += _rows[row][column] * vector[column];
        }
        return sum;
      }),
    );
  }

  double determinant({double tolerance = 1e-12}) {
    _requireSquare();
    _validateTolerance(tolerance);
    if (rowCount == 0) {
      return 1.0;
    }

    final work = toMutableRows();
    final rowScales = _rowScales(work);
    var determinant = 1.0;
    var sign = 1.0;

    for (var column = 0; column < columnCount; column++) {
      final pivotRow = _scaledPivotRow(work, rowScales, column, column);
      final pivotMagnitude = work[pivotRow][column].abs();
      if (pivotMagnitude <= tolerance * rowScales[pivotRow]) {
        return 0.0;
      }
      if (pivotRow != column) {
        final temporary = work[column];
        work[column] = work[pivotRow];
        work[pivotRow] = temporary;
        final scaleTemporary = rowScales[column];
        rowScales[column] = rowScales[pivotRow];
        rowScales[pivotRow] = scaleTemporary;
        sign = -sign;
      }

      final pivot = work[column][column];
      determinant *= pivot;
      for (var row = column + 1; row < rowCount; row++) {
        final factor = work[row][column] / pivot;
        work[row][column] = 0.0;
        for (var k = column + 1; k < columnCount; k++) {
          work[row][k] -= factor * work[column][k];
        }
      }
    }
    return sign * determinant;
  }

  DoubleMatrix inverse({double tolerance = 1e-12}) =>
      solve(DoubleMatrix.identity(rowCount), tolerance: tolerance);

  DoubleMatrix solve(DoubleMatrix rightHandSide, {double tolerance = 1e-12}) {
    _requireSquare();
    _validateTolerance(tolerance);
    if (rightHandSide.rowCount != rowCount) {
      throw ArgumentError(
        'Right-hand side has ${rightHandSide.rowCount} rows; expected $rowCount',
      );
    }
    if (rowCount == 0) {
      return DoubleMatrix.zero(0, rightHandSide.columnCount);
    }

    final left = toMutableRows();
    final right = rightHandSide.toMutableRows();
    final rowScales = _rowScales(left);

    for (var column = 0; column < columnCount; column++) {
      final pivotRow = _scaledPivotRow(left, rowScales, column, column);
      if (left[pivotRow][column].abs() <= tolerance * rowScales[pivotRow]) {
        throw StateError('Matrix is singular or numerically rank deficient');
      }
      if (pivotRow != column) {
        final leftTemporary = left[column];
        left[column] = left[pivotRow];
        left[pivotRow] = leftTemporary;
        final rightTemporary = right[column];
        right[column] = right[pivotRow];
        right[pivotRow] = rightTemporary;
        final scaleTemporary = rowScales[column];
        rowScales[column] = rowScales[pivotRow];
        rowScales[pivotRow] = scaleTemporary;
      }

      final pivot = left[column][column];
      for (var k = column; k < columnCount; k++) {
        left[column][k] /= pivot;
      }
      for (var k = 0; k < rightHandSide.columnCount; k++) {
        right[column][k] /= pivot;
      }

      for (var row = 0; row < rowCount; row++) {
        if (row == column) {
          continue;
        }
        final factor = left[row][column];
        if (factor == 0.0) {
          continue;
        }
        left[row][column] = 0.0;
        for (var k = column + 1; k < columnCount; k++) {
          left[row][k] -= factor * left[column][k];
        }
        for (var k = 0; k < rightHandSide.columnCount; k++) {
          right[row][k] -= factor * right[column][k];
        }
      }
    }

    return DoubleMatrix.fromRows(right, columnCount: rightHandSide.columnCount);
  }

  List<double> solveVector(
    List<double> rightHandSide, {
    double tolerance = 1e-12,
  }) {
    if (rightHandSide.length != rowCount) {
      throw ArgumentError(
        'Right-hand side length ${rightHandSide.length} does not match $rowCount rows',
      );
    }
    final solved = solve(
      DoubleMatrix.fromRows(
        rightHandSide.map((value) => [value]),
        columnCount: 1,
      ),
      tolerance: tolerance,
    );
    return List<double>.unmodifiable(solved.column(0));
  }

  static DoubleMatrix verticalStack(
    Iterable<DoubleMatrix> matrices, {
    int columnCount = 0,
  }) {
    final items = List<DoubleMatrix>.of(matrices);
    if (items.isEmpty) {
      return DoubleMatrix.zero(0, columnCount);
    }
    final columns = items.first.columnCount;
    if (items.any((matrix) => matrix.columnCount != columns)) {
      throw ArgumentError('All matrices must have the same column count');
    }
    return DoubleMatrix.fromRows(
      items.expand((matrix) => matrix._rows),
      columnCount: columns,
    );
  }

  static DoubleMatrix horizontalStack(
    Iterable<DoubleMatrix> matrices, {
    int rowCount = 0,
  }) {
    final items = List<DoubleMatrix>.of(matrices);
    if (items.isEmpty) {
      return DoubleMatrix.zero(rowCount, 0);
    }
    final rows = items.first.rowCount;
    if (items.any((matrix) => matrix.rowCount != rows)) {
      throw ArgumentError('All matrices must have the same row count');
    }
    return DoubleMatrix.fromRows(
      List.generate(rows, (row) => items.expand((matrix) => matrix._rows[row])),
      columnCount: items.fold<int>(
        0,
        (sum, matrix) => sum + matrix.columnCount,
      ),
    );
  }

  bool approximatelyEquals(
    DoubleMatrix other, {
    double absoluteTolerance = 1e-10,
    double relativeTolerance = 1e-10,
  }) {
    if (!sameShape(other)) {
      return false;
    }
    for (var row = 0; row < rowCount; row++) {
      for (var column = 0; column < columnCount; column++) {
        final a = _rows[row][column];
        final b = other._rows[row][column];
        final allowed =
            absoluteTolerance + relativeTolerance * math.max(a.abs(), b.abs());
        if ((a - b).abs() > allowed) {
          return false;
        }
      }
    }
    return true;
  }

  bool sameShape(DoubleMatrix other) =>
      rowCount == other.rowCount && columnCount == other.columnCount;

  void _requireSameShape(DoubleMatrix other) {
    if (!sameShape(other)) {
      throw ArgumentError(
        'Matrix shapes differ: ${rowCount}x$columnCount and '
        '${other.rowCount}x${other.columnCount}',
      );
    }
  }

  void _requireSquare() {
    if (!isSquare) {
      throw ArgumentError('Operation requires a square matrix');
    }
  }

  static int _scaledPivotRow(
    List<List<double>> rows,
    List<double> rowScales,
    int startRow,
    int column,
  ) {
    var pivot = startRow;
    var largest = rowScales[startRow] == 0.0
        ? 0.0
        : rows[startRow][column].abs() / rowScales[startRow];
    for (var row = startRow + 1; row < rows.length; row++) {
      final magnitude = rowScales[row] == 0.0
          ? 0.0
          : rows[row][column].abs() / rowScales[row];
      if (magnitude > largest) {
        largest = magnitude;
        pivot = row;
      }
    }
    return pivot;
  }

  static List<double> _rowScales(List<List<double>> rows) => rows
      .map(
        (row) => row.fold<double>(
          0.0,
          (largest, value) => math.max(largest, value.abs()),
        ),
      )
      .toList(growable: false);

  static void _validateTolerance(double tolerance) {
    if (!tolerance.isFinite || tolerance < 0.0) {
      throw ArgumentError.value(
        tolerance,
        'tolerance',
        'Must be finite and non-negative',
      );
    }
  }

  static void _validateDimensions(int rows, int columns) {
    if (rows < 0 || columns < 0) {
      throw ArgumentError('Matrix dimensions must be non-negative');
    }
  }

  @override
  String toString() => _rows.toString();
}
