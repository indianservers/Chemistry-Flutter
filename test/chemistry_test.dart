import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:chemistry_universe/core/chemistry.dart';
import 'package:chemistry_universe/core/store.dart';
import 'package:chemistry_universe/rendering/molecule_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChemistryData data;
  setUpAll(() async {
    data = await ChemistryData.load();
  });
  test(
    '118 unique, correctly ordered elements and electron configurations',
    () {
      expect(data.elements.length, 118);
      expect(data.elements.map((e) => e.symbol).toSet().length, 118);
      for (var n = 1; n <= 118; n++) {
        final e = data.element(n);
        expect(e.number, n);
        expect(e.configuration, isNotEmpty);
        expect(
          (e.data['shells'] as List).cast<int>().fold(0, (v, n) => v + n),
          n,
        );
        expect(e.column, inInclusiveRange(1, 18));
        expect(e.row, inInclusiveRange(1, 10));
      }
      expect(data.element(6).symbol, 'C');
      expect(data.element(118).symbol, 'Og');
    },
  );
  test('isotopes and charge-specific ionic radii stay sourced', () {
    final carbon13 = data
        .records('isotopes', 6)
        .firstWhere((r) => r['mass_number'] == 13);
    expect(carbon13['is_radioactive'], 0);
    expect(carbon13['mass'], closeTo(13.00335, .00001));
    expect(data.element(11).property('ionic:1'), closeTo(102, .001));
    expect(data.element(6).data['oxidation_states'], contains(4));
    expect(data.records('isotopes', 118), isNotEmpty);
  });
  test(
    'corrupt storage recovers without overwriting original records',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final storage = SharedPreferencesAsync();
      await storage.setString('saved', 'malformed');
      await storage.setString('draft', 'malformed');
      final store = StudioStore(data, storage);
      await store.restore();
      expect(store.molecule.name, 'Ethanol');
      expect(store.recoveryNotice, isNotNull);
      expect(await storage.getString('saved'), 'malformed');
    },
  );
  test('edits invalidate recorded reference properties', () {
    final ethanol = data.presets.firstWhere((m) => m.name == 'Ethanol');
    expect(ethanol.properties['hbd'], 1);
    expect(ethanol.properties['hba'], 1);
    expect(ethanol.copy(name: 'Copy').properties, ethanol.properties);
    expect(ethanol.copy(atoms: ethanol.atoms).properties, isEmpty);
    expect(torsions(ethanol), isNotEmpty);
  });
  test('20 valid offline presets, formulas and masses', () {
    expect(data.presets.length, 20);
    final expected = [
      'H2',
      'H2O',
      'O2',
      'N2',
      'CH4',
      'C2H6',
      'C2H4',
      'C2H2',
      'C2H6O',
      'CH4O',
      'C6H6',
      'CO2',
      'H3N',
      'C2H4O2',
      'C3H6O',
      'C6H12O6',
      'C3H8O3',
      'C3H6O3',
      'C8H10N4O2',
      'C9H8O4',
    ];
    for (var i = 0; i < data.presets.length; i++) {
      expect(
        data.formula(data.presets[i]),
        expected[i],
        reason: data.presets[i].name,
      );
      expect(validate(data.presets[i]), isEmpty, reason: data.presets[i].name);
    }
    expect(
      data.mass(data.presets.firstWhere((m) => m.name == 'Ethanol')),
      closeTo(46.069, .02),
    );
  });
  test('JSON round trip preserves connectivity and formal charges', () {
    final m = data.presets[8];
    final copy = Molecule.fromJson(
      jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>,
    );
    expect(data.formula(copy), data.formula(m));
    expect(copy.toJson(), m.toJson());
    final charged = Molecule(
      id: 'ion',
      name: 'Hydronium',
      atoms: [
        const Atom(1, 8, 0, 0, 0, 1),
        const Atom(2, 1, 1, 0, 0),
        const Atom(3, 1, 0, 1, 0),
        const Atom(4, 1, 0, 0, 1),
      ],
      bonds: [const Bond(1, 2), const Bond(1, 3), const Bond(1, 4)],
    );
    expect(validate(charged), isEmpty);
    expect(Molecule.fromJson(charged.toJson()).atom(1).charge, 1);
  });
  test('malformed connectivity and duplicate bonds rejected', () {
    final j = data.presets[8].toJson();
    j['bonds'] = [
      {'a': 999, 'b': 1, 'order': 1},
    ];
    expect(() => Molecule.fromJson(j), throwsFormatException);
    j['bonds'] = [
      {'a': 1, 'b': 2, 'order': 1},
      {'a': 2, 'b': 1, 'order': 2},
    ];
    expect(() => Molecule.fromJson(j), throwsFormatException);
  });
  test('geometry measurements and real residual minimization', () {
    expect(
      angle(
        const Atom(1, 6, 1, 0, 0),
        const Atom(2, 6, 0, 0, 0),
        const Atom(3, 6, 0, 1, 0),
      ),
      closeTo(90, 1e-8),
    );
    final m = data.presets[8];
    final distorted = m.copy(
      atoms: m.atoms.map((a) => a.copy(position: a.position * 1.25)).toList(),
    );
    final result = relaxBonds(distorted);
    expect(result.after, lessThan(result.before));
    expect(result.molecule.atoms.first.x, isNot(distorted.atoms.first.x));
  });
  test(
    'edit, undo, redo, save, restore and delete modify actual state',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final s = StudioStore(data, SharedPreferencesAsync());
      final original = s.molecule;
      s.selectAtom(original.atoms.first.id);
      s.chooseAtom(8);
      s.addAtom();
      expect(s.molecule.atoms.length, original.atoms.length + 1);
      s.undo();
      expect(s.molecule, original);
      s.redo();
      expect(s.molecule.atoms.length, original.atoms.length + 1);
      await s.save('Experiment');
      final restored = StudioStore(data, SharedPreferencesAsync());
      await restored.restore();
      expect(restored.saved.single.name, 'Experiment');
      expect(restored.molecule.atoms.length, s.molecule.atoms.length);
      await restored.deleteSaved(restored.saved.single.id);
      expect(restored.saved, isEmpty);
    },
  );
  test('camera transforms and projection respond to controls', () {
    final c = CameraState();
    final p = ScenePainter(
      data.presets[8],
      c,
      DisplayMode.ballAndStick,
      null,
      false,
      0,
      false,
    );
    final before = p.rotate(Vector3(1, 0, 0));
    c.yaw += 1;
    expect(p.rotate(Vector3(1, 0, 0)), isNot(before));
    c.zoom = 2;
    c.reset();
    expect(c.zoom, 1);
  });
}
