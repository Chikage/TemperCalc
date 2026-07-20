import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/data/temperament_families.dart';

void main() {
  group('temperament family seeds', () {
    test('preserves the complete upstream order', () {
      expect(temperamentFamilySeeds, hasLength(139));

      expect(temperamentFamilySeeds.first.name, 'diaschismic');
      expect(temperamentFamilySeeds.first.comma, '2147483648/2109289329');
      expect(temperamentFamilySeeds.last.name, 'enneadecal');
      expect(temperamentFamilySeeds.last.comma, '[-37 57 0 -19]');

      expect(
        () => temperamentFamilySeeds.add(
          const TemperamentFamilySeed('extra', '1/1'),
        ),
        throwsUnsupportedError,
      );
    });

    test('keeps every comma for duplicate family names', () {
      expect(
        temperamentFamiliesNamed(
          'meantone',
        ).map((TemperamentFamilySeed seed) => seed.comma),
        orderedEquals(<String>['59049/57344', '81/80']),
      );
      expect(
        temperamentFamiliesNamed(
          'zeus',
        ).map((TemperamentFamilySeed seed) => seed.comma),
        orderedEquals(<String>['121/120', '176/175', '6144/6125']),
      );
      expect(temperamentFamiliesNamed('missing'), isEmpty);
      expect(
        () => temperamentFamiliesNamed(
          'zeus',
        ).add(const TemperamentFamilySeed('zeus', '1/1')),
        throwsUnsupportedError,
      );
    });

    test('looks up exact commas and preserves non-ASCII names', () {
      expect(temperamentFamilyForComma('81/80')?.name, 'meantone');
      expect(temperamentFamiliesNamed('würschmidt').single.comma, '[17 1 -8]');
      expect(temperamentFamilyForComma('[17 1 -8]')?.name, 'würschmidt');
      expect(temperamentFamilyForComma('1/1'), isNull);
    });
  });
}
