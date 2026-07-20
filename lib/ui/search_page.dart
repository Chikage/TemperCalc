import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'app_callbacks.dart' as callbacks;
import 'form_controls.dart';
import 'result_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    required this.active,
    required this.onCalculate,
    required this.onSearch,
    super.key,
  });

  final bool active;
  final callbacks.CalculateCallback onCalculate;
  final callbacks.SearchCallback onSearch;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _subgroupAnchor = GlobalKey();
  final _subgroup = TextEditingController();
  final _edos = TextEditingController();
  final _commas = TextEditingController();
  final _subgroupFocus = FocusNode();

  BadnessType _badness = BadnessType.cangwu;
  GeneratorReduction _reduction = GeneratorReduction.octave;
  TuningWeight _weight = TuningWeight.weil;
  TemperamentSearchResult? _result;
  SearchInput? _lastInput;
  bool _loading = false;
  SearchCandidate? _openingCandidate;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _subgroup.dispose();
    _edos.dispose();
    _commas.dispose();
    _subgroupFocus.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_loading || _openingCandidate != null) return;
    if (!_formKey.currentState!.validate()) {
      _subgroupFocus.requestFocus();
      final invalidContext = _subgroupAnchor.currentContext;
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
      final input = SearchInput(
        subgroup: _subgroup.text,
        badness: _badness,
        reduction: _reduction,
        weight: _weight,
        edos: _edos.text,
        commas: _commas.text,
      );
      final result = await widget.onSearch(input);
      if (mounted) {
        setState(() {
          _result = result;
          _lastInput = input;
        });
      }
    } catch (error) {
      if (!mounted || !widget.active) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCandidate(SearchCandidate candidate) async {
    if (_loading || _openingCandidate != null) return;
    final searchInput = _lastInput;
    if (searchInput == null) return;
    setState(() => _openingCandidate = candidate);
    try {
      final result = await widget.onCalculate(
        CalculatorInput(
          subgroup: searchInput.subgroup,
          source: candidate.source,
          reduction: searchInput.reduction,
          weight: searchInput.weight,
          edos: candidate.source == CalculationSource.edos
              ? candidate.label
              : '',
          commas: candidate.source == CalculationSource.commas
              ? candidate.label
              : '',
        ),
      );
      if (!mounted || !widget.active) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ResultPage(result: result)),
      );
    } catch (error) {
      if (!mounted || !widget.active) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _openingCandidate = null);
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
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Search temperaments',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      key: _subgroupAnchor,
                      child: TextFormField(
                        key: const ValueKey('search-subgroup'),
                        controller: _subgroup,
                        focusNode: _subgroupFocus,
                        decoration: const InputDecoration(
                          labelText: 'Prime limit or subgroup',
                          hintText: '11  or  2.3.5.7',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Subgroup is required'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<BadnessType>(
                        segments: [
                          for (final value in BadnessType.values)
                            ButtonSegment(
                              value: value,
                              label: Text(value.label),
                            ),
                        ],
                        selected: {_badness},
                        showSelectedIcon: false,
                        onSelectionChanged: (values) =>
                            setState(() => _badness = values.single),
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
                      controller: _edos,
                      decoration: const InputDecoration(
                        labelText: 'List of EDOs',
                        hintText: 'Optional',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _commas,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'List of commas',
                        hintText: 'Optional',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SubmitButton(
                      loading: _loading,
                      label: 'Search',
                      loadingLabel: 'Searching',
                      icon: Icons.manage_search_outlined,
                      onPressed: _openingCandidate == null ? _search : null,
                    ),
                    if (_result case final result?) ...[
                      const SizedBox(height: 28),
                      if (result.warning case final warning?)
                        _Notice(text: warning),
                      for (final group in result.groups)
                        _SearchGroupView(
                          group: group,
                          openingCandidate: _openingCandidate,
                          onOpen: _openCandidate,
                        ),
                    ],
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

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text),
    );
  }
}

class _SearchGroupView extends StatelessWidget {
  const _SearchGroupView({
    required this.group,
    required this.openingCandidate,
    required this.onOpen,
  });

  final SearchGroup group;
  final SearchCandidate? openingCandidate;
  final ValueChanged<SearchCandidate> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Rank ${group.rank}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          for (final candidate in group.candidates) ...[
            _CandidateCard(
              candidate: candidate,
              busy: openingCandidate != null,
              loading: identical(openingCandidate, candidate),
              onTap: () => onOpen(candidate),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.busy,
    required this.loading,
    required this.onTap,
  });

  final SearchCandidate candidate;
  final bool busy;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final familyLabel = candidate.families.isEmpty
        ? ''
        : '. ${candidate.families.join(', ')}';
    final metricLabel =
        '. Badness ${candidate.badness?.toStringAsFixed(3) ?? 'NA'}'
        '. Complexity ${candidate.complexity.toStringAsFixed(1)}';
    return Semantics(
      button: true,
      enabled: !busy,
      excludeSemantics: true,
      label: '${candidate.label}$familyLabel$metricLabel',
      onTap: busy ? null : onTap,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          excludeFromSemantics: true,
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.label,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (candidate.families.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          candidate.families.join(', '),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Badness  ${candidate.badness?.toStringAsFixed(3) ?? 'NA'}'
                        '    Complexity  ${candidate.complexity.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (loading)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
