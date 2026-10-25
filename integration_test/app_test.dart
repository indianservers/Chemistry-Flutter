import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:chemistry_universe/main.dart' as app;
import 'package:chemistry_universe/app/app.dart';
import 'package:chemistry_universe/features/periodic_table.dart';
import 'package:chemistry_universe/features/molecule_studio.dart';
import 'package:chemistry_universe/rendering/molecule_view.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android discovery, editing, persistence and screenshots', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    await shot('01-home');
    await tester.ensureVisible(find.text('Periodic Table'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Periodic Table'));
    await tester.pumpAndSettle();
    expect(find.byType(PeriodicScreen), findsOneWidget);
    await shot('02-periodic-table');
    final periodicViewer = find.byKey(const ValueKey('periodic-viewport'));
    final periodicCamera = tester
        .widget<InteractiveViewer>(periodicViewer)
        .transformationController!;
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    expect(periodicCamera.value.getMaxScaleOnAxis(), greaterThan(1));
    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pan controls'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move left'));
    await tester.pumpAndSettle();
    expect(periodicCamera.value.storage[12], lessThan(0));
    await shot('11-table-pan-controls');
    await tester.tap(find.byTooltip('Pan controls'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fit all elements'));
    await tester.pumpAndSettle();
    expect(periodicCamera.value.getMaxScaleOnAxis(), lessThan(1));
    await shot('12-table-fit-all');
    await tester.tap(find.byTooltip('Focus selected element'));
    await tester.pumpAndSettle();
    await shot('13-table-focus-carbon');
    await tester.tap(find.byTooltip('Reset table view'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search elements'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Carbon');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Carbon'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Details'));
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Atomic number'), findsOneWidget);
    await shot('03-element-details');
    Navigator.of(tester.element(find.text('Atomic number'))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Trends'));
    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Electronegativity'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Electronegativity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Electronegativity'));
    await tester.pumpAndSettle();
    expect(find.textContaining('dark → bright'), findsOneWidget);
    await tester.pumpAndSettle();
    await shot('04-periodic-trends');
    router.go('/molecule');
    await tester.pumpAndSettle();
    expect(find.byType(MoleculeScreen), findsOneWidget);
    await shot('05-ethanol');
    final view = find.byType(MoleculeView);
    await tester.ensureVisible(find.text('Rotate').first);
    await tester.tap(find.text('Rotate').first);
    await tester.pumpAndSettle();
    final initial = tester.widget<MoleculeView>(view).camera.yaw;
    await binding.watchPerformance(() async {
      await tester.timedDragFrom(
        tester.getBottomLeft(view) +
            Offset(tester.getSize(view).width * .55, -20),
        const Offset(60, -10),
        const Duration(milliseconds: 800),
      );
      await tester.pumpAndSettle();
    }, reportKey: 'rotation_performance');
    await tester.pumpAndSettle();
    expect(tester.widget<MoleculeView>(view).camera.yaw, isNot(initial));
    await tester.tap(find.text('Add Atom'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Confirm placement'));
    await tester.pumpAndSettle();
    await shot('06-editing');
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('molecule-inspector-handle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Properties'));
    await tester.pumpAndSettle();
    await shot('07-inspector');
    await tester.tap(find.byTooltip('Molecule library'));
    await tester.pumpAndSettle();
    await shot('08-presets');
    Navigator.of(tester.element(find.text('Molecule Library'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geometry'));
    await tester.pumpAndSettle();
    await shot('09-geometry');
    await tester.tap(find.byTooltip('Molecule actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save molecule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Emulator ethanol');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Saved molecules'));
    await tester.pumpAndSettle();
    expect(find.text('Emulator ethanol'), findsWidgets);
    await shot('10-saved-library');
    await tester.tap(find.widgetWithText(ListTile, 'Emulator ethanol').last);
    await tester.pumpAndSettle();
    router.go('/');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Molecule Studio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Molecule Studio'));
    await tester.pumpAndSettle();
    expect(find.text('Emulator ethanol'), findsWidgets);
  });
}
