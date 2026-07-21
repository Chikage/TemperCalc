import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/settings_store.dart';
import 'domain/models.dart';
import 'domain/temperament_info_service.dart';
import 'domain/temperament_search_service.dart';
import 'ui/app_callbacks.dart' as callbacks;
import 'ui/app_theme.dart';
import 'ui/display_scale.dart';
import 'ui/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(['Sin-tel/temper'], _upstreamLicense),
    ),
  );
  runApp(const TemperCalcApp());
}

const _upstreamLicense = '''
MIT License

Copyright (c) 2024 Sintel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

class TemperCalcApp extends StatefulWidget {
  const TemperCalcApp({
    this.onCalculate,
    this.onSearch,
    this.settingsController,
    super.key,
  });

  final callbacks.CalculateCallback? onCalculate;
  final callbacks.SearchCallback? onSearch;
  final SettingsController? settingsController;

  @override
  State<TemperCalcApp> createState() => _TemperCalcAppState();
}

class _TemperCalcAppState extends State<TemperCalcApp> {
  late final SettingsController _settings;
  late final bool _ownsSettings;

  @override
  void initState() {
    super.initState();
    _ownsSettings = widget.settingsController == null;
    _settings =
        widget.settingsController ??
        SettingsController(const SharedPreferencesSettingsStorage());
    unawaited(_settings.load());
  }

  @override
  void dispose() {
    if (_ownsSettings) _settings.dispose();
    super.dispose();
  }

  Future<TemperamentInfo> _calculate(CalculatorInput input) => _runWorker(
    _calculateWorker,
    input,
    timeoutMessage: 'Calculation took too long',
  );

  Future<TemperamentSearchResult> _search(SearchInput input) => _runWorker(
    _searchWorker,
    input,
    timeout: Duration(seconds: input.parameters.timeoutSeconds),
    timeoutMessage: 'Search took too long',
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Temper Calc',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      builder: (context, child) => AnimatedBuilder(
        animation: _settings,
        child: child,
        builder: (context, child) => AppDisplayScale(
          percent: _settings.settings.displayScalePercent,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: HomeShell(
        onCalculate: widget.onCalculate ?? _calculate,
        onSearch: widget.onSearch ?? _search,
        settingsController: _settings,
      ),
    );
  }
}

void _calculateWorker((SendPort, CalculatorInput) message) {
  try {
    final result = const TemperamentInfoService().calculate(message.$2);
    message.$1.send([true, result]);
  } catch (error) {
    message.$1.send([false, error.toString()]);
  }
}

void _searchWorker((SendPort, SearchInput) message) {
  try {
    final result = const TemperamentSearchService().search(message.$2);
    message.$1.send([true, result]);
  } catch (error) {
    message.$1.send([false, error.toString()]);
  }
}

Future<T> _runWorker<T, I>(
  void Function((SendPort, I)) worker,
  I input, {
  Duration timeout = const Duration(seconds: 5),
  required String timeoutMessage,
}) async {
  final receivePort = ReceivePort();
  final isolate = await Isolate.spawn(worker, (
    receivePort.sendPort,
    input,
  ), debugName: 'Temper Calc worker');
  try {
    final message = await receivePort.first.timeout(timeout);
    if (message case [true, final T result]) return result;
    if (message case [false, final Object error]) {
      throw TemperamentException(error.toString());
    }
    throw const TemperamentException(
      'Calculation worker returned invalid data',
    );
  } on TimeoutException {
    throw TemperamentException(timeoutMessage);
  } finally {
    isolate.kill(priority: Isolate.immediate);
    receivePort.close();
  }
}
