import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:chemistry_universe/main.dart' as app;
import 'package:chemistry_universe/app/app.dart';
import 'package:chemistry_universe/core/store.dart';
import 'package:chemistry_universe/features/periodic_table.dart';
import 'package:chemistry_universe/features/molecule_studio.dart';
import 'package:chemistry_universe/rendering/molecule_view.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'enhanced periodic and molecular workspaces operate on real state',
    (tester) async {
      await app.main();
      router.go('/periodic');
      await tester.pumpAndSettle();
      final store = ProviderScope.containerOf(
        tester.element(find.byType(PeriodicScreen)),
        listen: false,
      ).read(studioProvider);
      store.preferences.periodicHints = false;
      store.preferences.moleculeHints = false;
      await store.preferences.persist();
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      Future<void> shot(String name) async {
        await tester.pumpAndSettle();
        await binding.takeScreenshot(name);
      }

      Future<void> tapText(String label) async {
        if (find.text(label).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.text(label),
            180,
            scrollable: find.byType(Scrollable).last,
          );
        }
        await tester.ensureVisible(find.text(label).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
      }

      Future<void> popLabel(String label) async {
        Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byTooltip('Table options'));
      await tester.pumpAndSettle();
      await tapText('Table workspace');
      await tapText('Table minimap');
      await popLabel('Table workspace');
      await tester.tap(find.byTooltip('Favorite element'));
      await tester.pumpAndSettle();
      expect(
        store.preferences.favoriteElements,
        contains(store.selectedElement),
      );
      await shot('01-periodic-minimap-favorites');
      await tester.tap(find.byTooltip('Search elements'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Oxygen');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Oxygen'));
      await tester.pumpAndSettle();
      expect(store.selectedElement, 8);
      await tapText('Use atom');
      await tapText('Use Oxygen in Molecule Studio');
      expect(find.byType(MoleculeScreen), findsOneWidget);
      expect(store.atomType, 8);
      store.open(store.data.presets.firstWhere((m) => m.name == 'Ethanol'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Atom'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MoleculeView>(find.byType(MoleculeView)).ghost,
        isNotNull,
      );
      await shot('02-atom-placement-preview');
      await tester.tap(find.byTooltip('Cancel preview'));
      await tester.pumpAndSettle();
      expect(store.molecule.atoms.length, 9);
      await tester.tap(find.text('Add Atom'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Confirm placement'));
      await tester.pumpAndSettle();
      expect(store.molecule.atoms.length, 10);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(store.molecule.atoms.length, 9);
      final original = store.molecule.atoms.first;
      store.selectAtom(original.id);
      await tester.pumpAndSettle();
      await tapText('Move atom');
      await tester.drag(find.byType(MoleculeView), const Offset(20, 0));
      await tester.pumpAndSettle();
      expect(store.molecule.atom(original.id).x, isNot(original.x));
      await shot('03-constrained-atom-movement');
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      await tapText('Measure');
      var view = tester.widget<MoleculeView>(find.byType(MoleculeView));
      view.onPick!(1);
      await tester.pump();
      view = tester.widget<MoleculeView>(find.byType(MoleculeView));
      view.onPick!(2);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Molecule workspace'));
      await tester.pumpAndSettle();
      await tapText('Pin measurement');
      await popLabel('Molecule workspace');
      expect(
        tester
            .widget<MoleculeView>(find.byType(MoleculeView))
            .measurements
            .length,
        1,
      );
      await shot('04-pinned-measurement');
      await tester.tap(find.byTooltip('Molecule actions'));
      await tester.pumpAndSettle();
      await tapText('Editing history');
      expect(find.text('Open Ethanol'), findsWidgets);
      await shot('05-named-edit-history');
      await popLabel('Editing history');
      await tester.tap(find.byTooltip('Molecule actions'));
      await tester.pumpAndSettle();
      await tapText('Camera bookmarks');
      await tapText('Save current view');
      await tester.enterText(find.byType(TextField), 'Lab view');
      await tapText('Save view');
      expect(store.preferences.cameras.last['name'], 'Lab view');
      await tester.tap(find.byTooltip('Molecule library'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Water');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favorite Water'));
      await tester.pumpAndSettle();
      expect(store.preferences.favoriteMolecules, contains('pubchem-962'));
      await tester.tap(find.byTooltip('Preview Water'));
      await tester.pumpAndSettle();
      await shot('06-preset-structure-preview');
      await tapText('Cancel');
      await popLabel('Molecule Library');
      await tapText('Rotate');
      await tester.tap(find.byTooltip('Molecule workspace'));
      await tester.pumpAndSettle();
      await tapText('Viewing & accessibility');
      final sliders = find.byType(Slider);
      await tester.drag(sliders.first, const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(store.preferences.glow, lessThan(1));
      await tapText('Category patterns');
      await shot('07-viewing-accessibility');
      await popLabel('Viewing & accessibility');
      await popLabel('Molecule workspace');
      await store.flushDraft();
      expect(store.autosaveError, isNull);
      router.go('/periodic');
      await tester.pumpAndSettle();
      expect(store.preferences.periodic['minimap'], isTrue);
      await shot('08-restored-periodic-workspace');
    },
  );
}
