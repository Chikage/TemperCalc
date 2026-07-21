import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/data/settings_store.dart';
import 'package:temper_calc/domain/app_settings.dart';
import 'package:temper_calc/domain/models.dart';

void main() {
  test(
    'settings JSON round-trips search, precision, and visibility values',
    () {
      const settings = AppSettings(
        searchParameters: SearchParameters(
          maximumDimension: 96,
          maximumEdo: 750000,
          explorationIterations: 640,
          resultsPerRank: 512,
          timeoutSeconds: 1800,
        ),
        tuningDecimalPlaces: 2,
        errorsDecimalPlaces: 4,
        primesDecimalPlaces: 6,
        badnessDecimalPlaces: 8,
        complexityDecimalPlaces: 10,
        visibleTemperamentInfoFields: {
          TemperamentInfoField.rank,
          TemperamentInfoField.mapping,
        },
      );

      final decoded = settingsFromJson(settingsToJson(settings));

      expect(decoded.searchParameters.maximumDimension, 96);
      expect(decoded.searchParameters.maximumEdo, 750000);
      expect(decoded.searchParameters.explorationIterations, 640);
      expect(decoded.searchParameters.resultsPerRank, 512);
      expect(decoded.searchParameters.timeoutSeconds, 1800);
      expect(decoded.tuningDecimalPlaces, 2);
      expect(decoded.errorsDecimalPlaces, 4);
      expect(decoded.primesDecimalPlaces, 6);
      expect(decoded.badnessDecimalPlaces, 8);
      expect(decoded.complexityDecimalPlaces, 10);
      expect(decoded.visibleTemperamentInfoFields, {
        TemperamentInfoField.rank,
        TemperamentInfoField.mapping,
      });
    },
  );

  test('stored numeric values are clamped to the aggressive UI ranges', () {
    final decoded = settingsFromJson({
      'maximumDimension': 999,
      'maximumEdo': 9999999,
      'explorationIterations': 9999,
      'resultsPerRank': 9999,
      'timeoutSeconds': 9999,
      'tuningDecimalPlaces': 99,
      'errorsDecimalPlaces': -1,
      'complexityDecimalPlaces': 99,
    });

    expect(decoded.searchParameters.maximumDimension, 128);
    expect(decoded.searchParameters.maximumEdo, 1000000);
    expect(decoded.searchParameters.explorationIterations, 1000);
    expect(decoded.searchParameters.resultsPerRank, 1000);
    expect(decoded.searchParameters.timeoutSeconds, 3600);
    expect(decoded.tuningDecimalPlaces, 12);
    expect(decoded.errorsDecimalPlaces, 0);
    expect(decoded.complexityDecimalPlaces, 12);
  });

  test('older grouped visibility settings keep all matching result rows', () {
    final decoded = settingsFromJson({
      'visibleTemperamentInfoFields': ['tunings', 'errors', 'primes'],
    });

    expect(decoded.shows(TemperamentInfoField.tunings), isTrue);
    expect(decoded.shows(TemperamentInfoField.constrainedTunings), isTrue);
    expect(decoded.shows(TemperamentInfoField.constrainedErrors), isTrue);
    expect(decoded.shows(TemperamentInfoField.targetErrors), isTrue);
    expect(decoded.shows(TemperamentInfoField.constrainedPrimes), isTrue);
    expect(decoded.shows(TemperamentInfoField.targetPrimes), isTrue);
  });
}
