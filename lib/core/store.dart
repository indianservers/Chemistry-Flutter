import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chemistry.dart';

final studioProvider = Provider<StudioStore>(
  (ref) => throw UnimplementedError(),
);

class StudioStore extends ChangeNotifier {
  final ChemistryData data;
  final SharedPreferencesAsync storage;
  late Molecule molecule;
  int selectedElement = 6, atomType = 6;
  int? selectedAtom;
  int bondOrder = 1;
  final List<Molecule> _undo = [], _redo = [];
  List<Molecule> saved = [];
  String? recoveryNotice;
  StudioStore(this.data, this.storage) {
    molecule = data.presets.firstWhere((m) => m.name == 'Ethanol');
  }
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  Future<void> restore() async {
    final text = await storage.getString('saved');
    if (text != null) {
      try {
        final rows = jsonDecode(text) as List;
        for (final row in rows) {
          try {
            saved.add(Molecule.fromJson(row as Map<String, dynamic>));
          } catch (_) {
            recoveryNotice = 'Some saved records could not be read. The original storage has been retained.';
          }
        }
      } catch (_) {
        recoveryNotice = 'Saved library could not be read. The original storage has been retained.';
      }
    }
    selectedElement = (await storage.getInt('element') ?? 6).clamp(1, 118);
    final draft = await storage.getString('draft');
    if (draft != null) {
      try {
        molecule = Molecule.fromJson(jsonDecode(draft) as Map<String, dynamic>);
      } catch (_) {
        recoveryNotice = 'The last saved draft could not be read. Ethanol has been opened instead.';
      }
    }
    notifyListeners();
  }

  Future<void> selectElement(int n) async {
    selectedElement = n;
    notifyListeners();
    await storage.setInt('element', n);
  }

  void selectAtom(int? id) {
    selectedAtom = id;
    notifyListeners();
  }

  void chooseAtom(int n) {
    atomType = n;
    notifyListeners();
  }

  void edit(Molecule m) {
    _undo.add(molecule);
    _redo.clear();
    molecule = m;
    selectedAtom = null;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) {
      return;
    }
    _redo.add(molecule);
    molecule = _undo.removeLast();
    selectedAtom = null;
    notifyListeners();
  }

  void redo() {
    if (!canRedo) {
      return;
    }
    _undo.add(molecule);
    molecule = _redo.removeLast();
    selectedAtom = null;
    notifyListeners();
  }

  void addAtom() {
    final id = molecule.atoms.fold(0, (v, a) => a.id > v ? a.id : v) + 1;
    final parent = selectedAtom;
    final p = parent == null ? null : molecule.atom(parent);
    edit(
      molecule.copy(
        atoms: [
          ...molecule.atoms,
          Atom(id, atomType, (p?.x ?? -1.5) + 1.5, (p?.y ?? 0) + .8, p?.z ?? 0),
        ],
        bonds: [
          ...molecule.bonds,
          if (parent != null) Bond(parent, id, bondOrder),
        ],
      ),
    );
    selectAtom(id);
  }

  void removeSelected() {
    final id = selectedAtom;
    if (id == null) {
      return;
    }
    edit(
      molecule.copy(
        atoms: molecule.atoms.where((a) => a.id != id).toList(),
        bonds: molecule.bonds.where((b) => b.a != id && b.b != id).toList(),
      ),
    );
  }

  void connect(int a, int b) {
    if (a == b) {
      throw const FormatException('Select two distinct atoms');
    }
    edit(
      molecule.copy(
        bonds: [
          ...molecule.bonds.where(
            (bond) =>
                !((bond.a == a && bond.b == b) || (bond.b == a && bond.a == b)),
          ),
          Bond(a, b, bondOrder),
        ],
      ),
    );
  }

  Future<void> save(String name) async {
    final copy = molecule.copy(
      id: 'saved-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
    );
    final next = [...saved, copy];
    await storage.setString(
      'saved',
      jsonEncode(next.map((m) => m.toJson()).toList()),
    );
    await storage.setString('draft', jsonEncode(copy.toJson()));
    saved = next;
    molecule = copy;
    notifyListeners();
  }

  Future<void> deleteSaved(String id) async {
    final next = saved.where((m) => m.id != id).toList();
    await storage.setString(
      'saved',
      jsonEncode(next.map((m) => m.toJson()).toList()),
    );
    saved = next;
    notifyListeners();
  }
}
