import 'models.dart';

enum TemperamentInfoField {
  rank,
  subgroup,
  families,
  commaBasis,
  equalDivisions,
  equalDivisionJoin,
  mapping,
  preimage,
  tunings,
  constrainedTunings,
  errors,
  constrainedErrors,
  targetErrors,
  primes,
  constrainedPrimes,
  targetPrimes,
  badness,
  complexity,
}

extension TemperamentInfoFieldLabel on TemperamentInfoField {
  String get label => switch (this) {
    TemperamentInfoField.rank => 'Rank',
    TemperamentInfoField.subgroup => 'Subgroup',
    TemperamentInfoField.families => 'Families',
    TemperamentInfoField.commaBasis => 'Comma basis',
    TemperamentInfoField.equalDivisions => 'Equal divisions',
    TemperamentInfoField.equalDivisionJoin => 'Equal division join',
    TemperamentInfoField.mapping => 'Mapping',
    TemperamentInfoField.preimage => 'Preimage',
    TemperamentInfoField.tunings => 'Tuning',
    TemperamentInfoField.constrainedTunings => 'Constrained tuning',
    TemperamentInfoField.errors => 'Errors',
    TemperamentInfoField.constrainedErrors => 'Constrained errors',
    TemperamentInfoField.targetErrors => 'Target errors',
    TemperamentInfoField.primes => 'Primes',
    TemperamentInfoField.constrainedPrimes => 'Constrained primes',
    TemperamentInfoField.targetPrimes => 'Target primes',
    TemperamentInfoField.badness => 'Badness',
    TemperamentInfoField.complexity => 'Complexity',
  };
}

class AppSettings {
  const AppSettings({
    this.searchParameters = const SearchParameters(),
    this.tuningDecimalPlaces = 9,
    this.errorsDecimalPlaces = 9,
    this.primesDecimalPlaces = 9,
    this.badnessDecimalPlaces = 9,
    this.complexityDecimalPlaces = 9,
    this.visibleTemperamentInfoFields = const {
      TemperamentInfoField.rank,
      TemperamentInfoField.subgroup,
      TemperamentInfoField.families,
      TemperamentInfoField.commaBasis,
      TemperamentInfoField.equalDivisions,
      TemperamentInfoField.equalDivisionJoin,
      TemperamentInfoField.mapping,
      TemperamentInfoField.preimage,
      TemperamentInfoField.tunings,
      TemperamentInfoField.constrainedTunings,
      TemperamentInfoField.errors,
      TemperamentInfoField.constrainedErrors,
      TemperamentInfoField.targetErrors,
      TemperamentInfoField.primes,
      TemperamentInfoField.constrainedPrimes,
      TemperamentInfoField.targetPrimes,
      TemperamentInfoField.badness,
      TemperamentInfoField.complexity,
    },
  }) : assert(tuningDecimalPlaces >= 0 && tuningDecimalPlaces <= 12),
       assert(errorsDecimalPlaces >= 0 && errorsDecimalPlaces <= 12),
       assert(primesDecimalPlaces >= 0 && primesDecimalPlaces <= 12),
       assert(badnessDecimalPlaces >= 0 && badnessDecimalPlaces <= 12),
       assert(complexityDecimalPlaces >= 0 && complexityDecimalPlaces <= 12);

  final SearchParameters searchParameters;
  final int tuningDecimalPlaces;
  final int errorsDecimalPlaces;
  final int primesDecimalPlaces;
  final int badnessDecimalPlaces;
  final int complexityDecimalPlaces;
  final Set<TemperamentInfoField> visibleTemperamentInfoFields;

  bool shows(TemperamentInfoField field) =>
      visibleTemperamentInfoFields.contains(field);

  AppSettings copyWith({
    SearchParameters? searchParameters,
    int? tuningDecimalPlaces,
    int? errorsDecimalPlaces,
    int? primesDecimalPlaces,
    int? badnessDecimalPlaces,
    int? complexityDecimalPlaces,
    Set<TemperamentInfoField>? visibleTemperamentInfoFields,
  }) => AppSettings(
    searchParameters: searchParameters ?? this.searchParameters,
    tuningDecimalPlaces: tuningDecimalPlaces ?? this.tuningDecimalPlaces,
    errorsDecimalPlaces: errorsDecimalPlaces ?? this.errorsDecimalPlaces,
    primesDecimalPlaces: primesDecimalPlaces ?? this.primesDecimalPlaces,
    badnessDecimalPlaces: badnessDecimalPlaces ?? this.badnessDecimalPlaces,
    complexityDecimalPlaces:
        complexityDecimalPlaces ?? this.complexityDecimalPlaces,
    visibleTemperamentInfoFields:
        visibleTemperamentInfoFields ?? this.visibleTemperamentInfoFields,
  );
}
