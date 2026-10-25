import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:chemistry_universe/app/app.dart';
import 'package:chemistry_universe/core/chemistry.dart';
import 'package:chemistry_universe/core/store.dart';
import 'package:chemistry_universe/core/workspace.dart';
import 'package:chemistry_universe/features/molecule_import.dart';
import 'package:chemistry_universe/rendering/molecule_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChemistryData data;
  setUpAll(() async {
    data = await ChemistryData.load();
  });
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  StudioStore store() {
    final s = StudioStore(data, SharedPreferencesAsync());
    addTearDown(s.dispose);
    return s;
  }

  test(
    'favorites, recent records, appearance, cards and workspace survive reload',
    () async {
      final s = store(), p = s.preferences;
      p.favoriteElement(6);
      p.favoriteElement(14);
      p.favoriteMolecule('pubchem-702');
      p.visitElement(6);
      p.visitElement(14);
      p.visitElement(6);
      p.visitMolecule('pubchem-702');
      p.glow = .3;
      p.textScale = 1.3;
      p.reducedMotion = true;
      p.patterns = true;
      p.largeControls = true;
      p.pinnedProperties = ['mass', 'phase'];
      p.setPeriodic({
        'matrix': [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -80, -40, 0, 1],
        'categories': ['halogen'],
        'inspector': .14,
      });
      p.cameras.add({'name': 'Front', ...CameraState().toJson()});
      await p.persist();
      final restored = WorkspacePreferences(SharedPreferencesAsync());
      await restored.load();
      expect(restored.favoriteElements, {6, 14});
      expect(restored.recentElements, [6, 14]);
      expect(restored.favoriteMolecules, contains('pubchem-702'));
      expect(restored.glow, .3);
      expect(restored.textScale, 1.3);
      expect(restored.reducedMotion, isTrue);
      expect(restored.patterns, isTrue);
      expect(restored.pinnedProperties, ['mass', 'phase']);
      expect(restored.periodic['categories'], ['halogen']);
      expect(restored.cameras.single['name'], 'Front');
      restored.dispose();
    },
  );
  test('named history, dirty state, autosave and recoverable backup preserve graphs', () async {
    final s = store();
    final original = s.molecule;
    expect(s.dirty, isFalse);
    s.edit(original.copy(name: 'Draft one'), label: 'Rename molecule');
    await s.flushDraft();
    expect(s.dirty, isTrue);
    expect(s.historyLabels.last, 'Rename molecule');
    s.edit(s.molecule.copy(name: 'Draft two'), label: 'Second rename');
    await s.flushDraft();
    await s.recoverBackup();
    expect(s.molecule.name, 'Draft one');
    await s.flushDraft();
    final restored = store();
    await restored.restore();
    expect(restored.molecule.name, 'Draft one');
    expect(restored.dirty, isTrue);
    await restored.save('Saved version');
    expect(restored.dirty, isFalse);
    s.restoreHistory(0);
    expect(s.molecule.toJson(), original.toJson());
    expect(s.dirty, isFalse);
  });
  test('cancellable solver reports progress, reduces residual and keeps original intact', () async {
    final original = data.presets.firstWhere((m) => m.name == 'Ethanol');
    final encoded = jsonEncode(original.toJson());
    final progress = <double>[];
    final result = await relaxBondsCancellable(
      original,
      cancelled: () => false,
      progress: progress.add,
    );
    expect(progress.length, 15);
    expect(progress.last, 1);
    expect(result.after, lessThanOrEqualTo(result.before));
    expect(jsonEncode(original.toJson()), encoded);
    double reached = 0;
    await expectLater(
      relaxBondsCancellable(
        original,
        cancelled: () => reached >= .2,
        progress: (v) => reached = v,
      ),
      throwsFormatException,
    );
    expect(reached, closeTo(.2, .001));
    expect(jsonEncode(original.toJson()), encoded);
  });
  test('measurement labels use actual graph coordinates and camera bookmarks round-trip', () {
    final hydrogen = data.presets.firstWhere((m) => m.name == 'Hydrogen');
    expect(SceneMeasurement('Length', [1, 2]).value(hydrogen), '0.741 Å');
    final camera = CameraState()..orient('Side');
    camera.zoom = 2;
    camera.pan = const Offset(12, -8);
    final copy = CameraState()..restore(camera.toJson());
    expect(copy.toJson(), camera.toJson());
    copy.orient('Top');
    expect(copy.pitch, closeTo(1.5708, .001));
    camera.dispose();
    copy.dispose();
  });
  test('property quality never invents measurement certainty', () {
    const reference = ElementData({'atomic_mass': 12.011});
    expect(
      reference.valueQuality('atomic_mass'),
      'Reference · uncertainty unspecified',
    );
    expect(reference.valueQuality('missing'), 'Unavailable');
    const estimated = ElementData({
      'atomic_mass': 12.0,
      'property_quality': {'atomic_mass': 'estimated'},
    });
    expect(estimated.valueQuality('atomic_mass'), 'Estimated');
  });

  Future<StudioStore> mount(
    WidgetTester tester,
    String route, {
    bool large = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = store();
    s.preferences.periodicHints = false;
    s.preferences.moleculeHints = false;
    if (large) {
      s.preferences.textScale = 1.4;
      s.preferences.largeControls = true;
    }
    router.go(route);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studioProvider.overrideWithValue(s)],
        child: const UniverseApp(),
      ),
    );
    await tester.pumpAndSettle();
    return s;
  }

  testWidgets(
    'placement requires confirmation and cancellation preserves the graph',
    (tester) async {
      final s = await mount(tester, '/molecule');
      final before = jsonEncode(s.molecule.toJson());
      await tester.tap(find.text('Add Atom'));
      await tester.pumpAndSettle();
      expect(jsonEncode(s.molecule.toJson()), before);
      expect(
        tester.widget<MoleculeView>(find.byType(MoleculeView)).ghost,
        isNotNull,
      );
      await tester.tap(find.byTooltip('Cancel preview'));
      await tester.pumpAndSettle();
      expect(jsonEncode(s.molecule.toJson()), before);
      await tester.tap(find.text('Add Atom'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Confirm placement'));
      await tester.pumpAndSettle();
      expect(s.molecule.atoms.length, 10);
      await tester.pump(const Duration(milliseconds: 400));
    },
  );
  testWidgets(
    'move mode changes selected coordinates once and undo restores them',
    (tester) async {
      final s = await mount(tester, '/molecule');
      final atom = s.molecule.atoms.first;
      s.selectAtom(atom.id);
      await tester.pump();
      await tester.tap(find.text('Move atom'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(MoleculeView), const Offset(35, -15));
      await tester.pumpAndSettle();
      expect(s.molecule.atom(atom.id).position, isNot(atom.position));
      expect(s.history.length, 2);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(s.molecule.atom(atom.id).position, atom.position);
      await tester.pump(const Duration(milliseconds: 400));
    },
  );
  testWidgets(
    'bond preview preserves graph until confirm and creates selected order',
    (tester) async {
      final s = await mount(tester, '/molecule');
      await tester.ensureVisible(find.text('Connect'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      s.bondOrder = 2;
      tester.widget<MoleculeView>(find.byType(MoleculeView)).onPick!(1);
      await tester.pump();
      tester.widget<MoleculeView>(find.byType(MoleculeView)).onPick!(2);
      await tester.pump();
      expect(
        tester
            .widget<MoleculeView>(find.byType(MoleculeView))
            .previewBond!
            .order,
        2,
      );
      final count = s.molecule.bonds.length;
      await tester.tap(find.byTooltip('Confirm bond'));
      await tester.pumpAndSettle();
      expect(s.molecule.bonds.length, count);
      expect(
        s.molecule.bonds
            .firstWhere((b) => (b.a == 1 && b.b == 2) || (b.a == 2 && b.b == 1))
            .order,
        2,
      );
      await tester.pump(const Duration(milliseconds: 400));
    },
  );
  testWidgets('multiple categories actually de-emphasize other element tiles', (
    tester,
  ) async {
    await mount(tester, '/periodic');
    await tester.tap(find.textContaining('diatomic nonmetal ('));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('alkali metal ('));
    await tester.tap(find.textContaining('alkali metal ('));
    await tester.pumpAndSettle();
    final opacity = tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byKey(const ValueKey('periodic-viewport')),
            matching: find.byType(Opacity),
          ),
        )
        .map((w) => w.opacity)
        .toList();
    expect(opacity.where((v) => v == 1).length, greaterThan(1));
    expect(opacity.where((v) => v < 1).length, greaterThan(1));
  });
  testWidgets(
    'import is reviewed before committing and malformed data is recoverable',
    (tester) async {
      Molecule? imported;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoleculeImportDialog(
              data: data,
              onImport: (m) => imported = m,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'invalid');
      await tester.tap(find.text('Preview structure'));
      await tester.pump();
      expect(find.textContaining('Invalid molecule:'), findsOneWidget);
      expect(imported, isNull);
      await tester.enterText(
        find.byType(TextField),
        jsonEncode(data.presets[8].toJson()),
      );
      await tester.tap(find.text('Preview structure'));
      await tester.pump();
      expect(find.text('Import structure'), findsOneWidget);
      expect(imported, isNull);
    },
  );
  for (final route in ['/periodic', '/molecule']) {
    testWidgets('large text and touch controls remain usable in $route', (
      tester,
    ) async {
      await mount(tester, route, large: true);
      expect(tester.takeException(), isNull);
    });
  }
  for (final route in ['/periodic', '/molecule']) {
    testWidgets('small phone supports large text and controls in $route', (
      tester,
    ) async {
      await mount(tester, route, large: true);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
