import 'dart:convert';
import 'dart:async';
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
import '../shared/viewing_preferences.dart';
import '../shared/orientation_cube.dart';
import '../shared/text_prompt.dart';
import 'molecule_library.dart';
import 'molecule_import.dart';
part 'molecule_tools.dart';

class MoleculeScreen extends ConsumerStatefulWidget {
  const MoleculeScreen({super.key});
  @override
  ConsumerState<MoleculeScreen> createState() => _MoleculeState();
}

class _MoleculeState extends ConsumerState<MoleculeScreen>
    with SingleTickerProviderStateMixin {
  final camera = CameraState();
  late final StudioStore workspaceStore;
  int toolbar = 0, inspector = 0;
  bool expanded = false, labels = false, vibration = false, connecting = false;
  bool vibrationVisible = false;
  double amplitude = .1, speed = 1;
  DisplayMode mode = DisplayMode.ballAndStick;
  InteractionMode interaction = InteractionMode.rotate;
  Atom? ghost;
  Bond? pendingBond, selectedBond;
  Molecule? movingPreview;
  String moveAxis = 'Free',
      measurementKind = 'Length',
      vibrationKind = 'Alternating';
  int inspectorSnap = 1;
  final List<int> measureSelection = [];
  final List<SceneMeasurement> pinnedMeasurements = [];
  Size canvasSize = Size.zero;
  late final AnimationController cameraAnimation;
  Vector3? cameraFrom, cameraTo;
  void _apply(VoidCallback fn) => setState(fn);
  @override
  void initState() {
    super.initState();
    workspaceStore = ref.read(studioProvider);
    final state = ref.read(studioProvider).preferences.molecule;
    try {
      if (state['camera'] is Map) {
        camera.restore((state['camera'] as Map).cast<String, dynamic>());
      }
      mode = DisplayMode.values[(state['mode'] as int? ?? 0).clamp(0, 3)];
      inspectorSnap = (state['inspector'] as int? ?? 1).clamp(0, 2);
      labels = state['labels'] == true;
    } catch (_) {}

    cameraAnimation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 230),
        )..addListener(() {
          if (cameraFrom != null && cameraTo != null) {
            final t = Curves.easeOutCubic.transform(cameraAnimation.value);
            camera.focus = cameraFrom! + (cameraTo! - cameraFrom!) * t;
            camera.pan = Offset.zero;
            camera.zoom = 1 + t * .5;
            camera.update();
          }
        });
  }

  @override
  void dispose() {
    final prefs = workspaceStore.preferences;
    prefs.molecule = {
      'camera': camera.toJson(),
      'mode': mode.index,
      'inspector': inspectorSnap,
      'labels': labels,
    };
    prefs.persist(notify: false);
    cameraAnimation.dispose();
    camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(studioProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([s, s.preferences]),
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
                              ('workspace', 'Molecule workspace'),
                              ('history', 'Editing history'),
                              ('palette', 'Full element picker'),
                              ('bookmarks', 'Camera bookmarks'),
                              ('legend', 'Visualization legend'),
                              ('preferences', 'Viewing & accessibility'),
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
                  _modeToolbar(s),
                  const SizedBox(height: 4),
                  if (!(s.preferences.textScale > 1.1 &&
                      interaction == InteractionMode.rotate))
                    SizedBox(
                      height: 72 * MediaQuery.textScalerOf(context).scale(1),
                      child: toolbar == 1
                          ? _bondToolbar(s)
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                            child: AnimatedSwitcher(
                              duration: s.preferences.reducedMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              child: MoleculeView(
                                key: ValueKey(mode),
                                molecule: movingPreview ?? s.molecule,
                                interaction: interaction,
                                ghost: ghost,
                                previewBond: pendingBond,
                                selectedBond: selectedBond,
                                highlights: measureSelection.toSet(),
                                warnings: validate(s.molecule)
                                    .map(
                                      (w) =>
                                          RegExp(r'Atom (\d+)').firstMatch(w),
                                    )
                                    .whereType<RegExpMatch>()
                                    .map((m) => int.parse(m[1]!))
                                    .toSet(),
                                measurements: pinnedMeasurements,
                                alternativeColors:
                                    s.preferences.alternativeColors,
                                onMove: _moveAtom,
                                onMoveEnd: _commitMove,
                                onContext: _contextAtom,
                                onPlace: (p) => _apply(
                                  () => ghost = Atom(
                                    -1,
                                    s.atomType,
                                    p.x,
                                    p.y,
                                    p.z,
                                  ),
                                ),
                                onViewport: (size) => canvasSize = size,
                                atomLabels: {
                                  for (final a in s.molecule.atoms)
                                    a.id: s.data.element(a.number).symbol,
                                },
                                camera: camera,
                                selected: s.selectedAtom,
                                mode: mode,
                                labels:
                                    labels || s.preferences.alternativeColors,
                                vibration:
                                    vibration && !s.preferences.reducedMotion,
                                vibrationKind: vibrationKind,
                                vibrationVisible: vibrationVisible,
                                onInteractionStart: cameraAnimation.stop,
                                amplitude: amplitude,
                                speed: speed,
                                onPick: _pickAtom,
                                onBond: (bond) {
                                  _apply(() => selectedBond = bond);
                                  s.selectAtom(null);
                                },
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          left: 12,
                          right: 12,
                          child: _selectionBanner(s),
                        ),
                        Positioned(
                          left: 12,
                          bottom: 50,
                          child: _orientationCube(),
                        ),
                        if (s.preferences.moleculeHints)
                          Positioned(
                            left: 70,
                            bottom: 52,
                            right: 65,
                            child: Panel(
                              padding: const EdgeInsets.all(6),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Pick a mode. Long-press atoms for actions.',
                                      style: TextStyle(fontSize: 9),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Dismiss molecule guidance',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      s.preferences.moleculeHints = false;
                                      s.preferences.persist();
                                    },
                                    icon: const Icon(Icons.close, size: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (interaction == InteractionMode.measure)
                          Positioned(
                            left: 70,
                            bottom: 50,
                            child: TextButton(
                              onPressed: _workspaceTools,
                              child: Text(
                                measureSelection.length == measurementCount
                                    ? 'Pin ${SceneMeasurement(measurementKind, measureSelection).value(s.molecule)}'
                                    : '$measurementKind: ${measureSelection.length}/$measurementCount selected',
                              ),
                            ),
                          ),
                        if (selectedBond != null)
                          Positioned(
                            left: 70,
                            bottom: 50,
                            child: TextButton(
                              onPressed: () => _bondDetails(s, selectedBond!),
                              child: Text(
                                'Bond ${selectedBond!.a}–${selectedBond!.b} · order ${selectedBond!.order}',
                              ),
                            ),
                          ),
                        Positioned(
                          right: 12,
                          top: 70,
                          bottom: 38,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _cameraTool(Icons.rotate_right, 'Rotate', () {
                                  _setMode(InteractionMode.rotate);
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
                              if (vibrationVisible)
                                Text(
                                  'Illustrative · ${vibration && !s.preferences.reducedMotion ? 'playing' : 'paused'}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: cyan,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _inspectorPanel(s),
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
                            _beginPlacement,
                          ),
                          const SizedBox(width: 6),
                          ToolButton(Icons.link, 'Add Bond', () {
                            _setMode(
                              interaction == InteractionMode.addBond
                                  ? InteractionMode.select
                                  : InteractionMode.addBond,
                            );
                          }, active: connecting),
                          const SizedBox(width: 6),
                          ToolButton(
                            Icons.delete_outline,
                            'Delete',
                            s.selectedAtom == null ? null : _deleteAtom,
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
                              'This structure has no validated partial charges or potential grid. No calculated surface is available. Open Visualization legend from Molecule workspace for supported identity colors and units.',
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
                      _pickAtom(atom.id);
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
            SizedBox(
              height: 110,
              child: LayoutBuilder(
                builder: (context, box) => CustomPaint(
                  size: Size(box.maxWidth, 110),
                  painter: ScenePainter(
                    m.copy(
                      atoms: [atom, ...neighbors],
                      bonds: m.bonds
                          .where((b) => b.a == atom.id || b.b == atom.id)
                          .toList(),
                    ),
                    CameraState(),
                    DisplayMode.ballAndStick,
                    atom.id,
                    true,
                    0,
                    false,
                    atomLabels: {
                      for (final a in [atom, ...neighbors])
                        a.id: s.data.element(a.number).symbol,
                    },
                  ),
                ),
              ),
            ),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StudioLibrary(
        store: s,
        savedOnly: savedOnly,
        onOpen: (m) {
          Navigator.pop(sheet);
          if (m.id.startsWith('saved-')) {
            s.open(m);
            camera.reset();
          } else {
            _previewMolecule(m, s);
          }
        },
        onPreview: (m) => _previewMolecule(m, s),
      ),
    );
  }

  Future<void> _rename(StudioStore s, {bool save = false}) async {
    final result = await promptText(
      context,
      title: save ? 'Save molecule' : 'Rename molecule',
      initial: s.molecule.name,
      confirm: save ? 'Save' : 'Rename',
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
        s.edit(s.molecule.copy(name: result), label: 'Rename molecule');
      }
    }
  }

  Future<void> _action(String action, StudioStore s) async {
    switch (action) {
      case 'workspace':
        _workspaceTools();
      case 'history':
        _showHistory();
      case 'palette':
        _elementPalette(s);
      case 'bookmarks':
        _cameraBookmarks();
      case 'legend':
        _showLegend();
      case 'preferences':
        showViewingPreferences(context, s.preferences);
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
        await _guidedExport(s);
      case 'mol':
        await _guidedExport(s, initial: 'MOL');
      case 'import':
        await _import(s);
    }
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

  Future<void> _import(StudioStore s) => showDialog<void>(
    context: context,
    builder: (context) => MoleculeImportDialog(
      data: s.data,
      onImport: (m) => s.edit(m, label: 'Import ${m.name}'),
    ),
  );

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

  void _vibration() {
    setState(() => vibrationVisible = true);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
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
                    'Illustrative displacements; not calculated normal modes. No frequency in cm⁻¹ is assigned. Measurements use the stored coordinates.',
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final kind in ['Alternating', 'Radial breathing'])
                        ChoiceChip(
                          label: Text(kind),
                          selected: vibrationKind == kind,
                          onSelected: (_) {
                            setState(() => vibrationKind = kind);
                            update(() {});
                          },
                        ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Play'),
                    value:
                        vibration && !workspaceStore.preferences.reducedMotion,
                    subtitle: workspaceStore.preferences.reducedMotion
                        ? const Text('Playback is disabled by Reduce motion.')
                        : null,
                    onChanged: workspaceStore.preferences.reducedMotion
                        ? null
                        : (v) {
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
                        vibrationVisible = false;
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
