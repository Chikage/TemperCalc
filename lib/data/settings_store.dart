import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';
import '../domain/models.dart';

abstract interface class SettingsStorage {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

class SharedPreferencesSettingsStorage implements SettingsStorage {
  static const storageKey = 'app_settings_v1';

  const SharedPreferencesSettingsStorage();

  @override
  Future<AppSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(storageKey);
    if (stored == null) return const AppSettings();
    try {
      return settingsFromJson(
        (jsonDecode(stored) as Map<Object?, Object?>).cast<String, Object?>(),
      );
    } on Object {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      jsonEncode(settingsToJson(settings)),
    );
  }
}

class SettingsController extends ChangeNotifier {
  SettingsController(this._storage);

  final SettingsStorage _storage;
  AppSettings _settings = const AppSettings();
  Future<void>? _loadOperation;
  Future<void> _saveChain = Future.value();
  int _revision = 0;
  bool _disposed = false;

  AppSettings get settings => _settings;

  Future<void> load() => _loadOperation ??= _performLoad();

  Future<void> _performLoad() async {
    final revision = _revision;
    try {
      final loaded = await _storage.load();
      if (revision == _revision) {
        _settings = loaded;
        _notify();
      }
    } finally {
      _loadOperation = null;
    }
  }

  void update(AppSettings settings) {
    _settings = settings;
    _revision++;
    _notify();
    _saveChain = _saveChain.then((_) => _storage.save(settings));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

Map<String, Object?> settingsToJson(AppSettings settings) => {
  'schemaVersion': 3,
  'displayScalePercent': settings.displayScalePercent,
  'maximumDimension': settings.searchParameters.maximumDimension,
  'maximumEdo': settings.searchParameters.maximumEdo,
  'explorationIterations': settings.searchParameters.explorationIterations,
  'resultsPerRank': settings.searchParameters.resultsPerRank,
  'timeoutSeconds': settings.searchParameters.timeoutSeconds,
  'tuningDecimalPlaces': settings.tuningDecimalPlaces,
  'errorsDecimalPlaces': settings.errorsDecimalPlaces,
  'primesDecimalPlaces': settings.primesDecimalPlaces,
  'badnessDecimalPlaces': settings.badnessDecimalPlaces,
  'complexityDecimalPlaces': settings.complexityDecimalPlaces,
  'visibleTemperamentInfoFields': [
    for (final field in settings.visibleTemperamentInfoFields) field.name,
  ],
};

AppSettings settingsFromJson(Map<String, Object?> json) {
  int integer(String key, int fallback, int minimum, int maximum) {
    final value = json[key];
    if (value is! num) return fallback;
    return value.toInt().clamp(minimum, maximum);
  }

  final storedFields = json['visibleTemperamentInfoFields'];
  final visibleFields = storedFields is List
      ? <TemperamentInfoField>{
          for (final name in storedFields.whereType<String>())
            for (final field in TemperamentInfoField.values)
              if (field.name == name) field,
        }
      : <TemperamentInfoField>{
          ...const AppSettings().visibleTemperamentInfoFields,
        };
  final storedSchemaVersion = json['schemaVersion'];
  final schemaVersion = storedSchemaVersion is num
      ? storedSchemaVersion.toInt()
      : 1;
  if (schemaVersion < 2) {
    if (visibleFields.contains(TemperamentInfoField.tunings)) {
      visibleFields.add(TemperamentInfoField.constrainedTunings);
    }
    if (visibleFields.contains(TemperamentInfoField.errors)) {
      visibleFields
        ..add(TemperamentInfoField.constrainedErrors)
        ..add(TemperamentInfoField.targetErrors);
    }
    if (visibleFields.contains(TemperamentInfoField.primes)) {
      visibleFields
        ..add(TemperamentInfoField.constrainedPrimes)
        ..add(TemperamentInfoField.targetPrimes);
    }
  }

  return AppSettings(
    displayScalePercent: integer('displayScalePercent', 100, 60, 140),
    searchParameters: SearchParameters(
      maximumDimension: integer('maximumDimension', 24, 2, 128),
      maximumEdo: integer('maximumEdo', 2000, 2, 1000000),
      explorationIterations: integer('explorationIterations', 12, 1, 1000),
      resultsPerRank: integer('resultsPerRank', 24, 1, 1000),
      timeoutSeconds: integer('timeoutSeconds', 15, 1, 3600),
    ),
    tuningDecimalPlaces: integer('tuningDecimalPlaces', 9, 0, 12),
    errorsDecimalPlaces: integer('errorsDecimalPlaces', 9, 0, 12),
    primesDecimalPlaces: integer('primesDecimalPlaces', 9, 0, 12),
    badnessDecimalPlaces: integer('badnessDecimalPlaces', 9, 0, 12),
    complexityDecimalPlaces: integer('complexityDecimalPlaces', 9, 0, 12),
    visibleTemperamentInfoFields: Set.unmodifiable(visibleFields),
  );
}
