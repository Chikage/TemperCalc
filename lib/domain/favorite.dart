import 'dart:convert';

import 'models.dart';

enum FavoriteOrigin { calculator, search }

class FavoriteEntry {
  const FavoriteEntry({
    required this.id,
    required this.title,
    required this.details,
    required this.origin,
    required this.savedAt,
    required this.result,
  });

  factory FavoriteEntry.fromCalculator({
    required CalculatorInput input,
    required TemperamentInfo result,
    DateTime? savedAt,
  }) {
    final subgroup = _compact(input.subgroup).isEmpty
        ? result.subgroup
        : _compact(input.subgroup);
    final definition = input.source == CalculationSource.edos
        ? 'EDOs ${_compact(input.edos)}'
        : 'Commas ${_compact(input.commas)}';
    final queryParts = [
      subgroup,
      definition,
      if (_compact(input.target).isNotEmpty)
        'Targets ${_compact(input.target)}',
    ];
    final identity = jsonEncode({
      'origin': FavoriteOrigin.calculator.name,
      'subgroup': _compact(input.subgroup),
      'source': input.source.name,
      'reduction': input.reduction.name,
      'weight': input.weight.name,
      'edos': _compact(input.edos),
      'commas': _compact(input.commas),
      'target': _compact(input.target),
    });
    return FavoriteEntry(
      id: identity,
      title: '${queryParts.join(' | ')} - ${_resultSummary(result)}',
      details:
          'Calculate | ${input.reduction.label} | ${input.weight.abbreviation}',
      origin: FavoriteOrigin.calculator,
      savedAt: savedAt ?? DateTime.now(),
      result: result,
    );
  }

  factory FavoriteEntry.fromSearch({
    required SearchInput input,
    required SearchCandidate candidate,
    required TemperamentInfo result,
    DateTime? savedAt,
  }) {
    final filters = [
      if (_compact(input.edos).isNotEmpty) 'EDOs ${_compact(input.edos)}',
      if (_compact(input.commas).isNotEmpty) 'Commas ${_compact(input.commas)}',
    ];
    final queryParts = [
      _compact(input.subgroup),
      input.badness.label,
      ...filters,
      candidate.label,
    ];
    final identity = jsonEncode({
      'origin': FavoriteOrigin.search.name,
      'subgroup': _compact(input.subgroup),
      'badness': input.badness.name,
      'reduction': input.reduction.name,
      'weight': input.weight.name,
      'edos': _compact(input.edos),
      'commas': _compact(input.commas),
      'candidateSource': candidate.source.name,
      'candidate': candidate.label,
    });
    return FavoriteEntry(
      id: identity,
      title: '${queryParts.join(' | ')} - ${_resultSummary(result)}',
      details:
          'Search | ${input.reduction.label} | ${input.weight.abbreviation}',
      origin: FavoriteOrigin.search,
      savedAt: savedAt ?? DateTime.now(),
      result: result,
    );
  }

  factory FavoriteEntry.fromJson(Map<String, Object?> json) {
    return FavoriteEntry(
      id: json['id']! as String,
      title: json['title']! as String,
      details: json['details']! as String,
      origin: FavoriteOrigin.values.byName(json['origin']! as String),
      savedAt: DateTime.parse(json['savedAt']! as String),
      result: _resultFromJson(
        (json['result']! as Map<Object?, Object?>).cast<String, Object?>(),
      ),
    );
  }

  final String id;
  final String title;
  final String details;
  final FavoriteOrigin origin;
  final DateTime savedAt;
  final TemperamentInfo result;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'details': details,
    'origin': origin.name,
    'savedAt': savedAt.toIso8601String(),
    'result': _resultToJson(result),
  };
}

String _compact(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');

String _resultSummary(TemperamentInfo result) {
  final families = [
    ...result.families,
    ...result.weakFamilies.map((name) => '($name)'),
  ];
  return [
    'Rank ${result.rank}',
    if (families.isNotEmpty) families.join(', '),
    'Badness ${result.badness}',
  ].join(' | ');
}

Map<String, Object?> _resultToJson(TemperamentInfo result) => {
  'rank': result.rank,
  'subgroup': result.subgroup,
  'families': result.families,
  'weakFamilies': result.weakFamilies,
  'commaBasis': [
    for (final comma in result.commaBasis)
      {'vector': comma.vector, 'ratio': comma.ratio},
  ],
  'equalDivisionsLabel': result.equalDivisionsLabel,
  'equalDivisions': result.equalDivisions,
  'equalDivisionJoinLabel': result.equalDivisionJoinLabel,
  'equalDivisionJoin': result.equalDivisionJoin,
  'mapping': result.mapping,
  'preimage': result.preimage,
  'tunings': result.tunings,
  'errors': result.errors,
  'primes': result.primes,
  'badness': result.badness,
  'complexity': result.complexity,
};

TemperamentInfo _resultFromJson(Map<String, Object?> json) {
  List<String> strings(String key) => (json[key]! as List<Object?>).cast();
  Map<String, List<String>> stringLists(String key) => {
    for (final entry in (json[key]! as Map<Object?, Object?>).entries)
      entry.key! as String: (entry.value! as List<Object?>).cast<String>(),
  };

  final equalDivisions = List<String>.of(strings('equalDivisions'));
  var equalDivisionJoinLabel = json['equalDivisionJoinLabel'] as String?;
  var equalDivisionJoin = json['equalDivisionJoin'] as String?;
  if (equalDivisionJoin == null && equalDivisions.isNotEmpty) {
    final legacyJoin = RegExp(
      r'^(.+ join):\s*(.+)$',
    ).firstMatch(equalDivisions.last);
    if (legacyJoin != null) {
      equalDivisionJoinLabel = legacyJoin.group(1);
      equalDivisionJoin = legacyJoin.group(2);
      equalDivisions.removeLast();
    }
  }

  return TemperamentInfo(
    rank: json['rank']! as int,
    subgroup: json['subgroup']! as String,
    families: strings('families'),
    weakFamilies: strings('weakFamilies'),
    commaBasis: [
      for (final value in json['commaBasis']! as List<Object?>)
        _commaFromJson(value),
    ],
    equalDivisionsLabel: json['equalDivisionsLabel']! as String,
    equalDivisions: equalDivisions,
    equalDivisionJoinLabel: equalDivisionJoinLabel,
    equalDivisionJoin: equalDivisionJoin,
    mapping: [
      for (final row in json['mapping']! as List<Object?>)
        (row! as List<Object?>).cast<int>(),
    ],
    preimage: strings('preimage'),
    tunings: stringLists('tunings'),
    errors: stringLists('errors'),
    primes: stringLists('primes'),
    badness: json['badness']! as String,
    complexity: json['complexity'] as String? ?? 'NA',
  );
}

CommaInfo _commaFromJson(Object? value) {
  final json = (value! as Map<Object?, Object?>).cast<String, Object?>();
  return CommaInfo(
    vector: (json['vector']! as List<Object?>).cast<int>(),
    ratio: json['ratio']! as String,
  );
}
