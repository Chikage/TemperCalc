import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/domain/models.dart';
import 'package:temper_calc/ui/app_theme.dart';
import 'package:temper_calc/ui/search_page.dart';

void main() {
  testWidgets(
    'labels badness selector and shows comma-separated subgroup hint',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SearchPage(
              active: true,
              onCalculate: (_) async => throw UnimplementedError(),
              onSearch: (_) async => const TemperamentSearchResult(groups: []),
            ),
          ),
        ),
      );

      final subgroupDecoration = tester.widget<InputDecorator>(
        find.descendant(
          of: find.byKey(const ValueKey('search-subgroup')),
          matching: find.byType(InputDecorator),
        ),
      );
      expect(subgroupDecoration.decoration.hintText, '11  or  2,3,5,7');

      final selector = find.byWidgetPredicate(
        (widget) => widget is SegmentedButton<BadnessType>,
      );
      final label = find.text('Badness');
      expect(selector, findsOneWidget);
      expect(label, findsOneWidget);
      expect(
        tester.getRect(label).left,
        lessThan(tester.getRect(selector).left),
      );
      final formRect = tester.getRect(
        find.byKey(const ValueKey('search-subgroup')),
      );
      final subgroupLabelRect = tester.getRect(
        find.text('Prime limit or subgroup'),
      );
      final edosLabelRect = tester.getRect(find.text('List of EDOs'));
      expect(tester.getRect(label).left, closeTo(subgroupLabelRect.left, 0.1));
      expect(tester.getRect(label).left, closeTo(edosLabelRect.left, 0.1));
      expect(tester.getRect(selector).right, closeTo(formRect.right, 1));
      final selectorRect = tester.getRect(
        find.byKey(const ValueKey('badness-selector')),
      );
      final optionsRect = tester.getRect(
        find.byKey(const ValueKey('search-calculation-options')),
      );
      expect(
        selectorRect.center.dy,
        closeTo((formRect.bottom + optionsRect.top) / 2, 0.1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
