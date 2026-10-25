import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chemistry.dart';
import 'workspace.dart';

final studioProvider = Provider<StudioStore>(
  (ref) => throw UnimplementedError(),
);

class StudioStore extends ChangeNotifier {
  final ChemistryData data;
  final SharedPreferencesAsync storage;
  late final WorkspacePreferences preferences = WorkspacePreferences(storage);
  Timer? _autosave;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  String _baseline = '';
  final List<String> _undoLabels = [], _redoLabels = [];
  String? autosaveError;
  DateTime? autosavedAt;
  late Molecule molecule;
  int selectedElement = 6, atomType = 6;
  int? selectedAtom;
  int bondOrder = 1;
  final List<Molecule> _undo = [], _redo = [];
  List<Molecule> saved = [];
  String? recoveryNotice;
  StudioStore(this.data, this.storage) {
    molecule = data.presets.firstWhere((m) => m.name == 'Ethanol');
    _baseline = jsonEncode(molecule.toJson());
  }
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get dirty => jsonEncode(molecule.toJson()) != _baseline;
  List<Molecule> get history => List.unmodifiable([..._undo, molecule]);
  List<String> get historyLabels => [
    'Opened ${history.first.name}',
    ..._undoLabels,
  ];
  void _changed() {
    if (!_disposed) {
      notifyListeners();
    }
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 350), () {
      flushDraft();
    });
  }

  Future<void> flushDraft() {
    _autosave?.cancel();
    final snapshot = jsonEncode(molecule.toJson()), baseline = _baseline;
    _writes = _writes.then((_) async {
      try {
        final previous = await storage.getString('draft');
        if (previous != null && previous != snapshot) {
          await storage.setString('draft-backup', previous);
        }
        await storage.setString('draft', snapshot);
        await storage.setString('draft-baseline', baseline);
        autosavedAt = DateTime.now();
        autosaveError = null;
      } catch (e) {
        autosaveError = 'Draft could not be saved: $e';
      }
      if (!_disposed) {
        notifyListeners();
      }
    });
    return _writes;
  }

  Future<void> recoverBackup() async {
    final raw = await storage.getString('draft-backup');
    if (raw != null) {
      edit(
        Molecule.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        label: 'Recover previous draft',
      );
    }
  }

  void open(Molecule m) {
    edit(m, label: 'Open ${m.name}');
    _baseline = jsonEncode(m.toJson());
    preferences.visitMolecule(m.id);
    _changed();
  }

  void restoreHistory(int index) {
    while (_undo.length > index) {
      undo();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _autosave?.cancel();
    preferences.dispose();
    super.dispose();
  }

  Future<void> restore() async {
    await preferences.load();
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
    _baseline =
        await storage.getString('draft-baseline') ??
        jsonEncode(molecule.toJson());
    notifyListeners();
  }

  Future<void> selectElement(int n) async {
    selectedElement = n;
    preferences.visitElement(n);
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

  void edit(Molecule m, {String label = 'Edit structure'}) {
    _undo.add(molecule);
    _undoLabels.add(label);
    _redoLabels.clear();
    _redo.clear();
    molecule = m;
    selectedAtom = null;
    _changed();
  }

  void undo() {
    if (!canUndo) {
      return;
    }
    _redo.add(molecule);
    _redoLabels.add(_undoLabels.removeLast());
    molecule = _undo.removeLast();
    selectedAtom = null;
    _changed();
  }

  void redo() {
    if (!canRedo) {
      return;
    }
    _undo.add(molecule);
    _undoLabels.add(_redoLabels.removeLast());
    molecule = _redo.removeLast();
    selectedAtom = null;
    _changed();
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
      label: 'Add ${data.element(atomType).symbol}',
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
      label: 'Delete atom $id',
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
      label: 'Set bond $a–$b (order $bondOrder)',
    );
  }

  Future<void> save(String name) async {
    _autosave?.cancel();
    final original = molecule;
    await _writes;
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
    if (identical(molecule, original)) {
      molecule = copy;
      _baseline = jsonEncode(copy.toJson());
    }
    await flushDraft();
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
