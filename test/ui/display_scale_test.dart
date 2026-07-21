import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/data/settings_store.dart';
import 'package:temper_calc/domain/app_settings.dart';
import 'package:temper_calc/main.dart';
import 'package:temper_calc/ui/display_scale.dart';
import 'package:temper_calc/ui/home_shell.dart';

void main() {
  testWidgets('smaller app scale increases layout space and shrinks widgets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Size? mediaSize;
    EdgeInsets? mediaPadding;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          padding: EdgeInsets.only(top: 24),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(
            child: AppDisplayScale(
              percent: 80,
              child: Builder(
                builder: (context) {
                  mediaSize = MediaQuery.sizeOf(context);
                  mediaPadding = MediaQuery.paddingOf(context);
                  return const Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox.square(
                      key: ValueKey('scaled-square'),
                      dimension: 100,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(mediaSize, const Size(500, 1000));
    expect(mediaPadding, const EdgeInsets.only(top: 30));
    final box = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('scaled-square')),
    );
    final topLeft = box.localToGlobal(Offset.zero);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
    expect(bottomRight - topLeft, const Offset(80, 80));
  });

  testWidgets('stored scale applies to the complete application navigator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = SettingsController(
      _MemorySettingsStorage(const AppSettings(displayScalePercent: 80)),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(TemperCalcApp(settingsController: controller));
    await tester.pumpAndSettle();

    final shellContext = tester.element(find.byType(HomeShell));
    expect(MediaQuery.sizeOf(shellContext), const Size(500, 1000));
  });
}

class _MemorySettingsStorage implements SettingsStorage {
  _MemorySettingsStorage(this.value);

  AppSettings value;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async {
    value = settings;
  }
}
