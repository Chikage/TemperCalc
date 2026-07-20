import '../core/int_matrix.dart';
import '../core/lattice.dart';
import '../core/rational.dart';
import 'input_parser.dart';
import 'interval.dart';
import 'models.dart';

class TemperamentDefinition {
  const TemperamentDefinition({
    required this.mapping,
    required this.expandedMapping,
    required this.basis,
    required this.expanded,
  });

  final IntMatrix mapping;
  final IntMatrix expandedMapping;
  final IntMatrix basis;
  final List<int> expanded;

  List<Rational> get subgroup => subgroupFromBasis(basis, expanded);
}

TemperamentDefinition buildTemperament(CalculatorInput input) {
  try {
    late SubgroupDefinition subgroup;
    if (input.subgroup.trim().isNotEmpty) {
      subgroup = parseSubgroup(input.subgroup);
    } else {
      if (input.source != CalculationSource.commas) {
        throw const TemperamentException('Subgroup is required for EDO input');
      }
      subgroup = inferSubgroupFromCommas(input.commas);
    }

    return switch (input.source) {
      CalculationSource.edos => temperamentFromEdos(
        input.edos,
        subgroup.basis,
        subgroup.expanded,
      ),
      CalculationSource.commas => temperamentFromCommas(
        input.commas,
        subgroup.basis,
        subgroup.expanded,
      ),
    };
  } on TemperamentException {
    rethrow;
  } on FormatException catch (error) {
    throw TemperamentException(error.message);
  } on ArgumentError catch (error) {
    throw TemperamentException(error.message?.toString() ?? 'Invalid input');
  } on StateError catch (error) {
    throw TemperamentException(error.message);
  }
}

SubgroupDefinition inferSubgroupFromCommas(String commaSource) {
  final expanded97 = primeLimit(97);
  final identity = IntMatrix.identity(expanded97.length);
  final intervals = parseIntervals(commaSource, identity, expanded97);
  if (intervals.isEmpty) {
    throw const TemperamentException('Enter at least one comma');
  }
  final commas = IntMatrix.horizontalStack(
    intervals,
    rowCount: expanded97.length,
  );
  final supported = <int>[];
  for (var row = 0; row < commas.rowCount; row++) {
    if (commas[row].any((value) => value != BigInt.zero)) {
      supported.add(expanded97[row]);
    }
  }
  if (supported.isEmpty) {
    throw const TemperamentException('Could not infer a subgroup');
  }
  return SubgroupDefinition(
    basis: IntMatrix.identity(supported.length),
    expanded: List.unmodifiable(supported),
  );
}

TemperamentDefinition temperamentFromCommas(
  String commaSource,
  IntMatrix basis,
  List<int> expanded,
) {
  final parsed = parseIntervals(commaSource, basis, expanded);
  if (parsed.isEmpty) {
    throw const TemperamentException('Enter at least one comma');
  }
  var commas = IntMatrix.horizontalStack(parsed, rowCount: expanded.length);
  commas = hnf(commas.transpose(), removeZeroRows: true).transpose();
  final expandedMapping = cokernel(commas);
  final subgroupCommas = solveDiophantine(basis, commas);
  final mapping = cokernel(subgroupCommas);
  if (mapping.rowCount == 0 ||
      mapping.columnCount == 0 ||
      mapping[0][0] == BigInt.zero) {
    throw const TemperamentException("Can't temper out the equave");
  }
  if (!expandedMapping.multiply(basis).multiply(subgroupCommas).isZero) {
    throw const TemperamentException('Comma is not in subgroup');
  }
  return TemperamentDefinition(
    mapping: mapping,
    expandedMapping: expandedMapping,
    basis: basis,
    expanded: List.unmodifiable(expanded),
  );
}

TemperamentDefinition temperamentFromEdos(
  String edoSource,
  IntMatrix basis,
  List<int> expanded,
) {
  final subgroup = subgroupFromBasis(basis, expanded);
  final maps = parseEdos(edoSource, subgroup);
  var mapping = hnf(IntMatrix.verticalStack(maps), removeZeroRows: true);
  mapping = defactoredHnf(mapping);
  final expandedMapping = hnf(cokernel(basis.multiply(kernel(mapping))));
  return TemperamentDefinition(
    mapping: mapping,
    expandedMapping: expandedMapping,
    basis: basis,
    expanded: List.unmodifiable(expanded),
  );
}
