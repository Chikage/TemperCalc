import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../domain/app_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.controller, super.key});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final settings = controller.settings;
          final search = settings.searchParameters;
          return ListView(
            key: const ValueKey('settings-list'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionTitle('Display'),
                      _ScaleSetting(
                        key: const ValueKey('setting-display-scale'),
                        value: settings.displayScalePercent,
                        onChanged: (value) => controller.update(
                          settings.copyWith(displayScalePercent: value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _SectionTitle('Search scope'),
                      _IntegerSetting(
                        key: const ValueKey('setting-maximum-dimension'),
                        label: 'Maximum dimension',
                        value: search.maximumDimension,
                        minimum: 2,
                        maximum: 128,
                        onChanged: (value) => controller.update(
                          settings.copyWith(
                            searchParameters: search.copyWith(
                              maximumDimension: value,
                            ),
                          ),
                        ),
                      ),
                      _IntegerSetting(
                        key: const ValueKey('setting-maximum-edo'),
                        label: 'Maximum EDO',
                        value: search.maximumEdo,
                        minimum: 2,
                        maximum: 1000000,
                        onChanged: (value) => controller.update(
                          settings.copyWith(
                            searchParameters: search.copyWith(
                              maximumEdo: value,
                            ),
                          ),
                        ),
                      ),
                      _IntegerSetting(
                        key: const ValueKey('setting-exploration-iterations'),
                        label: 'Exploration rounds',
                        value: search.explorationIterations,
                        minimum: 1,
                        maximum: 1000,
                        onChanged: (value) => controller.update(
                          settings.copyWith(
                            searchParameters: search.copyWith(
                              explorationIterations: value,
                            ),
                          ),
                        ),
                      ),
                      _IntegerSetting(
                        key: const ValueKey('setting-results-per-rank'),
                        label: 'Results per rank',
                        value: search.resultsPerRank,
                        minimum: 1,
                        maximum: 1000,
                        onChanged: (value) => controller.update(
                          settings.copyWith(
                            searchParameters: search.copyWith(
                              resultsPerRank: value,
                            ),
                          ),
                        ),
                      ),
                      _IntegerSetting(
                        key: const ValueKey('setting-search-timeout'),
                        label: 'Timeout (seconds)',
                        value: search.timeoutSeconds,
                        minimum: 1,
                        maximum: 3600,
                        onChanged: (value) => controller.update(
                          settings.copyWith(
                            searchParameters: search.copyWith(
                              timeoutSeconds: value,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _SectionTitle('Decimal places'),
                      _IntegerSetting(
                        key: const ValueKey('setting-tuning-decimals'),
                        label: 'Tuning',
                        value: settings.tuningDecimalPlaces,
                        minimum: 0,
                        maximum: 12,
                        onChanged: (value) => controller.update(
                          settings.copyWith(tuningDecimalPlaces: value),
                        ),
                      ),
                      _IntegerSetting(
                        key: const ValueKey('setting-errors-decimals'),
                        label: 'Errors',
                        value: settings.errorsDecimalPlaces,
                        minimum: 0,
                        maximum: 12,
                        onChanged: (value) => controller.update(
                          settings.copyWith(errorsDecimalPlaces: value),
                        ),
                      ),
                      _IntegerSetting(
                        key: const ValueKey('setting-primes-decimals'),
                        label: 'Primes',
                        value: settings.primesDecimalPlaces,
                        minimum: 0,
                        maximum: 12,
                        onChanged: (value) => controller.update(
                          settings.copyWith(primesDecimalPlaces: value),
                        ),
                      ),
                      _IntegerSetting(
                        key: const ValueKey('setting-badness-decimals'),
                        label: 'Badness',
                        value: settings.badnessDecimalPlaces,
                        minimum: 0,
                        maximum: 12,
                        onChanged: (value) => controller.update(
                          settings.copyWith(badnessDecimalPlaces: value),
                        ),
                      ),
                      _IntegerSetting(
                        key: const ValueKey('setting-complexity-decimals'),
                        label: 'Complexity',
                        value: settings.complexityDecimalPlaces,
                        minimum: 0,
                        maximum: 12,
                        onChanged: (value) => controller.update(
                          settings.copyWith(complexityDecimalPlaces: value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _SectionTitle('Temperament info'),
                      for (final field in TemperamentInfoField.values)
                        SwitchListTile(
                          key: ValueKey('setting-field-${field.name}'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          title: Text(field.label),
                          value: settings.shows(field),
                          onChanged: (visible) {
                            final fields = Set<TemperamentInfoField>.of(
                              settings.visibleTemperamentInfoFields,
                            );
                            visible ? fields.add(field) : fields.remove(field);
                            controller.update(
                              settings.copyWith(
                                visibleTemperamentInfoFields: Set.unmodifiable(
                                  fields,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ScaleSetting extends StatefulWidget {
  const _ScaleSetting({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_ScaleSetting> createState() => _ScaleSettingState();
}

class _ScaleSettingState extends State<_ScaleSetting> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value.toDouble();
  }

  @override
  void didUpdateWidget(_ScaleSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _value = widget.value.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Row(
        children: [
          const Expanded(child: Text('App scale')),
          Text('${_value.round()}%'),
        ],
      ),
      subtitle: Slider(
        key: const ValueKey('display-scale-slider'),
        value: _value,
        min: 60,
        max: 140,
        divisions: 16,
        label: '${_value.round()}%',
        onChanged: (value) => setState(() => _value = value),
        onChangeEnd: (value) => widget.onChanged(value.round()),
      ),
    );
  }
}

class _IntegerSetting extends StatefulWidget {
  const _IntegerSetting({
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int value;
  final int minimum;
  final int maximum;
  final ValueChanged<int> onChanged;

  @override
  State<_IntegerSetting> createState() => _IntegerSettingState();
}

class _IntegerSettingState extends State<_IntegerSetting> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_IntegerSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != '${widget.value}') {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _set(int value) {
    final next = value.clamp(widget.minimum, widget.maximum);
    _controller.text = '$next';
    if (next != widget.value) widget.onChanged(next);
  }

  void _read(String text) {
    final value = int.tryParse(text);
    if (value != null && value >= widget.minimum && value <= widget.maximum) {
      if (value != widget.value) widget.onChanged(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(widget.label),
      trailing: SizedBox(
        width: 152,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Decrease ${widget.label}',
              visualDensity: VisualDensity.compact,
              onPressed: widget.value > widget.minimum
                  ? () => _set(widget.value - 1)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                ),
                onChanged: _read,
                onSubmitted: (text) => _set(int.tryParse(text) ?? widget.value),
                onEditingComplete: () {
                  _set(int.tryParse(_controller.text) ?? widget.value);
                  FocusManager.instance.primaryFocus?.unfocus();
                },
              ),
            ),
            IconButton(
              tooltip: 'Increase ${widget.label}',
              visualDensity: VisualDensity.compact,
              onPressed: widget.value < widget.maximum
                  ? () => _set(widget.value + 1)
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
