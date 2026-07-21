import 'package:flutter/material.dart';

import '../data/favorites_store.dart';
import '../domain/app_settings.dart';
import '../domain/favorite.dart';
import '../domain/models.dart';
import 'app_callbacks.dart';
import 'form_controls.dart';
import 'result_page.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({
    required this.active,
    required this.onCalculate,
    this.favorites,
    this.settings = const AppSettings(),
    super.key,
  });

  final bool active;
  final CalculateCallback onCalculate;
  final FavoritesController? favorites;
  final AppSettings settings;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _subgroupAnchor = GlobalKey();
  final _edosAnchor = GlobalKey();
  final _commasAnchor = GlobalKey();
  final _subgroup = TextEditingController();
  final _target = TextEditingController();
  final _edos = TextEditingController();
  final _commas = TextEditingController();
  final _subgroupFocus = FocusNode();
  final _edosFocus = FocusNode();
  final _commasFocus = FocusNode();

  CalculationSource _source = CalculationSource.edos;
  GeneratorReduction _reduction = GeneratorReduction.octave;
  TuningWeight _weight = TuningWeight.weil;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _subgroup.dispose();
    _target.dispose();
    _edos.dispose();
    _commas.dispose();
    _subgroupFocus.dispose();
    _edosFocus.dispose();
    _commasFocus.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) {
      final subgroupInvalid =
          _source == CalculationSource.edos && _subgroup.text.trim().isEmpty;
      final anchor = subgroupInvalid
          ? _subgroupAnchor
          : _source == CalculationSource.edos
          ? _edosAnchor
          : _commasAnchor;
      final focus = subgroupInvalid
          ? _subgroupFocus
          : _source == CalculationSource.edos
          ? _edosFocus
          : _commasFocus;
      focus.requestFocus();
      final invalidContext = anchor.currentContext;
      if (invalidContext != null) {
        await Scrollable.ensureVisible(
          invalidContext,
          alignment: 0.15,
          duration: const Duration(milliseconds: 220),
        );
      }
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    try {
      final input = CalculatorInput(
        subgroup: _subgroup.text,
        source: _source,
        reduction: _reduction,
        weight: _weight,
        edos: _edos.text,
        commas: _commas.text,
        target: _target.text,
      );
      final result = await widget.onCalculate(input);
      if (!mounted || !widget.active) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ResultPage(
            result: result,
            favorites: widget.favorites,
            settings: widget.settings,
            favorite: FavoriteEntry.fromCalculator(
              input: input,
              result: result,
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted || !widget.active) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      top: false,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      key: _subgroupAnchor,
                      child: TextFormField(
                        key: const ValueKey('calculator-subgroup'),
                        controller: _subgroup,
                        focusNode: _subgroupFocus,
                        decoration: const InputDecoration(
                          labelText: 'Prime limit or subgroup',
                          hintText: '11  or  2,3,5,7',
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (_source == CalculationSource.edos &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Required for EDO input';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    CalculationOptions(
                      reduction: _reduction,
                      weight: _weight,
                      onReductionChanged: (value) =>
                          setState(() => _reduction = value),
                      onWeightChanged: (value) =>
                          setState(() => _weight = value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('calculator-target'),
                      controller: _target,
                      decoration: const InputDecoration(
                        labelText: 'Target intervals',
                        hintText: '2/1, 3/2',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    FormSection(
                      title: 'Definition',
                      trailing: SegmentedButton<CalculationSource>(
                        key: const ValueKey('definition-selector'),
                        segments: const [
                          ButtonSegment(
                            value: CalculationSource.edos,
                            icon: Icon(Icons.grid_3x3_outlined),
                            label: Text('EDOs'),
                          ),
                          ButtonSegment(
                            value: CalculationSource.commas,
                            icon: Icon(Icons.data_array_outlined),
                            label: Text('Commas'),
                          ),
                        ],
                        selected: {_source},
                        showSelectedIcon: false,
                        onSelectionChanged: (values) {
                          setState(() => _source = values.single);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _source == CalculationSource.edos
                          ? Container(
                              key: _edosAnchor,
                              child: TextFormField(
                                key: const ValueKey('calculator-edos'),
                                controller: _edos,
                                focusNode: _edosFocus,
                                decoration: const InputDecoration(
                                  labelText: 'List of EDOs',
                                  hintText: '12, 31  or  17c',
                                ),
                                validator: (value) =>
                                    _source == CalculationSource.edos &&
                                        (value == null || value.trim().isEmpty)
                                    ? 'Enter at least one EDO'
                                    : null,
                                onFieldSubmitted: (_) => _calculate(),
                              ),
                            )
                          : Container(
                              key: _commasAnchor,
                              child: TextFormField(
                                key: const ValueKey('calculator-commas'),
                                controller: _commas,
                                focusNode: _commasFocus,
                                minLines: 4,
                                maxLines: 7,
                                decoration: const InputDecoration(
                                  labelText: 'List of commas',
                                  hintText: '81/80, 225/224',
                                  alignLabelWithHint: true,
                                ),
                                validator: (value) =>
                                    _source == CalculationSource.commas &&
                                        (value == null || value.trim().isEmpty)
                                    ? 'Enter at least one comma'
                                    : null,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    SubmitButton(
                      loading: _loading,
                      label: 'Calculate',
                      loadingLabel: 'Calculating',
                      icon: Icons.calculate_outlined,
                      onPressed: _calculate,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
