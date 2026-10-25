import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../app/design.dart';
import '../core/chemistry.dart';
import '../core/store.dart';
import '../rendering/molecule_view.dart';

class MoleculeScreen extends ConsumerStatefulWidget {
  const MoleculeScreen({super.key});
  @override
  ConsumerState<MoleculeScreen> createState() => _MoleculeState();
}

class _MoleculeState extends ConsumerState<MoleculeScreen> {
  final camera = CameraState();
  int toolbar = 0, inspector = 0;
  bool expanded = false, labels = false, vibration = false, connecting = false;
  double amplitude = .1, speed = 1;
  DisplayMode mode = DisplayMode.ballAndStick;
  @override
  void dispose() {
    camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(studioProvider);
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  StudioHeader(
                    'Molecule Studio',
                    'Build. Optimize. Understand.',
                    actions: [
                      IconButton(
                        tooltip: 'Molecule library',
                        icon: const Icon(Icons.search),
                        onPressed: () => _library(s),
                      ),
                      IconButton(
                        tooltip: 'Help',
                        icon: const Icon(Icons.help_outline),
                        onPressed: () => message(
                          context,
                          'Your molecular workspace',
                          'Drag the model to rotate. Pinch to zoom and pan with two fingers. Double tap to reset. Tap an atom to select it, then Add Atom to attach the chosen element. Add Bond enters a two-atom connection mode. Hydrogens are explicit: edits can leave incomplete valences, shown in the inspector.\n\nMeshes use perspective software rendering. Bond relaxation is a limited harmonic model, not molecular mechanics.',
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<int>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(value: 0, label: Text('Atoms')),
                              ButtonSegment(value: 1, label: Text('Bonds')),
                              ButtonSegment(value: 2, label: Text('Presets')),
                            ],
                            selected: {toolbar},
                            onSelectionChanged: (v) {
                              setState(() => toolbar = v.first);
                              if (v.first == 2) {
                                _library(s);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Saved molecules',
                          onPressed: () => _library(s, savedOnly: true),
                          icon: const Icon(Icons.folder_open),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Molecule actions',
                          onSelected: (v) => _action(v, s),
                          itemBuilder: (_) => [
                            for (final item in [
                              ('save', 'Save molecule'),
                              ('rename', 'Rename molecule'),
                              ('blank', 'New blank molecule'),
                              ('duplicate', 'Duplicate molecule'),
                              ('export', 'Export JSON'),
                              ('mol', 'Export MOL'),
                              ('import', 'Import JSON'),
                              ('labels', 'Toggle atom labels'),
                              ('mode', 'Change display mode'),
                            ])
                              PopupMenuItem(
                                value: item.$1,
                                child: Text(item.$2),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 72,
                    child: toolbar == 1
                        ? _bondToolbar(s)
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                for (final n in [
                                  6,
                                  1,
                                  8,
                                  7,
                                  17,
                                  9,
                                  15,
                                  16,
                                  35,
                                  53,
                                  ...([
                                        6,
                                        1,
                                        8,
                                        7,
                                        17,
                                        9,
                                        15,
                                        16,
                                        35,
                                        53,
                                      ].contains(s.atomType)
                                      ? <int>[]
                                      : [s.atomType]),
                                ])
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: InkWell(
                                      onTap: () => s.chooseAtom(n),
                                      child: SizedBox(
                                        width: 72,
                                        child: Panel(
                                          active: s.atomType == n,
                                          padding: const EdgeInsets.all(4),
                                          child: Column(
                                            children: [
                                              Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: RadialGradient(
                                                    center: const Alignment(
                                                      -.4,
                                                      -.5,
                                                    ),
                                                    colors: [
                                                      Color.lerp(
                                                        atomColor(n),
                                                        Colors.white,
                                                        .55,
                                                      )!,
                                                      atomColor(n),
                                                      Colors.black,
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                s.data.element(n).symbol,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                s.data.element(n).name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: MoleculeView(
                              molecule: s.molecule,
                              atomLabels: {
                                for (final a in s.molecule.atoms)
                                  a.id: s.data.element(a.number).symbol,
                              },
                              camera: camera,
                              selected: s.selectedAtom,
                              mode: mode,
                              labels: labels,
                              vibration: vibration,
                              amplitude: amplitude,
                              speed: speed,
                              onPick: (id) {
                                if (connecting &&
                                    s.selectedAtom != null &&
                                    id != null) {
                                  if (s.selectedAtom == id) {
                                    s.selectAtom(null);
                                    return;
                                  }
                                  s.connect(s.selectedAtom!, id);
                                  setState(() => connecting = false);
                                } else {
                                  s.selectAtom(id);
                                }
                              },
                              onBond: (b) => _bondDetails(s, b),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 18,
                          child: Text(
                            connecting
                                ? 'Select two atoms to connect'
                                : s.selectedAtom == null
                                ? 'Drag to rotate · Pinch to zoom'
                                : '${s.data.element(s.molecule.atom(s.selectedAtom!).number).name} · Atom ${s.selectedAtom}',
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 30,
                          bottom: 38,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _cameraTool(Icons.rotate_right, 'Rotate', () {
                                  setState(() => connecting = false);
                                }),
                                _cameraTool(Icons.add, 'Zoom in', () {
                                  camera.zoom = (camera.zoom * 1.2).clamp(
                                    .25,
                                    4,
                                  );
                                  camera.update();
                                }),
                                _cameraTool(Icons.remove, 'Zoom out', () {
                                  camera.zoom = (camera.zoom / 1.2).clamp(
                                    .25,
                                    4,
                                  );
                                  camera.update();
                                }),
                                _cameraTool(
                                  Icons.fullscreen,
                                  'Fit',
                                  camera.reset,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          bottom: 8,
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Undo',
                                onPressed: s.canUndo ? s.undo : null,
                                icon: const Icon(Icons.undo),
                              ),
                              IconButton(
                                tooltip: 'Redo',
                                onPressed: s.canRedo ? s.redo : null,
                                icon: const Icon(Icons.redo),
                              ),
                              if (vibration)
                                const Text(
                                  'Illustrative bond motion',
                                  style: TextStyle(fontSize: 10, color: cyan),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onVerticalDragEnd: (d) =>
                        setState(() => expanded = (d.primaryVelocity ?? 0) < 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: expanded
                          ? math.min(
                              MediaQuery.sizeOf(context).height * .48,
                              MediaQuery.sizeOf(context).height - 420,
                            )
                          : MediaQuery.sizeOf(context).height < 700
                          ? 148
                          : 218,
                      decoration: const BoxDecoration(
                        color: background,
                        border: Border(top: BorderSide(color: line)),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => setState(() => expanded = !expanded),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 8, 12, 6),
                              child: Column(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: line,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.molecule.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 25,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              s.data.formula(s.molecule),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Rename molecule',
                                        onPressed: () => _rename(s),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _optimize(s),
                                        icon: const Icon(
                                          Icons.auto_awesome,
                                          size: 18,
                                        ),
                                        label: const Text('Relax bonds'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 37,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              children: [
                                for (var i = 0; i < 4; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(
                                        [
                                          'Properties',
                                          'Geometry',
                                          'Interactions',
                                          'Lewis structure',
                                        ][i],
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      selected: inspector == i,
                                      onSelected: (_) => setState(() {
                                        inspector = i;
                                        expanded = true;
                                      }),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                              child: _inspector(s),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: line)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ToolButton(
                            Icons.add_circle_outline,
                            'Add Atom',
                            s.addAtom,
                          ),
                          const SizedBox(width: 6),
                          ToolButton(Icons.link, 'Add Bond', () {
                            setState(() => connecting = !connecting);
                          }, active: connecting),
                          const SizedBox(width: 6),
                          ToolButton(
                            Icons.delete_outline,
                            'Delete',
                            s.selectedAtom == null ? null : s.removeSelected,
                          ),
                          const SizedBox(width: 6),
                          ToolButton(
                            Icons.view_in_ar,
                            'Spacefill',
                            () => setState(
                              () => mode = mode == DisplayMode.spacefill
                                  ? DisplayMode.ballAndStick
                                  : DisplayMode.spacefill,
                            ),
                            active: mode == DisplayMode.spacefill,
                          ),
                          const SizedBox(width: 6),
                          ToolButton(
                            Icons.cloud_outlined,
                            'Electrostatic',
                            () => message(
                              context,
                              'Electrostatic surface unavailable',
                              'This structure has no bundled validated partial-charge calculation or electrostatic potential grid. A calculated surface cannot be shown.',
                            ),
                          ),
                          const SizedBox(width: 6),
                          ToolButton(
                            Icons.graphic_eq,
                            'Vibration',
                            _vibration,
                            active: vibration,
                          ),
                          const SizedBox(width: 6),
                          ToolButton(
                            Icons.restart_alt,
                            'Reset View',
                            camera.reset,
                          ),
                          const SizedBox(width: 6),
                          ToolButton(
                            Icons.home_outlined,
                            'Home',
                            () => context.go('/'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cameraTool(IconData icon, String tooltip, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: background.withValues(alpha: .8),
            border: Border.all(color: line),
          ),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onTap,
            icon: Icon(icon, color: muted, size: 22),
          ),
        ),
      );
  Widget _bondToolbar(StudioStore s) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(
      children: [
        for (var i = 1; i <= 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ToolButton(
              i == 1
                  ? Icons.remove
                  : i == 2
                  ? Icons.drag_handle
                  : Icons.menu,
              ['Single', 'Double', 'Triple'][i - 1],
              () {
                s.bondOrder = i;
                setState(() {});
              },
              active: s.bondOrder == i,
            ),
          ),
        ToolButton(
          Icons.info_outline,
          'Aromatic',
          () => message(
            context,
            'Aromatic representation',
            'Benzene is bundled in a Kekulé representation with alternating single and double bonds. Aromatic bond editing and aromaticity perception are not implemented.',
          ),
        ),
      ],
    ),
  );
  Widget _inspector(StudioStore s) {
    final m = s.molecule;
    if (inspector == 3) {
      return SizedBox(
        height: 250,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = Size(box.maxWidth, 250);
            return InteractiveViewer(
              minScale: .5,
              maxScale: 4,
              child: GestureDetector(
                onTapUp: (d) {
                  final points = LewisPainter.layout(m, size);
                  for (final atom in m.atoms) {
                    if ((points[atom.id]! - d.localPosition).distance < 20) {
                      s.selectAtom(atom.id);
                      break;
                    }
                  }
                },
                onDoubleTap: () {
                  if (s.selectedAtom != null) {
                    _editAtom(s);
                  }
                },
                child: CustomPaint(
                  size: size,
                  painter: LewisPainter(m, s.data, s.selectedAtom),
                ),
              ),
            );
          },
        ),
      );
    }
    if (inspector == 1) {
      final atom = s.selectedAtom == null ? null : m.atom(s.selectedAtom!);
      final neighbors = atom == null
          ? <Atom>[]
          : m.bonds
                .where((b) => b.a == atom.id || b.b == atom.id)
                .map((b) => m.atom(b.a == atom.id ? b.b : b.a))
                .toList();
      return Column(
        children: [
          const Text('Measurements from the current 3D coordinates (Å).'),
          if (atom == null)
            const PropertyRow('Local geometry', 'Select an atom')
          else ...[
            PropertyRow(
              'Selected atom',
              '${s.data.element(atom.number).symbol} ${atom.id}',
            ),
            PropertyRow('Coordination number', '${neighbors.length}'),
            PropertyRow('Local shape', localGeometry(atom, neighbors)),
            for (var i = 0; i < neighbors.length; i++)
              for (var j = i + 1; j < neighbors.length; j++)
                PropertyRow(
                  '∠ ${neighbors[i].id}–${atom.id}–${neighbors[j].id}',
                  '${angle(neighbors[i], atom, neighbors[j]).toStringAsFixed(1)}°',
                ),
          ],
          for (final b in m.bonds)
            InkWell(
              onTap: () => _bondDetails(s, b),
              child: PropertyRow(
                '${s.data.element(m.atom(b.a).number).symbol}${b.a}–${s.data.element(m.atom(b.b).number).symbol}${b.b}',
                '${bondLength(m, b).toStringAsFixed(3)} Å',
              ),
            ),
          const SizedBox(height: 12),
          const Text('Dihedrals · atom IDs · coordinate-based'),
          for (final t in torsions(m))
            PropertyRow(t.label, '${t.degrees.toStringAsFixed(1)}°'),
        ],
      );
    }
    if (inspector == 2) {
      return Column(
        children: [
          PropertyRow(
            'Net formal charge',
            '${m.atoms.fold(0, (v, a) => v + a.charge)} e',
          ),
          const PropertyRow('Polarity', 'Not calculated'),
          PropertyRow(
            'H-bond donors / acceptors',
            m.properties['hbd'] == null
                ? 'Not assigned for edited graphs'
                : '${m.properties['hbd']} / ${m.properties['hba']} (PubChem CACTVS)',
          ),
          const SizedBox(height: 10),
          const Text(
            'Reliable interaction properties need aromaticity, protonation, and charge-model assignment. No electrostatic potential is inferred from atom colors.',
          ),
        ],
      );
    }
    final warnings = validate(m);
    return Column(
      children: [
        PropertyRow('Molecular formula', s.data.formula(m)),
        if (m.properties['iupac'] != null)
          PropertyRow('IUPAC name', '${m.properties['iupac']}'),
        PropertyRow('Molar mass', '${s.data.mass(m).toStringAsFixed(2)} g/mol'),
        PropertyRow('Atoms / Bonds', '${m.atoms.length} / ${m.bonds.length}'),
        PropertyRow(
          'Formal charge',
          '${m.atoms.fold(0, (v, a) => v + a.charge)} e',
        ),
        if (s.selectedAtom != null)
          OutlinedButton(
            onPressed: () => _editAtom(s),
            child: const Text('Edit selected atom / formal charge'),
          ),
        PropertyRow(
          'Validation',
          warnings.isEmpty
              ? 'Typical valences satisfied'
              : '${warnings.length} warning(s)',
        ),
        for (final w in warnings)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              w,
              style: const TextStyle(color: Colors.amber, fontSize: 11),
            ),
          ),
        const SizedBox(height: 10),
        Text(
          'Coordinates: ${m.source}\nValence checks are heuristic, not a proof of chemical validity.',
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Future<void> _library(StudioStore s, {bool savedOnly = false}) async {
    String query = '';
    bool saved = savedOnly;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .78,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Molecule Library',
                          style: TextStyle(fontSize: 23, color: Colors.white),
                        ),
                      ),
                      FilterChip(
                        label: const Text('Saved'),
                        selected: saved,
                        onSelected: (v) => update(() => saved = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search molecules',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => update(() => query = v),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: [
                        if (saved && s.saved.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No saved molecules yet. Save your work from the menu.',
                            ),
                          ),
                        for (final m
                            in (saved ? s.saved : s.data.presets).where(
                              (m) => m.name.toLowerCase().contains(
                                query.toLowerCase(),
                              ),
                            ))
                          ListTile(
                            leading: const Icon(
                              Icons.hub_outlined,
                              color: cyan,
                            ),
                            title: Text(m.name),
                            subtitle: Text(
                              '${s.data.formula(m)} · ${m.atoms.length} atoms',
                            ),
                            trailing: saved
                                ? IconButton(
                                    tooltip: 'Delete saved molecule',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await s.deleteSaved(m.id);
                                      update(() {});
                                    },
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: () {
                              s.edit(m);
                              camera.reset();
                              Navigator.pop(context);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _rename(StudioStore s, {bool save = false}) async {
    final controller = TextEditingController(text: s.molecule.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(save ? 'Save molecule' : 'Rename molecule'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(save ? 'Save' : 'Rename'),
          ),
        ],
      ),
    );
    if (result != null) {
      if (save) {
        try {
          await s.save(result);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Molecule saved on this device')),
            );
          }
        } catch (e) {
          if (mounted) {
            message(context, 'Save failed', '$e');
          }
        }
      } else {
        s.edit(s.molecule.copy(name: result));
      }
    }
    controller.dispose();
  }

  Future<void> _action(String action, StudioStore s) async {
    switch (action) {
      case 'save':
        await _rename(s, save: true);
      case 'rename':
        await _rename(s);
      case 'blank':
        s.edit(
          Molecule(
            id: 'blank',
            name: 'Untitled molecule',
            atoms: [],
            bonds: [],
          ),
        );
      case 'duplicate':
        s.edit(
          s.molecule.copy(
            id: 'copy-${DateTime.now().microsecondsSinceEpoch}',
            name: '${s.molecule.name} copy',
          ),
        );
      case 'labels':
        setState(() => labels = !labels);
      case 'mode':
        setState(
          () => mode =
              DisplayMode.values[(mode.index + 1) % DisplayMode.values.length],
        );
      case 'export':
        await _export(
          const JsonEncoder.withIndent('  ').convert(s.molecule.toJson()),
          'Chemistry Universe JSON',
        );
      case 'mol':
        await _export(_mol(s), 'MOL V2000');
      case 'import':
        await _import(s);
    }
  }

  Future<void> _export(String text, String title) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _mol(StudioStore s) {
    final m = s.molecule;
    if (m.atoms.length > 999 || m.bonds.length > 999) {
      return 'V2000 limit exceeded';
    }
    final out = StringBuffer(
      '${m.name}\n  Chemistry Universe\n\n${m.atoms.length.toString().padLeft(3)}${m.bonds.length.toString().padLeft(3)}  0  0  0  0            999 V2000\n',
    );
    for (final a in m.atoms) {
      out.writeln(
        '${a.x.toStringAsFixed(4).padLeft(10)}${a.y.toStringAsFixed(4).padLeft(10)}${a.z.toStringAsFixed(4).padLeft(10)} ${s.data.element(a.number).symbol.padRight(3)} 0  0  0  0  0  0  0  0  0  0  0  0',
      );
    }
    for (final b in m.bonds) {
      out.writeln(
        '${(m.atoms.indexWhere((a) => a.id == b.a) + 1).toString().padLeft(3)}${(m.atoms.indexWhere((a) => a.id == b.b) + 1).toString().padLeft(3)}${b.order.toString().padLeft(3)}  0  0  0  0',
      );
    }
    for (final a in m.atoms.where((a) => a.charge != 0)) {
      out.writeln(
        'M  CHG  1${(m.atoms.indexOf(a) + 1).toString().padLeft(4)}${a.charge.toString().padLeft(4)}',
      );
    }
    out.writeln('M  END');
    return out.toString();
  }

  Future<void> _import(StudioStore s) async {
    final controller = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Import molecular JSON'),
          content: SizedBox(
            width: 500,
            child: TextField(
              controller: controller,
              maxLines: 12,
              decoration: InputDecoration(
                hintText: 'Paste Chemistry Universe JSON',
                errorText: error,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final value = jsonDecode(controller.text);
                  if (value is! Map<String, dynamic>) {
                    throw const FormatException('Expected a JSON object');
                  }
                  final m = Molecule.fromJson(value);
                  s.edit(m);
                  Navigator.pop(context);
                } catch (e) {
                  update(() => error = 'Invalid molecular data: $e');
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  void _bondDetails(StudioStore s, Bond b) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bond ${b.a}–${b.b}',
                style: const TextStyle(fontSize: 23, color: Colors.white),
              ),
              PropertyRow(
                'Length',
                '${bondLength(s.molecule, b).toStringAsFixed(3)} Å',
              ),
              PropertyRow('Order', '${b.order}'),
              Wrap(
                spacing: 8,
                children: [
                  for (var order = 1; order <= 3; order++)
                    OutlinedButton(
                      onPressed: () {
                        s.bondOrder = order;
                        s.connect(b.a, b.b);
                        Navigator.pop(context);
                      },
                      child: Text('Order $order'),
                    ),
                  TextButton(
                    onPressed: () {
                      s.edit(
                        s.molecule.copy(
                          bonds: s.molecule.bonds
                              .where((bond) => bond != b)
                              .toList(),
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('Remove bond'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editAtom(StudioStore s) {
    final atom = s.molecule.atom(s.selectedAtom!);
    int number = atom.number, charge = atom.charge;
    final position = atom.position;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Edit atom ${atom.id}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: number,
                  items: [
                    for (final e in s.data.elements)
                      DropdownMenuItem(
                        value: e.number,
                        child: Text('${e.symbol} · ${e.name}'),
                      ),
                  ],
                  onChanged: (v) => update(() => number = v!),
                ),
                Row(
                  children: [
                    const Text('Formal charge'),
                    IconButton(
                      onPressed: () =>
                          update(() => charge = math.max(-8, charge - 1)),
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$charge'),
                    IconButton(
                      onPressed: () =>
                          update(() => charge = math.min(8, charge + 1)),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                for (var axis = 0; axis < 3; axis++)
                  Column(
                    children: [
                      Text(
                        '${['X', 'Y', 'Z'][axis]} = ${position[axis].toStringAsFixed(2)} Å',
                      ),
                      Slider(
                        value: position[axis].clamp(-10, 10),
                        min: -10,
                        max: 10,
                        onChanged: (value) =>
                            update(() => position[axis] = value),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                s.edit(
                  s.molecule.copy(
                    atoms: s.molecule.atoms
                        .map(
                          (a) => a.id == atom.id
                              ? a.copy(
                                  number: number,
                                  charge: charge,
                                  position: Vector3.copy(position),
                                )
                              : a,
                        )
                        .toList(),
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _optimize(StudioStore s) {
    try {
      final result = relaxBonds(s.molecule);
      s.edit(result.molecule);
      message(
        context,
        'Harmonic bond relaxation',
        'Residual Σ(r − r₀)²: ${result.before.toStringAsFixed(6)} → ${result.after.toStringAsFixed(6)} Å².\n\nTargets use covalent-radius sums with bond-order scaling. This limited model minimizes bond-length residuals only. It omits angles, torsions, nonbonded interactions, and electronic energy. It is not a validated molecular mechanics optimizer.',
      );
    } catch (e) {
      message(context, 'Relaxation unavailable', '$e');
    }
  }

  void _vibration() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Illustrative vibration',
                  style: TextStyle(fontSize: 22, color: Colors.white),
                ),
                const Text(
                  'Alternating atom displacements; not calculated normal modes. No frequency in cm⁻¹ is assigned.',
                ),
                SwitchListTile(
                  title: const Text('Play'),
                  value: vibration,
                  onChanged: (v) {
                    setState(() => vibration = v);
                    update(() {});
                  },
                ),
                Text('Amplitude ${amplitude.toStringAsFixed(2)} Å'),
                Slider(
                  value: amplitude,
                  min: 0,
                  max: .3,
                  onChanged: (v) {
                    setState(() => amplitude = v);
                    update(() {});
                  },
                ),
                Text('Speed ${speed.toStringAsFixed(1)}×'),
                Slider(
                  value: speed,
                  min: .3,
                  max: 3,
                  onChanged: (v) {
                    setState(() => speed = v);
                    update(() {});
                  },
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      amplitude = .1;
                      speed = 1;
                      vibration = false;
                    });
                    update(() {});
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LewisPainter extends CustomPainter {
  final Molecule molecule;
  final ChemistryData data;
  final int? selected;
  LewisPainter(this.molecule, this.data, this.selected);
  static Map<int, Offset> layout(Molecule m, Size size) {
    if (m.atoms.isEmpty) {
      return {};
    }
    final minX = m.atoms.map((a) => a.x).reduce(math.min),
        maxX = m.atoms.map((a) => a.x).reduce(math.max),
        minY = m.atoms.map((a) => a.y).reduce(math.min),
        maxY = m.atoms.map((a) => a.y).reduce(math.max);
    final scale = math.min(
      (size.width - 50) / math.max(1, maxX - minX),
      (size.height - 50) / math.max(1, maxY - minY),
    );
    return {
      for (final a in m.atoms)
        a.id: Offset(
          size.width / 2 + (a.x - (minX + maxX) / 2) * scale,
          size.height / 2 - (a.y - (minY + maxY) / 2) * scale,
        ),
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final points = layout(molecule, size);
    for (final b in molecule.bonds) {
      final a = points[b.a]!, end = points[b.b]!, d = end - a;
      if (d.distance < 1) {
        continue;
      }
      final unit = d / d.distance, normal = Offset(-unit.dy, unit.dx);
      for (var i = 0; i < b.order; i++) {
        final offset = normal * ((i - (b.order - 1) / 2) * 4);
        canvas.drawLine(
          a + unit * 12 + offset,
          end - unit * 12 + offset,
          Paint()
            ..color = muted
            ..strokeWidth = 1.5,
        );
      }
    }
    for (final a in molecule.atoms) {
      final p = points[a.id]!;
      canvas.drawCircle(p, 12, Paint()..color = background);
      final symbol = data.element(a.number).symbol;
      final text = TextPainter(
        text: TextSpan(
          text:
              '$symbol${a.charge == 0
                  ? ''
                  : a.charge > 0
                  ? '+${a.charge}'
                  : '${a.charge}'}',
          style: TextStyle(
            color: a.id == selected ? cyan : Colors.white,
            fontSize: 15,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, p - Offset(text.width / 2, text.height / 2));
      final valence = const {
        1: 1,
        6: 4,
        7: 5,
        8: 6,
        9: 7,
        15: 5,
        16: 6,
        17: 7,
        35: 7,
        53: 7,
      }[a.number];
      final order = molecule.bonds
          .where((b) => b.a == a.id || b.b == a.id)
          .fold(0, (v, b) => v + b.order);
      final pairs = valence == null
          ? 0
          : ((valence - order - a.charge) / 2).floor().clamp(0, 4);
      for (var i = 0; i < pairs; i++) {
        final angle = (i * math.pi / 2) - math.pi / 2;
        final center = p + Offset(math.cos(angle), math.sin(angle)) * 19;
        for (final delta in [-2.0, 2.0]) {
          canvas.drawCircle(
            center + Offset(-math.sin(angle), math.cos(angle)) * delta,
            1.4,
            Paint()..color = muted,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant LewisPainter oldDelegate) => true;
}
