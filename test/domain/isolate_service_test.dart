import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/domain/models.dart';
import 'package:temper_calc/domain/temperament_info_service.dart';
import 'package:temper_calc/domain/temperament_search_service.dart';

void main() {
  test('calculation and search results cross an isolate boundary', () async {
    final info = await Isolate.run(
      () => const TemperamentInfoService().calculate(
        const CalculatorInput(
          subgroup: '5',
          source: CalculationSource.edos,
          reduction: GeneratorReduction.octave,
          weight: TuningWeight.weil,
          edos: '12',
        ),
      ),
    );
    expect(info.mapping, [
      [12, 19, 28],
    ]);

    final search = await Isolate.run(
      () => const TemperamentSearchService().search(
        const SearchInput(
          subgroup: '3',
          badness: BadnessType.cangwu,
          reduction: GeneratorReduction.octave,
          weight: TuningWeight.weil,
          edos: '12',
        ),
      ),
    );
    expect(search.warning, 'Empty search');
  });
}
