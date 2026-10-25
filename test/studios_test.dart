import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chemistry_universe/app/app.dart';
import 'package:chemistry_universe/app/design.dart';
import 'package:chemistry_universe/core/chemistry.dart';
import 'package:chemistry_universe/core/store.dart';
import 'package:chemistry_universe/features/periodic_table.dart';
import 'package:chemistry_universe/features/molecule_studio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChemistryData data;
  setUpAll(() async {
    data = await ChemistryData.load();
  });
  Future<StudioStore> mount(
    WidgetTester tester,
    Widget screen,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final s = StudioStore(data, SharedPreferencesAsync());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studioProvider.overrideWithValue(s)],
        child: MaterialApp(theme: universeTheme(), home: screen),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    return s;
  }

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(900, 1200),
  ]) {
    testWidgets('Molecule studio has no overflow at $size', (tester) async {
      await mount(tester, const MoleculeScreen(), size);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Properties'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
    testWidgets('Periodic table has no overflow at $size', (tester) async {
      await mount(tester, const PeriodicScreen(), size);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Search selects element and details open and close', (
    tester,
  ) async {
    final s = await mount(tester, const PeriodicScreen(), const Size(390, 844));
    await tester.tap(find.byTooltip('Search elements'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'Silicon');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Silicon').last);
    await tester.tap(find.text('Silicon').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(s.selectedElement, 14);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Details'));
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Atomic number'), findsOneWidget);
    Navigator.of(tester.element(find.text('Atomic number'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Atomic number'), findsNothing);
  });
  testWidgets('118 tiles fit pannable content including actinides', (
    tester,
  ) async {
    await mount(tester, const PeriodicScreen(), const Size(390, 844));
    final table = find
        .descendant(
          of: find.byType(InteractiveViewer).first,
          matching: find.byType(Stack),
        )
        .first;
    final bounds = tester.getRect(table);
    final tiles = find.descendant(of: table, matching: find.byType(Tooltip));
    expect(tiles, findsNWidgets(118));
    for (final tile in tiles.evaluate()) {
      final rect = tester.getRect(find.byWidget(tile.widget));
      expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
      expect(rect.right, lessThanOrEqualTo(bounds.right));
    }
  });
  testWidgets('Add atom and undo update molecule and mass', (tester) async {
    final s = await mount(tester, const MoleculeScreen(), const Size(390, 844));
    final count = s.molecule.atoms.length;
    await tester.tap(find.text('Add Atom'));
    await tester.pump();
    expect(s.molecule.atoms.length, count + 1);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(s.molecule.atoms.length, count);
    await tester.tap(find.byTooltip('Redo'));
    await tester.pump();
    expect(s.molecule.atoms.length, count + 1);
  });
  testWidgets('Home launches periodic studio', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = StudioStore(data, SharedPreferencesAsync());
    router.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studioProvider.overrideWithValue(s)],
        child: const UniverseApp(),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Periodic Table'));
    await tester.tap(find.text('Periodic Table'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PeriodicScreen), findsOneWidget);
  });
}
