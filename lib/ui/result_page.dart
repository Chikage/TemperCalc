import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/link.dart';

import '../domain/models.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({required this.result, super.key});

  final TemperamentInfo result;

  Future<void> _copy(BuildContext context) async {
    final buffer = StringBuffer()
      ..writeln('rank: ${result.rank}')
      ..writeln('subgroup: ${result.subgroup}');
    if (result.families.isNotEmpty || result.weakFamilies.isNotEmpty) {
      buffer.writeln(
        'families: ${[...result.families, ...result.weakFamilies.map((name) => '($name)')].join(', ')}',
      );
    }
    buffer.writeln('comma basis:');
    for (final comma in result.commaBasis) {
      buffer.writeln('[${comma.vector.join(' ')}] ${comma.ratio}');
    }
    buffer
      ..writeln(
        '${result.equalDivisionsLabel}: '
        '${result.equalDivisions.join(', ')}',
      )
      ..writeln('mapping:');
    for (final row in result.mapping) {
      buffer.writeln('[${row.join(', ')}]');
    }
    buffer.writeln('preimage: ${result.preimage.join(', ')}');
    for (final section in [result.tunings, result.errors, result.primes]) {
      for (final entry in section.entries) {
        buffer.writeln('${entry.key}: ${entry.value.join(', ')}');
      }
    }
    buffer.writeln('badness: ${result.badness}');
    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Result copied')));
  }

  @override
  Widget build(BuildContext context) {
    final familyText = [
      ...result.families,
      ...result.weakFamilies.map((name) => '($name)'),
    ];
    final familyValues = [...result.families, ...result.weakFamilies];
    final weakFamilyIndexes = <int>{
      for (
        var index = result.families.length;
        index < familyValues.length;
        index++
      )
        index,
    };
    final rows = <_ResultTableItem>[
      _ResultRow(label: 'rank', value: _TextValue('${result.rank}')),
      _ResultRow(
        label: 'subgroup',
        value: _TextValue(result.subgroup, monospace: true),
      ),
      if (familyText.isNotEmpty)
        _ResultRow(
          label: 'families',
          value: _WikiValue(
            values: familyValues,
            weakIndexes: weakFamilyIndexes,
            familyLinks: true,
          ),
        ),
      _ResultRow(
        label: 'comma basis',
        value: _CommaBasisView(commaBasis: result.commaBasis),
      ),
      _ResultRow(
        label: result.equalDivisionsLabel,
        value: _TextValue(result.equalDivisions.join(', '), monospace: true),
      ),
      _ResultRow(
        label: 'mapping',
        value: MatrixView(rows: result.mapping),
      ),
      _AlignedResultRows(
        rows: [
          _AlignedResultRow(
            label: 'preimage',
            values: result.preimage,
            linkValues: true,
          ),
          for (final entry in result.tunings.entries)
            _AlignedResultRow(label: entry.key, values: entry.value),
        ],
      ),
      ..._valueRows(result.errors),
      ..._valueRows(result.primes),
      _ResultRow(
        label: 'badness',
        value: _TextValue(result.badness, monospace: true),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Temperament info'),
        actions: [
          IconButton(
            tooltip: 'Copy result',
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _ResultTable(rows: rows),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ResultRow> _valueRows(Map<String, List<String>> values) => [
    for (final entry in values.entries)
      _ResultRow(
        label: entry.key,
        value: _TextValue(entry.value.join(', '), monospace: true),
      ),
  ];
}

class _ResultTable extends StatelessWidget {
  const _ResultTable({required this.rows});

  final List<_ResultTableItem> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidth = (constraints.maxWidth * 0.39)
              .clamp(112.0, 248.0)
              .toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final row in rows)
                switch (row) {
                  _ResultRow() => _ResultRowLayout(
                    row: row,
                    labelWidth: labelWidth,
                  ),
                  _AlignedResultRows() => _AlignedResultRowsLayout(
                    rows: row.rows,
                    labelWidth: labelWidth,
                  ),
                },
            ],
          );
        },
      ),
    );
  }
}

sealed class _ResultTableItem {
  const _ResultTableItem();
}

class _ResultRow extends _ResultTableItem {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final Widget value;
}

class _AlignedResultRows extends _ResultTableItem {
  const _AlignedResultRows({required this.rows});

  final List<_AlignedResultRow> rows;
}

class _AlignedResultRow {
  const _AlignedResultRow({
    required this.label,
    required this.values,
    this.linkValues = false,
  });

  final String label;
  final List<String> values;
  final bool linkValues;
}

class _ResultRowLayout extends StatelessWidget {
  const _ResultRowLayout({required this.row, required this.labelWidth});

  final _ResultRow row;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              row.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: row.value),
        ],
      ),
    );
  }
}

class _AlignedResultRowsLayout extends StatelessWidget {
  const _AlignedResultRowsLayout({
    required this.rows,
    required this.labelWidth,
  });

  static const _rowHeight = 52.0;

  final List<_AlignedResultRow> rows;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final valueColumnCount = rows.fold<int>(
      0,
      (count, row) => row.values.length > count ? row.values.length : count,
    );
    final columnCount = valueColumnCount == 0 ? 1 : valueColumnCount;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Column(
            children: [
              for (final row in rows)
                SizedBox(
                  height: _rowHeight,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        row.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              children: [
                for (final row in rows)
                  TableRow(
                    children: [
                      for (var column = 0; column < columnCount; column++)
                        SizedBox(
                          key: ValueKey('aligned-value-${row.label}-$column'),
                          height: _rowHeight,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: 14,
                                right: column < columnCount - 1 ? 16 : 0,
                              ),
                              child: _AlignedResultValue(
                                value: column < row.values.length
                                    ? row.values[column]
                                    : null,
                                linked: row.linkValues,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AlignedResultValue extends StatelessWidget {
  const _AlignedResultValue({required this.value, required this.linked});

  final String? value;
  final bool linked;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    const style = TextStyle(fontFamily: 'monospace', height: 1.45);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (linked)
          _WikiLink(label: value!, monospace: true)
        else
          SelectableText(value!, style: style),
      ],
    );
  }
}

class _TextValue extends StatelessWidget {
  const _TextValue(this.value, {this.monospace = false});

  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      value,
      style: TextStyle(
        fontFamily: monospace ? 'monospace' : null,
        height: 1.45,
      ),
    );
  }
}

class _WikiValue extends StatelessWidget {
  const _WikiValue({
    required this.values,
    this.weakIndexes = const <int>{},
    this.familyLinks = false,
  });

  final List<String> values;
  final Set<int> weakIndexes;
  final bool familyLinks;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    const style = TextStyle(height: 1.45);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var index = 0; index < values.length; index++) ...[
          if (index > 0) Text(', ', style: style),
          if (weakIndexes.contains(index)) Text('(', style: style),
          _WikiLink(
            label: values[index],
            wikiTitle: familyLinks ? '${values[index]} family' : null,
          ),
          if (weakIndexes.contains(index)) Text(')', style: style),
        ],
      ],
    );
  }
}

class _WikiLink extends StatelessWidget {
  const _WikiLink({
    required this.label,
    this.wikiTitle,
    this.monospace = false,
  });

  final String label;
  final String? wikiTitle;
  final bool monospace;

  Uri get _uri => Uri.https('en.xen.wiki', '/w/${wikiTitle ?? label}');

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontFamily: monospace ? 'monospace' : null,
      height: 1.45,
    );
    return Link(
      uri: _uri,
      builder: (context, followLink) => Semantics(
        link: followLink != null,
        label: label,
        child: InkWell(
          onTap: followLink == null ? null : () => followLink(),
          child: Text(label, style: style),
        ),
      ),
    );
  }
}

class _CommaBasisView extends StatelessWidget {
  const _CommaBasisView({required this.commaBasis});

  final List<CommaInfo> commaBasis;

  @override
  Widget build(BuildContext context) {
    if (commaBasis.isEmpty) return const SizedBox.shrink();
    final vectors = formatCommaBasisVectors(commaBasis);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < commaBasis.length; index++) ...[
            SelectableText(
              vectors[index],
              key: ValueKey('comma-vector-$index'),
              style: const TextStyle(fontFamily: 'monospace', height: 1.45),
            ),
            _WikiLink(label: commaBasis[index].ratio, monospace: true),
            if (index < commaBasis.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Formats every comma vector with the same width for each exponent column.
/// Padding is calculated across all rows so both brackets occupy the same
/// character columns even when a row contains a negative or multi-digit value.
List<String> formatCommaBasisVectors(List<CommaInfo> commaBasis) {
  if (commaBasis.isEmpty) return const [];
  final columnCount = commaBasis.fold<int>(
    0,
    (count, comma) => comma.vector.length > count ? comma.vector.length : count,
  );
  final widths = List<int>.filled(columnCount, 1);
  for (final comma in commaBasis) {
    for (var column = 0; column < comma.vector.length; column++) {
      final width = comma.vector[column].toString().length;
      if (width > widths[column]) widths[column] = width;
    }
  }
  return [
    for (final comma in commaBasis)
      '[ ${_formatCommaVector(comma.vector, widths)} ]',
  ];
}

String _formatCommaVector(List<int> vector, List<int> widths) {
  return List<String>.generate(
    widths.length,
    (column) => column < vector.length
        ? vector[column].toString().padLeft(widths[column])
        : ''.padLeft(widths[column]),
  ).join('  ');
}

class MatrixView extends StatelessWidget {
  const MatrixView({required this.rows, super.key});

  final List<List<int>> rows;

  @override
  Widget build(BuildContext context) {
    final widest = rows
        .expand((row) => row)
        .fold<int>(
          1,
          (width, value) =>
              value.toString().length > width ? value.toString().length : width,
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SelectableText(
        rows
            .map(
              (row) => row
                  .map((value) => value.toString().padLeft(widest))
                  .join('  '),
            )
            .join('\n'),
        style: const TextStyle(fontFamily: 'monospace', height: 1.55),
      ),
    );
  }
}
