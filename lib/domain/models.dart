enum CalculationSource { edos, commas }

enum GeneratorReduction { off, octave, spine, layout }

enum TuningWeight { tenney, weil, unweighted }

enum BadnessType { cangwu, dirichlet }

extension GeneratorReductionLabel on GeneratorReduction {
  String get label => switch (this) {
    GeneratorReduction.off => 'Off',
    GeneratorReduction.octave => 'Octave',
    GeneratorReduction.spine => 'Spine + commas',
    GeneratorReduction.layout => 'Layout',
  };
}

extension TuningWeightLabel on TuningWeight {
  String get label => switch (this) {
    TuningWeight.tenney => 'Tenney',
    TuningWeight.weil => 'Weil',
    TuningWeight.unweighted => 'Unweighted',
  };

  String get abbreviation => switch (this) {
    TuningWeight.tenney => 'TE',
    TuningWeight.weil => 'WE',
    TuningWeight.unweighted => 'E',
  };
}

extension BadnessTypeLabel on BadnessType {
  String get label => switch (this) {
    BadnessType.cangwu => 'Cangwu',
    BadnessType.dirichlet => 'Dirichlet',
  };
}

class CalculatorInput {
  const CalculatorInput({
    required this.subgroup,
    required this.source,
    required this.reduction,
    required this.weight,
    this.edos = '',
    this.commas = '',
    this.target = '',
  });

  final String subgroup;
  final CalculationSource source;
  final GeneratorReduction reduction;
  final TuningWeight weight;
  final String edos;
  final String commas;
  final String target;
}

class SearchInput {
  const SearchInput({
    required this.subgroup,
    required this.badness,
    required this.reduction,
    required this.weight,
    this.edos = '',
    this.commas = '',
  });

  final String subgroup;
  final BadnessType badness;
  final GeneratorReduction reduction;
  final TuningWeight weight;
  final String edos;
  final String commas;
}

class CommaInfo {
  const CommaInfo({required this.vector, required this.ratio});

  final List<int> vector;
  final String ratio;
}

class TemperamentInfo {
  const TemperamentInfo({
    required this.rank,
    required this.subgroup,
    required this.commaBasis,
    required this.equalDivisionsLabel,
    required this.equalDivisions,
    required this.mapping,
    required this.preimage,
    required this.tunings,
    required this.errors,
    required this.primes,
    required this.badness,
    this.families = const [],
    this.weakFamilies = const [],
  });

  final int rank;
  final String subgroup;
  final List<String> families;
  final List<String> weakFamilies;
  final List<CommaInfo> commaBasis;
  final String equalDivisionsLabel;
  final List<String> equalDivisions;
  final List<List<int>> mapping;
  final List<String> preimage;
  final Map<String, List<String>> tunings;
  final Map<String, List<String>> errors;
  final Map<String, List<String>> primes;
  final String badness;
}

class SearchCandidate {
  const SearchCandidate({
    required this.rank,
    required this.label,
    required this.source,
    required this.families,
    required this.badness,
    required this.complexity,
  });

  final int rank;
  final String label;
  final CalculationSource source;
  final List<String> families;
  final double? badness;
  final double complexity;
}

class SearchGroup {
  const SearchGroup({required this.rank, required this.candidates});

  final int rank;
  final List<SearchCandidate> candidates;
}

class TemperamentSearchResult {
  const TemperamentSearchResult({required this.groups, this.warning});

  final List<SearchGroup> groups;
  final String? warning;
}

class TemperamentException implements Exception {
  const TemperamentException(this.message);

  final String message;

  @override
  String toString() => message;
}
