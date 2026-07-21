import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/link.dart';

import '../data/favorites_store.dart';
import '../domain/app_settings.dart';
import '../domain/favorite.dart';
import '../domain/models.dart';

class ResultPage extends StatefulWidget {
  const ResultPage({
    required TemperamentInfo result,
    this.favorite,
    this.favorites,
    this.settings = const AppSettings(),
    super.key,
  }) : _initialResult = result,
       _resultLoader = null,
       favoriteBuilder = null;

  const ResultPage.loading({
    required Future<TemperamentInfo> Function() loadResult,
    this.favoriteBuilder,
    this.favorites,
    this.settings = const AppSettings(),
    super.key,
  }) : _initialResult = null,
       favorite = null,
       _resultLoader = loadResult;

  final TemperamentInfo? _initialResult;
  final FavoriteEntry? favorite;
  final FavoritesController? favorites;
  final AppSettings settings;
  final Future<TemperamentInfo> Function()? _resultLoader;
  final FavoriteEntry Function(TemperamentInfo result)? favoriteBuilder;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool _savingFavorite = false;
  TemperamentInfo? _loadedResult;
  FavoriteEntry? _loadedFavorite;
  Object? _loadError;

  TemperamentInfo get result => widget._initialResult ?? _loadedResult!;

  FavoriteEntry? get favorite => widget.favorite ?? _loadedFavorite;

  @override
  void initState() {
    super.initState();
    if (widget._resultLoader != null) _loadResult();
  }

  Future<void> _loadResult() async {
    if (_loadError != null) setState(() => _loadError = null);
    try {
      final result = await widget._resultLoader!();
      final favorite = widget.favoriteBuilder?.call(result);
      if (!mounted) return;
      setState(() {
        _loadedResult = result;
        _loadedFavorite = favorite;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  bool _shows(TemperamentInfoField field) => widget.settings.shows(field);

  String _formatDecimal(String value, int decimalPlaces) =>
      double.tryParse(value)?.toStringAsFixed(decimalPlaces) ?? value;

  bool _showsMetric(String label, TemperamentInfoField field) {
    final normalized = label.toLowerCase();
    final resolved = switch (field) {
      TemperamentInfoField.tunings when normalized.startsWith('c') =>
        TemperamentInfoField.constrainedTunings,
      TemperamentInfoField.errors when normalized.startsWith('target ') =>
        TemperamentInfoField.targetErrors,
      TemperamentInfoField.errors when normalized.startsWith('c') =>
        TemperamentInfoField.constrainedErrors,
      TemperamentInfoField.primes when normalized.startsWith('target ') =>
        TemperamentInfoField.targetPrimes,
      TemperamentInfoField.primes when normalized.startsWith('c') =>
        TemperamentInfoField.constrainedPrimes,
      _ => field,
    };
    return _shows(resolved);
  }

  Future<void> _copy(BuildContext context) async {
    final buffer = StringBuffer();
    if (_shows(TemperamentInfoField.rank)) {
      buffer.writeln('rank: ${result.rank}');
    }
    if (_shows(TemperamentInfoField.subgroup)) {
      buffer.writeln('subgroup: ${result.subgroup}');
    }
    if (_shows(TemperamentInfoField.families) &&
        (result.families.isNotEmpty || result.weakFamilies.isNotEmpty)) {
      buffer.writeln(
        'families: ${[...result.families, ...result.weakFamilies.map((name) => '($name)')].join(', ')}',
      );
    }
    if (_shows(TemperamentInfoField.commaBasis)) {
      buffer.writeln('comma basis:');
      for (final comma in result.commaBasis) {
        buffer.writeln('[${comma.vector.join(' ')}] ${comma.ratio}');
      }
    }
    if (_shows(TemperamentInfoField.equalDivisions)) {
      buffer.writeln(
        '${result.equalDivisionsLabel}: '
        '${result.equalDivisions.join(', ')}',
      );
    }
    if (_shows(TemperamentInfoField.equalDivisionJoin) &&
        result.equalDivisionJoinLabel != null &&
        result.equalDivisionJoin != null) {
      buffer.writeln(
        '${result.equalDivisionJoinLabel}: ${result.equalDivisionJoin}',
      );
    }
    if (_shows(TemperamentInfoField.mapping)) {
      buffer.writeln('mapping:');
      if (result.mapping.isNotEmpty) {
        buffer.writeln(formatMatrixText(result.mapping));
      }
    }
    for (var index = 0; index < result.preimage.length; index++) {
      if (_shows(TemperamentInfoField.preimage)) {
        buffer.writeln(
          '${_indexedLabel('preimage', index, result.preimage.length)}: '
          '${result.preimage[index]}',
        );
      }
      for (final entry in result.tunings.entries) {
        if (_showsMetric(entry.key, TemperamentInfoField.tunings) &&
            index < entry.value.length) {
          buffer.writeln(
            '${_indexedLabel(entry.key, index, result.preimage.length)}: '
            '${_formatDecimal(entry.value[index], widget.settings.tuningDecimalPlaces)}',
          );
        }
      }
    }
    for (final entry in result.errors.entries) {
      if (_showsMetric(entry.key, TemperamentInfoField.errors)) {
        buffer.writeln('${entry.key}:');
        for (final value in entry.value) {
          buffer.writeln(
            _formatDecimal(value, widget.settings.errorsDecimalPlaces),
          );
        }
      }
    }
    for (final entry in result.primes.entries) {
      if (_showsMetric(entry.key, TemperamentInfoField.primes)) {
        buffer.writeln('${entry.key}:');
        for (final value in entry.value) {
          buffer.writeln(
            _formatDecimal(value, widget.settings.primesDecimalPlaces),
          );
        }
      }
    }
    if (_shows(TemperamentInfoField.badness)) {
      buffer.writeln(
        'badness: ${_formatDecimal(result.badness, widget.settings.badnessDecimalPlaces)}',
      );
    }
    if (_shows(TemperamentInfoField.complexity)) {
      buffer.writeln('complexity: ${result.complexity}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Result copied')));
  }

  Future<void> _toggleFavorite() async {
    final favorite = this.favorite;
    final favorites = widget.favorites;
    if (favorite == null || favorites == null || _savingFavorite) return;
    setState(() => _savingFavorite = true);
    try {
      final added = await favorites.toggle(favorite);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added ? 'Saved to favorites' : 'Removed from favorites',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update favorites: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingFavorite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget._initialResult == null && _loadedResult == null) {
      return _LoadingResultScaffold(error: _loadError, onRetry: _loadResult);
    }

    final favorite = this.favorite;
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
    final rows = <_ResultRow>[
      if (_shows(TemperamentInfoField.rank))
        _ResultRow(label: 'rank', value: _TextValue('${result.rank}')),
      if (_shows(TemperamentInfoField.subgroup))
        _ResultRow(
          label: 'subgroup',
          value: _TextValue(result.subgroup, monospace: true),
        ),
      if (_shows(TemperamentInfoField.families) && familyText.isNotEmpty)
        _ResultRow(
          label: 'families',
          value: _WikiValue(
            values: familyValues,
            weakIndexes: weakFamilyIndexes,
            familyLinks: true,
          ),
        ),
      if (_shows(TemperamentInfoField.commaBasis))
        _ResultRow(
          label: 'comma basis',
          value: _CommaBasisView(commaBasis: result.commaBasis),
        ),
      if (_shows(TemperamentInfoField.equalDivisions))
        _ResultRow(
          label: result.equalDivisionsLabel,
          value: _TextValue(result.equalDivisions.join(', '), monospace: true),
        ),
      if (_shows(TemperamentInfoField.equalDivisionJoin) &&
          result.equalDivisionJoinLabel != null &&
          result.equalDivisionJoin != null)
        _ResultRow(
          label: result.equalDivisionJoinLabel!,
          value: _TextValue(result.equalDivisionJoin!, monospace: true),
        ),
      if (_shows(TemperamentInfoField.mapping))
        _ResultRow(
          label: 'mapping',
          value: MatrixView(rows: result.mapping),
        ),
      ..._preimageTuningRows(),
      ..._valueRows(
        result.errors,
        widget.settings.errorsDecimalPlaces,
        TemperamentInfoField.errors,
      ),
      ..._valueRows(
        result.primes,
        widget.settings.primesDecimalPlaces,
        TemperamentInfoField.primes,
      ),
      if (_shows(TemperamentInfoField.badness))
        _ResultRow(
          label: 'badness',
          value: _TextValue(
            _formatDecimal(
              result.badness,
              widget.settings.badnessDecimalPlaces,
            ),
            monospace: true,
          ),
        ),
      if (_shows(TemperamentInfoField.complexity))
        _ResultRow(
          label: 'complexity',
          value: _TextValue(result.complexity, monospace: true),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Temperament info'),
        actions: [
          if (favorite != null && widget.favorites != null)
            AnimatedBuilder(
              animation: widget.favorites!,
              builder: (context, _) {
                final saved = widget.favorites!.contains(favorite.id);
                return IconButton(
                  key: const ValueKey('favorite-result'),
                  tooltip: saved ? 'Remove from favorites' : 'Add to favorites',
                  onPressed: _savingFavorite ? null : _toggleFavorite,
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_outline),
                );
              },
            ),
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

  List<_ResultRow> _valueRows(
    Map<String, List<String>> values,
    int decimalPlaces,
    TemperamentInfoField field,
  ) => [
    for (final entry in values.entries)
      if (_showsMetric(entry.key, field))
        _ResultRow(
          label: entry.key,
          value: _TextValue(
            entry.value
                .map((value) => _formatDecimal(value, decimalPlaces))
                .join('\n'),
            monospace: true,
          ),
        ),
  ];

  List<_ResultRow> _preimageTuningRows() {
    final rows = <_ResultRow>[];
    for (var index = 0; index < result.preimage.length; index++) {
      if (_shows(TemperamentInfoField.preimage)) {
        rows.add(
          _ResultRow(
            label: _indexedLabel('preimage', index, result.preimage.length),
            value: _WikiLink(label: result.preimage[index], monospace: true),
          ),
        );
      }
      for (final entry in result.tunings.entries) {
        if (!_showsMetric(entry.key, TemperamentInfoField.tunings) ||
            index >= entry.value.length) {
          continue;
        }
        rows.add(
          _ResultRow(
            label: _indexedLabel(entry.key, index, result.preimage.length),
            value: _TextValue(
              _formatDecimal(
                entry.value[index],
                widget.settings.tuningDecimalPlaces,
              ),
              monospace: true,
            ),
          ),
        );
      }
    }
    return rows;
  }
}

class _LoadingResultScaffold extends StatelessWidget {
  const _LoadingResultScaffold({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temperament info')),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: error == null
                ? const Column(
                    key: ValueKey('temperament-info-loading'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      SizedBox(height: 14),
                      Text('Loading'),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 32,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load temperament info',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

String _indexedLabel(String label, int index, int itemCount) =>
    itemCount == 1 ? label : '$label $index';

class _ResultTable extends StatelessWidget {
  const _ResultTable({required this.rows});

  final List<_ResultRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(6),
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
                _ResultRowLayout(row: row, labelWidth: labelWidth),
            ],
          );
        },
      ),
    );
  }
}

class _ResultRow {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final Widget value;
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
    if (rows.isEmpty) return const SizedBox.shrink();
    final values = _formatMatrixValueRows(rows).join('\n');
    const style = TextStyle(fontFamily: 'monospace', height: 1.55);
    final textPainter = TextPainter(
      text: TextSpan(text: values, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final bracketHeight = textPainter.height < 18.0 ? 18.0 : textPainter.height;
    final bracketColor = Theme.of(context).colorScheme.onSurface;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        height: bracketHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomPaint(
              key: const ValueKey('mapping-left-bracket'),
              size: Size(8, bracketHeight),
              painter: _MatrixBracketPainter(color: bracketColor, left: true),
            ),
            const SizedBox(width: 6),
            SelectableText(
              values,
              key: const ValueKey('mapping-values'),
              style: style,
            ),
            const SizedBox(width: 6),
            CustomPaint(
              key: const ValueKey('mapping-right-bracket'),
              size: Size(8, bracketHeight),
              painter: _MatrixBracketPainter(color: bracketColor, left: false),
            ),
          ],
        ),
      ),
    );
  }
}

String formatMatrixText(List<List<int>> rows) {
  final values = _formatMatrixValueRows(rows);
  if (values.isEmpty) return '';
  if (values.length == 1) return '[ ${values.single} ]';
  return [
    '[ ${values.first}',
    for (final value in values.skip(1).take(values.length - 2)) '  $value',
    '  ${values.last} ]',
  ].join('\n');
}

List<String> _formatMatrixValueRows(List<List<int>> rows) {
  if (rows.isEmpty) return const [];
  final columnCount = rows.fold<int>(
    0,
    (count, row) => row.length > count ? row.length : count,
  );
  final widths = List<int>.filled(columnCount, 1);
  for (final row in rows) {
    for (var column = 0; column < row.length; column++) {
      final width = row[column].toString().length;
      if (width > widths[column]) widths[column] = width;
    }
  }
  return [
    for (final row in rows)
      List<String>.generate(
        columnCount,
        (column) => column < row.length
            ? row[column].toString().padLeft(widths[column])
            : ''.padLeft(widths[column]),
      ).join('  '),
  ];
}

class _MatrixBracketPainter extends CustomPainter {
  const _MatrixBracketPainter({required this.color, required this.left});

  final Color color;
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final vertical = left ? 0.75 : size.width - 0.75;
    final inward = left ? size.width : 0.0;
    final path = Path()
      ..moveTo(inward, 0.75)
      ..lineTo(vertical, 0.75)
      ..lineTo(vertical, size.height - 0.75)
      ..lineTo(inward, size.height - 0.75);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_MatrixBracketPainter oldDelegate) =>
      color != oldDelegate.color || left != oldDelegate.left;
}
