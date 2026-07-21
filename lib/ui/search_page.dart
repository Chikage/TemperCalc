import 'package:flutter/material.dart';

import '../data/favorites_store.dart';
import '../domain/favorite.dart';
import '../domain/models.dart';
import 'app_callbacks.dart' as callbacks;
import 'form_controls.dart';
import 'result_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    required this.active,
    required this.onCalculate,
    required this.onSearch,
    this.favorites,
    super.key,
  });

  final bool active;
  final callbacks.CalculateCallback onCalculate;
  final callbacks.SearchCallback onSearch;
  final FavoritesController? favorites;

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
        MaterialPageRoute(
          builder: (_) => ResultPage(
            result: result,
            favorites: widget.favorites,
            favorite: FavoriteEntry.fromSearch(
              input: searchInput,
              candidate: candidate,
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
                    Container(
                      key: _subgroupAnchor,
                      child: TextFormField(
                        key: const ValueKey('search-subgroup'),
                        controller: _subgroup,
                        focusNode: _subgroupFocus,
                        decoration: const InputDecoration(
                          labelText: 'Prime limit or subgroup',
                          hintText: '11  or  2,3,5,7',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Subgroup is required'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FormSection(
                      title: 'Badness',
                      trailing: SegmentedButton<BadnessType>(
                        key: const ValueKey('badness-selector'),
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
                      key: const ValueKey('search-calculation-options'),
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
          _SearchResultsTable(
            rank: group.rank,
            candidates: group.candidates,
            openingCandidate: openingCandidate,
            onOpen: onOpen,
          ),
        ],
      ),
    );
  }
}

class _SearchResultsTable extends StatelessWidget {
  const _SearchResultsTable({
    required this.rank,
    required this.candidates,
    required this.openingCandidate,
    required this.onOpen,
  });

  final int rank;
  final List<SearchCandidate> candidates;
  final SearchCandidate? openingCandidate;
  final ValueChanged<SearchCandidate> onOpen;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final divider = BorderSide(color: colorScheme.outlineVariant);
    return Material(
      key: ValueKey('search-results-table-$rank'),
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: divider,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ColoredBox(
            color: colorScheme.surfaceContainerHigh,
            child: _ResultColumns(
              divider: divider,
              result: const _TableHeading('Results'),
              families: const _TableHeading('Families'),
              badness: const _TableHeading('Badness', alignRight: true),
              complexity: const _TableHeading('Complexity', alignRight: true),
            ),
          ),
          for (var index = 0; index < candidates.length; index++)
            _CandidateTableRow(
              candidate: candidates[index],
              busy: openingCandidate != null,
              loading: identical(openingCandidate, candidates[index]),
              showBottomBorder: index != candidates.length - 1,
              divider: divider,
              onTap: () => onOpen(candidates[index]),
            ),
        ],
      ),
    );
  }
}

class _CandidateTableRow extends StatelessWidget {
  const _CandidateTableRow({
    required this.candidate,
    required this.busy,
    required this.loading,
    required this.showBottomBorder,
    required this.divider,
    required this.onTap,
  });

  final SearchCandidate candidate;
  final bool busy;
  final bool loading;
  final bool showBottomBorder;
  final BorderSide divider;
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
      child: InkWell(
        key: ValueKey('search-result-${candidate.rank}-${candidate.label}'),
        excludeFromSemantics: true,
        onTap: busy ? null : onTap,
        child: Ink(
          decoration: showBottomBorder
              ? BoxDecoration(border: Border(bottom: divider))
              : null,
          child: _ResultColumns(
            divider: divider,
            result: Stack(
              fit: StackFit.passthrough,
              children: [
                Tooltip(
                  message: candidate.label,
                  child: Text(
                    candidate.label,
                    softWrap: true,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (loading)
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      child: const SizedBox(
                        width: 20,
                        child: Center(
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            families: Text(
              candidate.families.isEmpty ? '-' : candidate.families.join(', '),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            badness: _MetricText(candidate.badness?.toStringAsFixed(3) ?? 'NA'),
            complexity: _MetricText(candidate.complexity.toStringAsFixed(1)),
          ),
        ),
      ),
    );
  }
}

class _ResultColumns extends StatelessWidget {
  const _ResultColumns({
    required this.result,
    required this.families,
    required this.badness,
    required this.complexity,
    required this.divider,
  });

  final Widget result;
  final Widget families;
  final Widget badness;
  final Widget complexity;
  final BorderSide divider;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 480;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: compact ? 28 : 34,
            child: _ResultCell(divider: divider, child: result),
          ),
          Expanded(
            flex: compact ? 23 : 27,
            child: _ResultCell(divider: divider, child: families),
          ),
          Expanded(
            flex: compact ? 21 : 19,
            child: _ResultCell(divider: divider, child: badness),
          ),
          Expanded(
            flex: compact ? 28 : 20,
            child: _ResultCell(child: complexity),
          ),
        ],
      ),
    );
  }
}

class _ResultCell extends StatelessWidget {
  const _ResultCell({required this.child, this.divider});

  final Widget child;
  final BorderSide? divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: divider == null
          ? null
          : BoxDecoration(border: Border(right: divider!)),
      child: child,
    );
  }
}

class _TableHeading extends StatelessWidget {
  const _TableHeading(this.label, {this.alignRight = false});

  final String label;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MetricText extends StatelessWidget {
  const _MetricText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          value,
          maxLines: 1,
          textAlign: TextAlign.right,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
