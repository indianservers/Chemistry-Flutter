import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';

class ElementData {
  final Map<String, dynamic> data;
  const ElementData(this.data);
  int get number => data['number'] as int;
  String get symbol => data['symbol'] as String;
  String get name => data['name'] as String;
  String get category => data['group'] == 17 && number <= 85
      ? 'halogen'
      : data['category'] as String;
  double get mass => (data['atomic_mass'] as num).toDouble();
  int get column => data['xpos'] as int;
  int get row => data['ypos'] as int;
  String get configuration => data['electron_configuration_semantic'] as String;
  String valueQuality(String key) {
    if (property(key) == null) {
      return 'Unavailable';
    }
    return switch ((data['property_quality'] as Map?)?[key]) {
      'measured' => 'Measured',
      'estimated' => 'Estimated',
      _ => 'Reference · uncertainty unspecified',
    };
  }

  double? property(String key) {
    if (key.startsWith('ionic:')) {
      final charge = int.parse(key.split(':')[1]);
      final values = (data['ionic_radii'] as List?) ?? [];
      for (final row in values) {
        if (row['charge'] == charge &&
            row['coordination'] == 'VI' &&
            (row['spin'] == '' || row['spin'] == 'HS')) {
          return (row['ionic_radius'] as num?)?.toDouble();
        }
      }
      return null;
    }
    if (key == 'ionization') {
      final values = data['ionization_energies'] as List?;
      return values == null || values.isEmpty
          ? null
          : (values.first as num).toDouble();
    }
    if (key == 'radius') {
      final values = (data['atomic_radii'] as Map?)?['empirical'] as List?;
      return values == null || values.isEmpty
          ? null
          : (values.first as num).toDouble();
    }
    final value = data[key];
    return value is num ? value.toDouble() : null;
  }
}

class Atom {
  final int id, number, charge;
  final double x, y, z;
  const Atom(this.id, this.number, this.x, this.y, this.z, [this.charge = 0]);
  Vector3 get position => Vector3(x, y, z);
  Atom copy({int? number, Vector3? position, int? charge}) => Atom(
    id,
    number ?? this.number,
    position?.x ?? x,
    position?.y ?? y,
    position?.z ?? z,
    charge ?? this.charge,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'x': x,
    'y': y,
    'z': z,
    'charge': charge,
  };
  factory Atom.fromJson(Map<String, dynamic> j) => Atom(
    j['id'] as int,
    j['number'] as int,
    (j['x'] as num).toDouble(),
    (j['y'] as num).toDouble(),
    (j['z'] as num).toDouble(),
    (j['charge'] as int?) ?? 0,
  );
}

class Bond {
  final int a, b, order;
  const Bond(this.a, this.b, [this.order = 1]);
  Map<String, dynamic> toJson() => {'a': a, 'b': b, 'order': order};
}

class Molecule {
  final String id, name, source;
  final List<Atom> atoms;
  final List<Bond> bonds;
  final Map<String, dynamic> properties;
  Molecule({
    required this.id,
    required this.name,
    required List<Atom> atoms,
    required List<Bond> bonds,
    this.source = 'User-edited structure',
    Map<String, dynamic> properties = const {},
  }) : atoms = List.unmodifiable(atoms),
       bonds = List.unmodifiable(bonds),
       properties = Map.unmodifiable(properties);
  Molecule copy({
    String? id,
    String? name,
    List<Atom>? atoms,
    List<Bond>? bonds,
  }) => Molecule(
    id: id ?? this.id,
    name: name ?? this.name,
    atoms: atoms ?? this.atoms,
    bonds: bonds ?? this.bonds,
    properties: atoms != null || bonds != null ? const {} : properties,
    source: (atoms != null || bonds != null) && !source.startsWith('Edited')
        ? 'Edited graph / coordinates; original reference: $source'
        : source,
  );
  Atom atom(int id) => atoms.firstWhere((a) => a.id == id);
  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'name': name,
    'source': source,
    'properties': properties,
    'atoms': atoms.map((a) => a.toJson()).toList(),
    'bonds': bonds.map((b) => b.toJson()).toList(),
  };
  factory Molecule.fromJson(Map<String, dynamic> j) {
    final m = Molecule(
      id: j['id'] as String,
      name: j['name'] as String,
      source: j['source'] as String? ?? 'Imported',
      properties: (j['properties'] as Map<String, dynamic>?) ?? const {},
      atoms: (j['atoms'] as List)
          .map((a) => Atom.fromJson(a as Map<String, dynamic>))
          .toList(),
      bonds: (j['bonds'] as List)
          .map((b) => Bond(b['a'] as int, b['b'] as int, b['order'] as int))
          .toList(),
    );
    if (m.atoms.length > 500 ||
        m.atoms.map((a) => a.id).toSet().length != m.atoms.length ||
        m.atoms.any(
          (a) =>
              a.number < 1 ||
              a.number > 118 ||
              !a.x.isFinite ||
              !a.y.isFinite ||
              !a.z.isFinite,
        ) ||
        m.bonds.any(
          (b) =>
              b.a == b.b ||
              !m.atoms.any((a) => a.id == b.a) ||
              !m.atoms.any((a) => a.id == b.b) ||
              b.order < 1 ||
              b.order > 3,
        )) {
      throw const FormatException('Invalid atom coordinates or connectivity');
    }
    final pairs = m.bonds
        .map((b) => '${math.min(b.a, b.b)}:${math.max(b.a, b.b)}')
        .toSet();
    if (pairs.length != m.bonds.length) {
      throw const FormatException('Duplicate bonds');
    }
    return m;
  }
}

class ChemistryData {
  final List<ElementData> elements;
  final List<Molecule> presets;
  final Map<String, dynamic> supplement;
  ChemistryData(this.elements, this.presets, [this.supplement = const {}]);
  List<Map<String, dynamic>> records(String key, int number) =>
      ((supplement[key] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .where((r) => r['atomic_number'] == number)
          .toList();
  ElementData element(int n) => elements.firstWhere((e) => e.number == n);
  static Future<ChemistryData> load() async {
    final supplement = jsonDecode(
      await rootBundle.loadString('assets/datasets/supplement.json'),
    ) as Map<String, dynamic>;
    final e = jsonDecode(
      await rootBundle.loadString('assets/datasets/elements.json'),
    ) as Map<String, dynamic>;
    final m = jsonDecode(
      (await rootBundle.loadString('assets/datasets/molecules.json'))
          .replaceFirst('\ufeff', ''),
    ) as List;
    return ChemistryData(
      (e['elements'] as List).where((e) => (e['number'] as int) <= 118).map((
        e,
      ) {
        final row = e as Map<String, dynamic>;
        row['ionic_radii'] = (supplement['ionic_radii'] as List)
            .where((r) => r['atomic_number'] == row['number'])
            .toList();
        row['oxidation_states'] = (supplement['oxidation_states'] as List)
            .where(
              (r) =>
                  r['atomic_number'] == row['number'] &&
                  r['category'] == 'main',
            )
            .map((r) => r['oxidation_state'])
            .toList();
        return ElementData(row);
      }).toList(),
      m
          .map((m) => Molecule.fromJson(m as Map<String, dynamic>))
          .where((m) => m.atoms.isNotEmpty)
          .toList(),
      supplement,
    );
  }

  String formula(Molecule m) {
    final counts = <String, int>{};
    for (final a in m.atoms) {
      final s = element(a.number).symbol;
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final keys = counts.keys.toList()..sort();
    if (keys.remove('C')) {
      keys.insert(0, 'C');
      if (keys.remove('H')) {
        keys.insert(1, 'H');
      }
    }
    return keys.map((s) => '$s${counts[s] == 1 ? '' : counts[s]}').join();
  }

  double mass(Molecule m) =>
      m.atoms.fold(0, (v, a) => v + element(a.number).mass);
}

double bondLength(Molecule m, Bond b) =>
    m.atom(b.a).position.distanceTo(m.atom(b.b).position);
double angle(Atom a, Atom b, Atom c) {
  final u = a.position - b.position, v = c.position - b.position;
  if (u.length == 0 || v.length == 0) {
    return double.nan;
  }
  return math.acos((u.dot(v) / (u.length * v.length)).clamp(-1, 1)) *
      180 /
      math.pi;
}

double dihedral(Atom a, Atom b, Atom c, Atom d) {
  final axis = c.position - b.position;
  if (axis.length < 1e-10) {
    return double.nan;
  }
  axis.normalize();
  final first = a.position - b.position, last = d.position - c.position;
  final u = first - axis * first.dot(axis), v = last - axis * last.dot(axis);
  if (u.length < 1e-10 || v.length < 1e-10) {
    return double.nan;
  }
  return math.atan2(axis.cross(u).dot(v), u.dot(v)) * 180 / math.pi;
}

List<({String label, double degrees})> torsions(Molecule m) {
  final result = <({String label, double degrees})>[];
  for (final middle in m.bonds) {
    final left = m.bonds
        .where((b) => (b.a == middle.a || b.b == middle.a) && b != middle)
        .map((b) => b.a == middle.a ? b.b : b.a);
    final right = m.bonds
        .where((b) => (b.a == middle.b || b.b == middle.b) && b != middle)
        .map((b) => b.a == middle.b ? b.b : b.a);
    for (final a in left) {
      for (final d in right) {
        if (a == d) {
          continue;
        }
        final degrees = dihedral(
          m.atom(a),
          m.atom(middle.a),
          m.atom(middle.b),
          m.atom(d),
        );
        if (degrees.isFinite) {
          result.add((
            label: '$a–${middle.a}–${middle.b}–$d',
            degrees: degrees,
          ));
        }
      }
    }
  }
  return result;
}

String localGeometry(Atom a, List<Atom> n) {
  if (n.isEmpty) {
    return 'Isolated atom';
  }
  if (n.length == 1) {
    return 'Terminal';
  }
  final angles = <double>[];
  for (var i = 0; i < n.length; i++) {
    for (var j = i + 1; j < n.length; j++) {
      angles.add(angle(n[i], a, n[j]));
    }
  }
  if (n.length == 2) {
    return angles.first > 165 ? 'Linear' : 'Bent';
  }
  if (n.length == 3) {
    return angles.reduce((a, b) => a + b) > 350
        ? 'Trigonal planar'
        : 'Trigonal pyramidal';
  }
  if (n.length == 4 && angles.every((v) => (v - 109.47).abs() < 12)) {
    return 'Tetrahedral';
  }
  if (n.length == 5 &&
      angles.every((v) => [90, 120, 180].any((t) => (v - t).abs() < 12))) {
    return 'Trigonal bipyramidal-like';
  }
  if (n.length == 6 &&
      angles.every((v) => [90, 180].any((t) => (v - t).abs() < 12))) {
    return 'Octahedral-like';
  }
  return '${n.length}-coordinate / distorted';
}

List<String> validate(Molecule m) {
  final warnings = <String>[];
  const typical = {
    1: 1,
    6: 4,
    7: 3,
    8: 2,
    9: 1,
    15: 5,
    16: 6,
    17: 1,
    35: 1,
    53: 1,
  };
  for (final a in m.atoms) {
    final order = m.bonds
        .where((b) => b.a == a.id || b.b == a.id)
        .fold(0, (v, b) => v + b.order);
    final max = (typical[a.number] ?? 8) + a.charge.abs();
    if (order > max) {
      warnings.add(
        'Atom ${a.id}: unusual valence $order; verify charge/connectivity.',
      );
    }
    if (order < (typical[a.number] ?? 0) &&
        a.charge == 0 &&
        [1, 6, 7, 8, 9, 17, 35, 53].contains(a.number)) {
      warnings.add('Atom ${a.id}: incomplete valence; hydrogens are explicit.');
    }
  }
  return warnings;
}

/// Limited harmonic bond relaxation. Not a force field or conformer prediction.
({Molecule molecule, double before, double after}) relaxBonds(
  Molecule m, {
  int iterations = 150,
}) {
  const radii = {
    1: .31,
    6: .76,
    7: .71,
    8: .66,
    9: .57,
    15: 1.07,
    16: 1.05,
    17: 1.02,
    35: 1.20,
    53: 1.39,
  };
  if (m.atoms.isEmpty ||
      m.atoms.any((a) => !radii.containsKey(a.number)) ||
      validate(m).isNotEmpty) {
    throw const FormatException(
      'Bond relaxation requires complete supported valences.',
    );
  }
  double target(Bond b) =>
      (radii[m.atom(b.a).number]! + radii[m.atom(b.b).number]!) *
      (b.order == 1
          ? 1
          : b.order == 2
          ? .88
          : .79);
  double energy(Molecule n) =>
      n.bonds.fold(0, (v, b) => v + math.pow(bondLength(n, b) - target(b), 2));
  var current = m;
  final before = energy(m);
  for (var step = 0; step < iterations; step++) {
    final forces = {for (final a in current.atoms) a.id: Vector3.zero()};
    for (final b in current.bonds) {
      final d = current.atom(b.b).position - current.atom(b.a).position;
      if (d.length < .001) {
        continue;
      }
      final force = d.normalized() * (d.length - target(b)) * .12;
      forces[b.a]!.add(force);
      forces[b.b]!.sub(force);
    }
    current = current.copy(
      atoms: current.atoms
          .map((a) => a.copy(position: a.position + forces[a.id]!))
          .toList(),
    );
  }
  return (molecule: current, before: before, after: energy(current));
}

Future<({Molecule molecule, double before, double after})>
relaxBondsCancellable(
  Molecule original, {
  required bool Function() cancelled,
  required void Function(double) progress,
}) async {
  var current = original;
  double before = 0, after = 0;
  for (var i = 0; i < 15; i++) {
    if (cancelled()) {
      throw const FormatException(
        'Calculation cancelled; original coordinates retained.',
      );
    }
    final result = relaxBonds(current, iterations: 10);
    if (i == 0) {
      before = result.before;
    }
    after = result.after;
    current = result.molecule;
    progress((i + 1) / 15);
    await Future<void>.delayed(Duration.zero);
  }
  if (cancelled()) {
    throw const FormatException(
      'Calculation cancelled; original coordinates retained.',
    );
  }
  return (molecule: current, before: before, after: after);
}
