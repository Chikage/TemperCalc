import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/data/favorites_store.dart';
import 'package:temper_calc/data/settings_store.dart';
import 'package:temper_calc/domain/app_settings.dart';
import 'package:temper_calc/domain/favorite.dart';
import 'package:temper_calc/domain/models.dart';
import 'package:temper_calc/ui/home_shell.dart';

void main() {
  testWidgets('settings tab updates values and passes search parameters', (
    tester,
  ) async {
    final storage = _MemorySettingsStorage();
    final settings = SettingsController(storage);
    final favorites = FavoritesController(_MemoryFavoritesStorage());
    addTearDown(settings.dispose);
    addTearDown(favorites.dispose);
    SearchInput? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          settingsController: settings,
          favoritesController: favorites,
          onCalculate: (_) async => throw UnimplementedError(),
          onSearch: (input) async {
            submitted = input;
            return const TemperamentSearchResult(groups: []);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Search scope'), findsOneWidget);

    final scaleSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('display-scale-slider')),
    );
    scaleSlider.onChangeEnd!(75);
    await tester.pump();
    expect(settings.settings.displayScalePercent, 75);

    final dimensionField = find.descendant(
      of: find.byKey(const ValueKey('setting-maximum-dimension')),
      matching: find.byType(TextField),
    );
    await tester.enterText(dimensionField, '96');
    await tester.pump();
    expect(settings.settings.searchParameters.maximumDimension, 96);

    final mappingSwitch = find.byKey(const ValueKey('setting-field-mapping'));
    await tester.ensureVisible(mappingSwitch);
    await tester.pumpAndSettle();
    await tester.tap(mappingSwitch);
    await tester.pump();
    expect(settings.settings.shows(TemperamentInfoField.mapping), isFalse);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Search'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('search-subgroup')), '5');
    final searchButton = find.widgetWithText(FilledButton, 'Search');
    await tester.ensureVisible(searchButton);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.parameters.maximumDimension, 96);
    expect(storage.saved.searchParameters.maximumDimension, 96);
    expect(storage.saved.displayScalePercent, 75);
    expect(storage.saved.shows(TemperamentInfoField.mapping), isFalse);
  });
}

class _MemorySettingsStorage implements SettingsStorage {
  AppSettings saved = const AppSettings();

  @override
  Future<AppSettings> load() async => saved;

  @override
  Future<void> save(AppSettings settings) async {
    saved = settings;
  }
}

class _MemoryFavoritesStorage implements FavoritesStorage {
  @override
  Future<List<FavoriteEntry>> load() async => [];

  @override
  Future<void> save(List<FavoriteEntry> favorites) async {}
}
