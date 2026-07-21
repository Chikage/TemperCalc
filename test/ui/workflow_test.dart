import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/data/favorites_store.dart';
import 'package:temper_calc/data/favorites_transfer.dart';
import 'package:temper_calc/domain/favorite.dart';
import 'package:temper_calc/domain/models.dart';
import 'package:temper_calc/ui/app_theme.dart';
import 'package:temper_calc/ui/home_shell.dart';
import 'package:temper_calc/ui/result_page.dart';

const _result = TemperamentInfo(
  rank: 2,
  subgroup: '2.3.5.7',
  families: ['meantone'],
  commaBasis: [
    CommaInfo(vector: [-4, 4, -1, 0], ratio: '81/80'),
    CommaInfo(vector: [-5, 2, 2, -1], ratio: '225/224'),
  ],
  equalDivisionsLabel: 'EDOs',
  equalDivisions: ['12', '19', '31'],
  mapping: [
    [1, 1, 0, -3],
    [0, 1, 4, 10],
  ],
  preimage: ['2', '3/2'],
  tunings: {
    'WE tuning': ['1201.236', '697.212'],
    'CWE tuning': ['1200.000', '696.656'],
  },
  errors: {
    'WE errors': ['1.236', '-3.507', '2.535', '-0.412'],
  },
  primes: {
    'WE primes': ['1201.236', '1898.448', '2788.849', '3368.414'],
  },
  badness: '0.347',
);

const _searchResult = TemperamentSearchResult(
  groups: [
    SearchGroup(
      rank: 2,
      candidates: [
        SearchCandidate(
          rank: 2,
          label: '81/80',
          source: CalculationSource.commas,
          families: ['meantone'],
          badness: 0.778,
          complexity: 3.8,
        ),
      ],
    ),
  ],
);

const _twoCandidateResult = TemperamentSearchResult(
  groups: [
    SearchGroup(
      rank: 2,
      candidates: [
        SearchCandidate(
          rank: 2,
          label: '81/80',
          source: CalculationSource.commas,
          families: ['meantone'],
          badness: 0.778,
          complexity: 3.8,
        ),
        SearchCandidate(
          rank: 2,
          label: '128/125',
          source: CalculationSource.commas,
          families: ['augmented'],
          badness: 1.235,
          complexity: 4.2,
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('calculator switches input mode and presents the result matrix', (
    tester,
  ) async {
    CalculatorInput? submittedInput;

    await _pumpApp(
      tester,
      onCalculate: (input) async {
        submittedInput = input;
        return _result;
      },
    );

    expect(find.byKey(const ValueKey('calculator-edos')), findsOneWidget);
    expect(find.byKey(const ValueKey('calculator-commas')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('calculator-subgroup')),
      '7',
    );
    await tester.enterText(
      find.byKey(const ValueKey('calculator-edos')),
      '12, 31',
    );

    final definitionRect = tester.getRect(find.text('Definition'));
    final sourceSwitchRect = tester.getRect(find.text('EDOs'));
    final targetLabelRect = tester.getRect(find.text('Target intervals'));
    final edosLabelRect = tester.getRect(find.text('List of EDOs'));
    final targetFieldRect = tester.getRect(
      find.byKey(const ValueKey('calculator-target')),
    );
    final sourceSelectorRect = tester.getRect(
      find.byKey(const ValueKey('definition-selector')),
    );
    final edosFieldRect = tester.getRect(
      find.byKey(const ValueKey('calculator-edos')),
    );
    expect(sourceSwitchRect.center.dy, closeTo(definitionRect.center.dy, 0.1));
    expect(sourceSwitchRect.left, greaterThan(definitionRect.left));
    expect(definitionRect.left, closeTo(targetLabelRect.left, 0.1));
    expect(definitionRect.left, closeTo(edosLabelRect.left, 0.1));
    expect(
      sourceSelectorRect.center.dy,
      closeTo((targetFieldRect.bottom + edosFieldRect.top) / 2, 0.1),
    );

    await tester.tap(find.text('Commas'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('calculator-edos')), findsNothing);
    expect(find.byKey(const ValueKey('calculator-commas')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('calculator-commas')),
      '81/80, 225/224',
    );

    await tester.tap(find.text('EDOs'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('calculator-edos')))
          .controller!
          .text,
      '12, 31',
    );
    await tester.tap(find.text('Commas'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('calculator-commas')),
          )
          .controller!
          .text,
      '81/80, 225/224',
    );

    final calculateButton = find.widgetWithText(FilledButton, 'Calculate');
    await tester.ensureVisible(calculateButton);
    await tester.tap(calculateButton);
    await tester.pumpAndSettle();

    expect(submittedInput, isNotNull);
    expect(submittedInput!.subgroup, '7');
    expect(submittedInput!.source, CalculationSource.commas);
    expect(submittedInput!.edos, '12, 31');
    expect(submittedInput!.commas, '81/80, 225/224');
    expect(submittedInput!.reduction, GeneratorReduction.octave);
    expect(submittedInput!.weight, TuningWeight.weil);

    expect(find.text('Temperament info'), findsOneWidget);
    expect(find.text('rank'), findsOneWidget);
    expect(find.text('mapping'), findsOneWidget);
    final matrixText = tester.widget<SelectableText>(
      find.descendant(
        of: find.byType(MatrixView),
        matching: find.byType(SelectableText),
      ),
    );
    expect(matrixText.data, '1  1  0  -3\n0  1  4  10');
    expect(find.byKey(const ValueKey('mapping-left-bracket')), findsOneWidget);
    expect(find.byKey(const ValueKey('mapping-right-bracket')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search opens a candidate through the calculation callback', (
    tester,
  ) async {
    SearchInput? submittedSearch;
    CalculatorInput? openedCandidate;

    await _pumpApp(
      tester,
      onSearch: (input) async {
        submittedSearch = input;
        return _searchResult;
      },
      onCalculate: (input) async {
        openedCandidate = input;
        return _result;
      },
    );

    final searchDestination = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Search'),
    );
    await tester.tap(searchDestination);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('search-subgroup')), '5');
    final searchButton = find.widgetWithText(FilledButton, 'Search');
    await tester.ensureVisible(searchButton);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    expect(submittedSearch, isNotNull);
    expect(submittedSearch!.subgroup, '5');
    expect(submittedSearch!.badness, BadnessType.cangwu);
    expect(submittedSearch!.reduction, GeneratorReduction.octave);
    expect(submittedSearch!.weight, TuningWeight.weil);

    await tester.scrollUntilVisible(
      find.text('81/80'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('81/80'));
    await tester.pumpAndSettle();

    expect(openedCandidate, isNotNull);
    expect(openedCandidate!.subgroup, '5');
    expect(openedCandidate!.source, CalculationSource.commas);
    expect(openedCandidate!.edos, isEmpty);
    expect(openedCandidate!.commas, '81/80');
    expect(openedCandidate!.reduction, GeneratorReduction.octave);
    expect(openedCandidate!.weight, TuningWeight.weil);
    expect(find.text('Temperament info'), findsOneWidget);
    expect(find.byType(MatrixView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calculator result can be saved, opened, and removed', (
    tester,
  ) async {
    final controller = FavoritesController(_MemoryFavoritesStorage());
    addTearDown(controller.dispose);
    await _pumpApp(tester, favoritesController: controller);

    await tester.enterText(
      find.byKey(const ValueKey('calculator-subgroup')),
      '5',
    );
    await tester.enterText(find.byKey(const ValueKey('calculator-edos')), '12');
    final calculateButton = find.widgetWithText(FilledButton, 'Calculate');
    await tester.ensureVisible(calculateButton);
    await tester.tap(calculateButton);
    await tester.pumpAndSettle();

    final favoriteButton = find.byKey(const ValueKey('favorite-result'));
    final copyButton = find.byTooltip('Copy result');
    expect(favoriteButton, findsOneWidget);
    expect(
      tester.getCenter(favoriteButton).dx,
      lessThan(tester.getCenter(copyButton).dx),
    );

    await tester.tap(favoriteButton);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await _openFavorites(tester);
    const title = '5 | EDOs 12 - Rank 2 | meantone | Badness 0.347';
    expect(find.text(title), findsOneWidget);

    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    expect(find.text('Temperament info'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove from favorites'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('No favorites yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search result can be saved with its search summary', (
    tester,
  ) async {
    final controller = FavoritesController(_MemoryFavoritesStorage());
    addTearDown(controller.dispose);
    await _pumpApp(tester, favoritesController: controller);
    await _openSearch(tester);
    await tester.enterText(find.byKey(const ValueKey('search-subgroup')), '5');
    final searchButton = find.widgetWithText(FilledButton, 'Search');
    await tester.ensureVisible(searchButton);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('81/80'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('81/80'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('favorite-result')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _openFavorites(tester);

    expect(
      find.text('5 | Cangwu | 81/80 - Rank 2 | meantone | Badness 0.347'),
      findsOneWidget,
    );
    expect(find.text('Search | Octave | WE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favorites can be imported and exported as JSON', (tester) async {
    final imported = FavoriteEntry.fromCalculator(
      input: const CalculatorInput(
        subgroup: '5',
        source: CalculationSource.edos,
        reduction: GeneratorReduction.octave,
        weight: TuningWeight.weil,
        edos: '12',
      ),
      result: _result,
      savedAt: DateTime.utc(2026, 7, 21),
    );
    final transfer = _MemoryFavoritesFileTransfer(
      importSource: FavoritesArchive.encode([imported]),
    );
    final controller = FavoritesController(_MemoryFavoritesStorage());
    addTearDown(controller.dispose);
    await _pumpApp(
      tester,
      favoritesController: controller,
      favoritesFileTransfer: transfer,
    );
    await _openFavorites(tester);

    final exportBeforeImport = tester.widget<IconButton>(
      find.byKey(const ValueKey('export-favorites')),
    );
    expect(exportBeforeImport.onPressed, isNull);
    await tester.tap(find.byTooltip('Import favorites'));
    await tester.pumpAndSettle();

    expect(find.text(imported.title), findsOneWidget);
    expect(find.text('Imported 1 added'), findsOneWidget);

    await tester.tap(find.byTooltip('Export favorites'));
    await tester.pumpAndSettle();

    expect(transfer.exportedFileName, startsWith('temper-calc-favorites-'));
    expect(transfer.exportedFileName, endsWith('.json'));
    final exported = FavoritesArchive.decode(transfer.exportedContents!);
    expect(exported.single.id, imported.id);
    expect(find.text('Exported 1 favorite'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validation scrolls the first invalid field into view', (
    tester,
  ) async {
    await _pumpApp(tester, size: const Size(844, 390));
    await _openSearch(tester);

    final searchButton = find.widgetWithText(FilledButton, 'Search');
    await tester.ensureVisible(searchButton);
    await tester.pump();
    expect(searchButton.hitTestable(), findsOneWidget);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    final errorRect = tester.getRect(find.text('Subgroup is required'));
    expect(errorRect.top, greaterThanOrEqualTo(0));
    expect(errorRect.bottom, lessThanOrEqualTo(390));
    expect(tester.takeException(), isNull);
  });

  testWidgets('large accessibility text does not overflow form controls', (
    tester,
  ) async {
    await _pumpApp(tester, textScaler: const TextScaler.linear(2));
    expect(tester.takeException(), isNull);
    await _openSearch(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only one search candidate can open at a time', (tester) async {
    final calculation = Completer<TemperamentInfo>();
    var calculateCalls = 0;
    await _pumpApp(
      tester,
      onSearch: (_) async => _twoCandidateResult,
      onCalculate: (_) {
        calculateCalls++;
        return calculation.future;
      },
    );
    await _openSearch(tester);
    await tester.enterText(find.byKey(const ValueKey('search-subgroup')), '5');
    final searchButton = find.widgetWithText(FilledButton, 'Search');
    await tester.ensureVisible(searchButton);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('81/80'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('81/80'));
    await tester.pump();
    await tester.tap(find.text('128/125'));
    await tester.pump();
    expect(calculateCalls, 1);

    calculation.complete(_result);
    await tester.pumpAndSettle();
  });

  testWidgets('hidden workflows do not push completed results', (tester) async {
    final calculation = Completer<TemperamentInfo>();
    await _pumpApp(tester, onCalculate: (_) => calculation.future);
    await tester.enterText(
      find.byKey(const ValueKey('calculator-subgroup')),
      '5',
    );
    await tester.enterText(find.byKey(const ValueKey('calculator-edos')), '12');
    final calculateButton = find.widgetWithText(FilledButton, 'Calculate');
    await tester.ensureVisible(calculateButton);
    await tester.tap(calculateButton);
    await tester.pump();
    await _openSearch(tester);

    calculation.complete(_result);
    await tester.pumpAndSettle();
    expect(find.text('Search temperaments'), findsOneWidget);
    expect(find.text('Temperament info'), findsNothing);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  Future<TemperamentInfo> Function(CalculatorInput input)? onCalculate,
  Future<TemperamentSearchResult> Function(SearchInput input)? onSearch,
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  FavoritesController? favoritesController,
  FavoritesFileTransfer favoritesFileTransfer =
      const FilePickerFavoritesFileTransfer(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: textScaler),
        child: HomeShell(
          onCalculate: onCalculate ?? (_) async => _result,
          onSearch: onSearch ?? (_) async => _searchResult,
          favoritesController: favoritesController,
          favoritesFileTransfer: favoritesFileTransfer,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSearch(WidgetTester tester) async {
  final searchDestination = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text('Search'),
  );
  await tester.tap(searchDestination);
  await tester.pumpAndSettle();
}

Future<void> _openFavorites(WidgetTester tester) async {
  final favoritesDestination = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text('Favorites'),
  );
  await tester.tap(favoritesDestination);
  await tester.pumpAndSettle();
}

class _MemoryFavoritesStorage implements FavoritesStorage {
  List<FavoriteEntry> values = [];

  @override
  Future<List<FavoriteEntry>> load() async => List.of(values);

  @override
  Future<void> save(List<FavoriteEntry> favorites) async {
    values = List.of(favorites);
  }
}

class _MemoryFavoritesFileTransfer implements FavoritesFileTransfer {
  _MemoryFavoritesFileTransfer({this.importSource});

  final String? importSource;
  String? exportedContents;
  String? exportedFileName;

  @override
  Future<String?> pickArchive() async => importSource;

  @override
  Future<bool> saveArchive({
    required String contents,
    required String fileName,
  }) async {
    exportedContents = contents;
    exportedFileName = fileName;
    return true;
  }
}
