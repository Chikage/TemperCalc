import '../domain/models.dart';

typedef CalculateCallback =
    Future<TemperamentInfo> Function(CalculatorInput input);
typedef SearchCallback =
    Future<TemperamentSearchResult> Function(SearchInput input);
