/// A rectangular, immutable matrix of arbitrary-precision integers.
final class IntMatrix {
  factory IntMatrix(List<List<BigInt>> rows, {int? columnCount}) =>
      IntMatrix.fromRows(rows, columnCount: columnCount);

  factory IntMatrix.fromRows(
    Iterable<Iterable<BigInt>> rows, {
    int? columnCount,
  }) {
    final copied = rows.map((row) => List<BigInt>.of(row)).toList();
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
    }
    return IntMatrix._(copied, copied.length, inferredColumns);
  }

  factory IntMatrix.fromInts(
    Iterable<Iterable<int>> rows, {
    int? columnCount,
  }) => IntMatrix.fromRows(
    rows.map((row) => row.map(BigInt.from)),
    columnCount: columnCount,
  );

  factory IntMatrix.zero(int rowCount, int columnCount) {
    _validateDimensions(rowCount, columnCount);
    return IntMatrix._(
      List.generate(
        rowCount,
        (_) => List<BigInt>.filled(columnCount, BigInt.zero),
      ),
      rowCount,
      columnCount,
    );
  }

  factory IntMatrix.identity(int size) {
    if (size < 0) {
      throw ArgumentError.value(size, 'size', 'Must be non-negative');
    }
    return IntMatrix.fromRows(
      List.generate(
        size,
        (row) => List.generate(
          size,
          (column) => row == column ? BigInt.one : BigInt.zero,
        ),
      ),
      columnCount: size,
    );
  }

  factory IntMatrix.diagonal(Iterable<BigInt> diagonal) {
    final entries = List<BigInt>.of(diagonal);
    return IntMatrix.fromRows(
      List.generate(
        entries.length,
        (row) => List.generate(
          entries.length,
          (column) => row == column ? entries[row] : BigInt.zero,
        ),
      ),
      columnCount: entries.length,
    );
  }

  IntMatrix._(List<List<BigInt>> rows, this.rowCount, this.columnCount)
    : _rows = List.unmodifiable(
        rows.map((row) => List<BigInt>.unmodifiable(row)),
      );

  final List<List<BigInt>> _rows;
  final int rowCount;
  final int columnCount;

  static final BigInt _minimumInt64 = -(BigInt.one << 63);
  static final BigInt _maximumInt64 = (BigInt.one << 63) - BigInt.one;

  bool get isSquare => rowCount == columnCount;
  bool get isEmpty => rowCount == 0 || columnCount == 0;
  bool get isZero =>
      _rows.every((row) => row.every((value) => value == BigInt.zero));

  List<List<BigInt>> get values => _rows;

  List<BigInt> operator [](int row) => _rows[row];

  BigInt at(int row, int column) => _rows[row][column];

  List<BigInt> row(int index) => _rows[index];

  List<BigInt> column(int index) {
    if (index < 0 || index >= columnCount) {
      throw RangeError.range(index, 0, columnCount - 1, 'index');
    }
    return List<BigInt>.unmodifiable(
      List.generate(rowCount, (row) => _rows[row][index]),
    );
  }

  List<List<BigInt>> toMutableRows() =>
      _rows.map((row) => List<BigInt>.of(row)).toList();

  List<BigInt> flatten() =>
      List<BigInt>.unmodifiable(_rows.expand((row) => row));

  List<List<int>> toIntsChecked() => _rows
      .map((row) {
        return row
            .map((value) {
              if (value < _minimumInt64 || value > _maximumInt64) {
                throw RangeError(
                  'Matrix entry $value does not fit in signed 64-bit int',
                );
              }
              return value.toInt();
            })
            .toList(growable: false);
      })
      .toList(growable: false);

  IntMatrix transpose() {
    if (columnCount == 0) {
      return IntMatrix.zero(0, rowCount);
    }
    return IntMatrix.fromRows(
      List.generate(
        columnCount,
        (column) => List.generate(rowCount, (row) => _rows[row][column]),
      ),
      columnCount: rowCount,
    );
  }

  IntMatrix submatrix(
    int rowStart,
    int rowEnd,
    int columnStart,
    int columnEnd,
  ) {
    RangeError.checkValidRange(rowStart, rowEnd, rowCount, 'rows');
    RangeError.checkValidRange(columnStart, columnEnd, columnCount, 'columns');
    return IntMatrix.fromRows(
      _rows
          .sublist(rowStart, rowEnd)
          .map((row) => row.sublist(columnStart, columnEnd)),
      columnCount: columnEnd - columnStart,
    );
  }

  IntMatrix withoutZeroRows() => IntMatrix.fromRows(
    _rows.where((row) => row.any((value) => value != BigInt.zero)),
    columnCount: columnCount,
  );

  IntMatrix add(IntMatrix other) {
    _requireSameShape(other);
    return IntMatrix.fromRows(
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

  IntMatrix subtract(IntMatrix other) {
    _requireSameShape(other);
    return IntMatrix.fromRows(
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

  IntMatrix scaled(BigInt scalar) => IntMatrix.fromRows(
    _rows.map((row) => row.map((value) => value * scalar)),
    columnCount: columnCount,
  );

  IntMatrix multiply(IntMatrix other) {
    if (columnCount != other.rowCount) {
      throw ArgumentError(
        'Cannot multiply ${rowCount}x$columnCount by '
        '${other.rowCount}x${other.columnCount}',
      );
    }
    return IntMatrix.fromRows(
      List.generate(
        rowCount,
        (row) => List.generate(other.columnCount, (column) {
          var sum = BigInt.zero;
          for (var k = 0; k < columnCount; k++) {
            sum += _rows[row][k] * other._rows[k][column];
          }
          return sum;
        }),
      ),
      columnCount: other.columnCount,
    );
  }

  List<BigInt> multiplyVector(List<BigInt> vector) {
    if (vector.length != columnCount) {
      throw ArgumentError(
        'Vector length ${vector.length} does not match $columnCount columns',
      );
    }
    return List<BigInt>.unmodifiable(
      List.generate(rowCount, (row) {
        var sum = BigInt.zero;
        for (var column = 0; column < columnCount; column++) {
          sum += _rows[row][column] * vector[column];
        }
        return sum;
      }),
    );
  }

  static IntMatrix verticalStack(
    Iterable<IntMatrix> matrices, {
    int columnCount = 0,
  }) {
    final items = List<IntMatrix>.of(matrices);
    if (items.isEmpty) {
      return IntMatrix.zero(0, columnCount);
    }
    final columns = items.first.columnCount;
    if (items.any((matrix) => matrix.columnCount != columns)) {
      throw ArgumentError('All matrices must have the same column count');
    }
    return IntMatrix.fromRows(
      items.expand((matrix) => matrix._rows),
      columnCount: columns,
    );
  }

  static IntMatrix horizontalStack(
    Iterable<IntMatrix> matrices, {
    int rowCount = 0,
  }) {
    final items = List<IntMatrix>.of(matrices);
    if (items.isEmpty) {
      return IntMatrix.zero(rowCount, 0);
    }
    final rows = items.first.rowCount;
    if (items.any((matrix) => matrix.rowCount != rows)) {
      throw ArgumentError('All matrices must have the same row count');
    }
    return IntMatrix.fromRows(
      List.generate(rows, (row) => items.expand((matrix) => matrix._rows[row])),
      columnCount: items.fold<int>(
        0,
        (sum, matrix) => sum + matrix.columnCount,
      ),
    );
  }

  bool sameShape(IntMatrix other) =>
      rowCount == other.rowCount && columnCount == other.columnCount;

  void _requireSameShape(IntMatrix other) {
    if (!sameShape(other)) {
      throw ArgumentError(
        'Matrix shapes differ: ${rowCount}x$columnCount and '
        '${other.rowCount}x${other.columnCount}',
      );
    }
  }

  static void _validateDimensions(int rows, int columns) {
    if (rows < 0 || columns < 0) {
      throw ArgumentError('Matrix dimensions must be non-negative');
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is! IntMatrix || !sameShape(other)) {
      return false;
    }
    for (var row = 0; row < rowCount; row++) {
      for (var column = 0; column < columnCount; column++) {
        if (_rows[row][column] != other._rows[row][column]) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(rowCount, columnCount, Object.hashAll(flatten()));

  @override
  String toString() => _rows.toString();
}
