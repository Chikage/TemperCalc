import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryHeader(
                      rank: result.rank,
                      subgroup: result.subgroup,
                      families: familyText,
                      badness: result.badness,
                    ),
                    _ResultSection(
                      title: 'Comma basis',
                      child: Column(
                        children: [
                          for (final comma in result.commaBasis)
                            _KeyValueLine(
                              leading: '[${comma.vector.join(' ')}]',
                              trailing: comma.ratio,
                            ),
                        ],
                      ),
                    ),
                    _ResultSection(
                      title: result.equalDivisionsLabel,
                      child: SelectableText(
                        result.equalDivisions.join(', '),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          height: 1.6,
                        ),
                      ),
                    ),
                    _ResultSection(
                      title: 'Mapping',
                      child: MatrixView(rows: result.mapping),
                    ),
                    _ResultSection(
                      title: 'Preimage',
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < result.preimage.length; i++)
                            Text(
                              'g${i + 1}  ${result.preimage[i]}',
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                        ],
                      ),
                    ),
                    _ValueTableSection(title: 'Tuning', values: result.tunings),
                    _ValueTableSection(title: 'Errors', values: result.errors),
                    _ValueTableSection(title: 'Primes', values: result.primes),
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

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.rank,
    required this.subgroup,
    required this.families,
    required this.badness,
  });

  final int rank;
  final String subgroup;
  final List<String> families;
  final String badness;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rank $rank', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          SelectableText(
            subgroup,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          if (families.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(families.join(', ')),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Badness',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: SelectableText(
                  badness,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _KeyValueLine extends StatelessWidget {
  const _KeyValueLine({required this.leading, required this.trailing});

  final String leading;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                leading,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: SelectableText(trailing, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _ValueTableSection extends StatelessWidget {
  const _ValueTableSection({required this.title, required this.values});

  final String title;
  final Map<String, List<String>> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return _ResultSection(
      title: title,
      child: Column(
        children: [
          for (final entry in values.entries)
            _KeyValueLine(leading: entry.key, trailing: entry.value.join(', ')),
        ],
      ),
    );
  }
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
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
      ),
    );
  }
}
