import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/data/favorites_transfer.dart';
import 'package:temper_calc/domain/favorite.dart';
import 'package:temper_calc/domain/models.dart';

const _result = TemperamentInfo(
  rank: 2,
  subgroup: '2.3.5.7',
  families: ['meantone'],
  weakFamilies: ['porcupine'],
  commaBasis: [
    CommaInfo(vector: [-4, 4, -1, 0], ratio: '81/80'),
  ],
  equalDivisionsLabel: 'EDOs',
  equalDivisions: ['12', '19'],
  mapping: [
    [1, 1, 0, -3],
    [0, 1, 4, 10],
  ],
  preimage: ['2', '3/2'],
  tunings: {
    'WE tuning': ['1201.236', '697.212'],
  },
  errors: {
    'WE errors': ['1.236', '-3.507'],
  },
  primes: {
    'WE primes': ['1201.236', '1898.448'],
  },
  badness: '0.347',
);

void main() {
  test('archive is pretty printed and round trips complete favorites', () {
    final favorite = _favorite();
    final archive = FavoritesArchive.encode([
      favorite,
    ], exportedAt: DateTime.utc(2026, 7, 21, 9, 30));
    final json = jsonDecode(archive) as Map<String, Object?>;

    expect(archive, contains('\n  "format"'));
    expect(json['format'], 'temper-calc-favorites');
    expect(json['version'], 1);
    expect(json['exportedAt'], '2026-07-21T09:30:00.000Z');

    final decoded = FavoritesArchive.decode(archive).single;
    expect(decoded.id, favorite.id);
    expect(decoded.title, favorite.title);
    expect(decoded.result.families, _result.families);
    expect(decoded.result.commaBasis.single.ratio, '81/80');
    expect(decoded.result.mapping, _result.mapping);
    expect(decoded.result.tunings, _result.tunings);
  });

  test('archive decoder accepts a UTF-8 byte order mark', () {
    final archive = FavoritesArchive.encode([_favorite()]);
    expect(FavoritesArchive.decode('\uFEFF$archive'), hasLength(1));
  });

  test('archive decoder rejects malformed and unsupported files', () {
    expect(
      () => FavoritesArchive.decode('not json'),
      throwsA(
        isA<FavoritesArchiveException>().having(
          (error) => error.message,
          'message',
          contains('not valid JSON'),
        ),
      ),
    );
    expect(
      () => FavoritesArchive.decode(
        jsonEncode({
          'format': FavoritesArchive.format,
          'version': 2,
          'favorites': <Object?>[],
        }),
      ),
      throwsA(
        isA<FavoritesArchiveException>().having(
          (error) => error.message,
          'message',
          contains('version 2'),
        ),
      ),
    );
  });
}

FavoriteEntry _favorite() {
  return FavoriteEntry.fromCalculator(
    input: const CalculatorInput(
      subgroup: '7',
      source: CalculationSource.edos,
      reduction: GeneratorReduction.octave,
      weight: TuningWeight.weil,
      edos: '12, 19',
    ),
    result: _result,
    savedAt: DateTime.utc(2026, 7, 21, 8, 30),
  );
}
