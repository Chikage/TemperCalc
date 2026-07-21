import 'package:flutter/material.dart';

import '../domain/models.dart';

class FormSection extends StatelessWidget {
  const FormSection({
    required this.title,
    this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final stackHeader =
            trailing != null && (constraints.maxWidth < 340 || textScale > 1.5);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stackHeader) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: trailing,
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            if (child case final child?) ...[const SizedBox(height: 10), child],
          ],
        );
      },
    );
  }
}

class CalculationOptions extends StatelessWidget {
  const CalculationOptions({
    required this.reduction,
    required this.weight,
    required this.onReductionChanged,
    required this.onWeightChanged,
    super.key,
  });

  final GeneratorReduction reduction;
  final TuningWeight weight;
  final ValueChanged<GeneratorReduction> onReductionChanged;
  final ValueChanged<TuningWeight> onWeightChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 480;
        final reductionField = DropdownButtonFormField<GeneratorReduction>(
          initialValue: reduction,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Generator reduction'),
          items: [
            for (final value in GeneratorReduction.values)
              DropdownMenuItem(
                value: value,
                child: Text(value.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            if (value != null) onReductionChanged(value);
          },
        );
        final weightField = DropdownButtonFormField<TuningWeight>(
          initialValue: weight,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tuning weight'),
          items: [
            for (final value in TuningWeight.values)
              DropdownMenuItem(
                value: value,
                child: Text(value.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            if (value != null) onWeightChanged(value);
          },
        );

        if (vertical) {
          return Column(
            children: [reductionField, const SizedBox(height: 12), weightField],
          );
        }
        return Row(
          children: [
            Expanded(child: reductionField),
            const SizedBox(width: 12),
            Expanded(child: weightField),
          ],
        );
      },
    );
  }
}

class SubmitButton extends StatelessWidget {
  const SubmitButton({
    required this.loading,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loadingLabel,
    super.key,
  });

  final bool loading;
  final String label;
  final String? loadingLabel;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(loading ? (loadingLabel ?? label) : label),
    );
  }
}
