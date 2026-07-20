import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/core/int_matrix.dart';
import 'package:temper_calc/domain/family_catalog.dart';

void main() {
  group('FamilyCatalog', () {
    test('caches the default 19-limit catalog', () {
      expect(identical(FamilyCatalog.instance, FamilyCatalog.instance), isTrue);
    });

    test('finds a strong meantone family from its canonical mapping', () {
      final matches = searchFamilies(
        <int>[2, 3, 5],
        IntMatrix.fromInts(<List<int>>[
          <int>[1, 0, -4],
          <int>[0, 1, 4],
        ]),
      );

      expect(matches.strong, contains('meantone'));
      expect(matches.weak, isNot(contains('meantone')));
      expect(() => matches.strong.add('other'), throwsUnsupportedError);
    });

    test('reports a defactored meantone mapping as a weak family', () {
      final matches = searchFamilies(
        <int>[2, 3, 5],
        IntMatrix.fromInts(<List<int>>[
          <int>[2, 0, -8],
          <int>[0, 2, 8],
        ]),
      );

      expect(matches.strong, isNot(contains('meantone')));
      expect(matches.weak, contains('meantone'));
    });

    test('matches the 12edo restriction to the compton family', () {
      final matches = searchFamilies(
        <int>[2, 3, 5],
        IntMatrix.fromInts(<List<int>>[
          <int>[12, 19, 28],
        ]),
      );

      expect(matches.strong, contains('compton'));
    });

    test('validates expanded mapping dimensions', () {
      expect(
        () => searchFamilies(
          <int>[2, 3, 5],
          IntMatrix.fromInts(<List<int>>[
            <int>[12, 19],
          ]),
        ),
        throwsArgumentError,
      );
    });
  });
}
