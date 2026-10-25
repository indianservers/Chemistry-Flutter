import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/design.dart';
import '../core/chemistry.dart';
import '../core/store.dart';
import '../rendering/molecule_view.dart';
import 'periodic_style.dart';
import '../shared/viewing_preferences.dart';
part 'periodic_tools.dart';

Color categoryColor(String category) => switch (category) {
  'alkali metal' => const Color(0xffff4563),
  'alkaline earth metal' => const Color(0xffffa42b),
  'transition metal' => const Color(0xff11d4c5),
  'post-transition metal' => const Color(0xff23ce95),
  'metalloid' => const Color(0xff13c8d5),
  'noble gas' => const Color(0xfff344a3),
  'halogen' => const Color(0xffae62f2),
  'lanthanide' => const Color(0xff35cceb),
  'actinide' => const Color(0xffdbb244),
  'diatomic nonmetal' || 'polyatomic nonmetal' => const Color(0xff278dff),
  _ => const Color(0xffa0a8ca),
};
const trendKeys = {
  'Atomic radius (pm)': 'radius',
  'Ionic radius +1, CN VI (pm)': 'ionic:1',
  'Ionic radius +2, CN VI (pm)': 'ionic:2',
  'Ionic radius +3, CN VI (pm)': 'ionic:3',
  'Ionic radius −1, CN VI (pm)': 'ionic:-1',
  'Ionic radius −2, CN VI (pm)': 'ionic:-2',
  'Electronegativity': 'electronegativity_pauling',
  'Melting point (K)': 'melt',
  'Density (g/cm³)': 'density_g_cm3',
  'Electron affinity (kJ/mol)': 'electron_affinity',
  'First ionization (kJ/mol)': 'ionization',
};

class PeriodicScreen extends ConsumerStatefulWidget {
  const PeriodicScreen({super.key});
  @override
  ConsumerState<PeriodicScreen> createState() => _PeriodicState();
}

class _PeriodicState extends ConsumerState<PeriodicScreen>
    with SingleTickerProviderStateMixin {
  final transform = TransformationController();
  late final StudioStore workspaceStore;
  final camera = CameraState();
  final search = TextEditingController();
  String? category, trend;
  int? group, period;
  final Set<int> compared = {6, 14};
  bool comparing = false;
  bool gesturesLocked = false, showNames = true, panControls = false;
  double inspectorFraction = .39;
  Size viewport = Size.zero;
  static const tableSize = Size(852, 566);
  final Set<String> categoryFilters = {};
  bool minimap = false,
      semanticZoom = true,
      dockTop = false,
      compactDock = false;
  int detailLevel = 1;
  double heatIntensity = 1;
  Timer? rememberTimer;
  late final AnimationController viewAnimation;
  Matrix4Tween? viewTween;
  void _apply(VoidCallback fn) => setState(fn);
  @override
  void initState() {
    super.initState();
    workspaceStore = ref.read(studioProvider);
    _restoreWorkspace();
    transform.addListener(_viewChanged);
    viewAnimation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          if (viewTween != null) {
            transform.value = viewTween!.transform(
              Curves.easeOutCubic.transform(viewAnimation.value),
            );
          }
        });
  }

  @override
  void dispose() {
    rememberTimer?.cancel();
    _remember();
    transform.removeListener(_viewChanged);
    viewAnimation.dispose();
    transform.dispose();
    camera.dispose();
    search.dispose();
    super.dispose();
  }

  double? value(ElementData e) {
    final key = trendKeys[trend];
    if (key == 'ionization') {
      final values = e.data['ionization_energies'] as List?;
      return values == null || values.isEmpty
          ? null
          : (values.first as num).toDouble();
    }
    return key == null ? null : e.property(key);
  }

  void _setView(double scale, Offset offset) {
    transform.value = Matrix4.identity()
      ..translateByDouble(offset.dx, offset.dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _zoom(double multiplier) {
    final matrix = transform.value, old = matrix.getMaxScaleOnAxis();
    final scale = (old * multiplier).clamp(.08, 4.0);
    final focal = viewport.center(Offset.zero);
    final scene = transform.toScene(focal);
    _setView(scale, focal - scene * scale);
  }

  void _pan(Offset delta) {
    final m = transform.value;
    _setView(
      m.getMaxScaleOnAxis(),
      Offset(m.storage[12], m.storage[13]) + delta,
    );
  }

  void _fit() {
    if (viewport.isEmpty) {
      return;
    }
    final scale = math
        .min(
          (viewport.width - 18) / tableSize.width,
          (viewport.height - 64) / tableSize.height,
        )
        .clamp(.08, 4.0);
    _setView(scale, Offset((viewport.width - tableSize.width * scale) / 2, 4));
  }

  void _focus(ElementData element) => _animateFocus(element);
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(studioProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([s, s.preferences]),
      builder: (context, _) {
        final selected = s.data.element(s.selectedElement);
        final categories = s.data.elements
            .map((e) => e.category)
            .toSet()
            .toList();
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _selectAdjacent(1),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _selectAdjacent(-1),
            const SingleActivator(LogicalKeyboardKey.equal): () => _zoom(1.25),
            const SingleActivator(LogicalKeyboardKey.minus): () => _zoom(.8),
            const SingleActivator(LogicalKeyboardKey.digit0): _fit,
            const SingleActivator(LogicalKeyboardKey.keyR): () =>
                transform.value = Matrix4.identity(),
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
                _search(s),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: CustomPaint(
                painter: ScienceBackdrop(),
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: LayoutBuilder(
                        builder: (context, screen) {
                          final height = screen.maxHeight;
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  12,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    const AtomMark(size: 40),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Periodic Table',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: screen.maxWidth < 360
                                                    ? 23
                                                    : 27,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -.6,
                                                height: 1.05,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          const FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Explore elements, properties and trends',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: muted,
                                                fontSize: 11,
                                                height: 1.2,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _roundAction(
                                      Icons.search,
                                      'Search elements',
                                      () => _search(s),
                                    ),
                                    const SizedBox(width: 7),
                                    NeonSurface(
                                      radius: 30,
                                      padding: EdgeInsets.zero,
                                      child: PopupMenuButton<String>(
                                        tooltip: 'Table options',
                                        icon: const Icon(
                                          Icons.more_vert,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        onSelected: (v) {
                                          switch (v) {
                                            case 'workspace':
                                              _workspaceTools();
                                            case 'favorites':
                                              _shelf();
                                            case 'preferences':
                                              showViewingPreferences(
                                                context,
                                                s.preferences,
                                              );
                                            case 'coach':
                                              message(
                                                context,
                                                'Explore the table',
                                                'Drag to pan; pinch or double-tap to zoom. The minimap and view presets are in Table workspace. Tap group/period labels to highlight a sequence. Arrow keys move selection; +/− zoom, 0 fits, R resets, Ctrl+F searches.',
                                              );
                                            case 'reset':
                                              transform.value =
                                                  Matrix4.identity();
                                            case 'fit':
                                              _fit();
                                            case 'filters':
                                              _filters();
                                            case 'trends':
                                              _trends();
                                            case 'compare':
                                              setState(
                                                () => comparing = !comparing,
                                              );
                                            case 'names':
                                              setState(
                                                () => showNames = !showNames,
                                              );
                                            case 'details':
                                              _details(selected, s);
                                            case 'isotopes':
                                              _isotopes(selected);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: "workspace",
                                            child: Text("Table workspace"),
                                          ),
                                          const PopupMenuItem(
                                            value: "favorites",
                                            child: Text(
                                              "Favorites & recent elements",
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: "preferences",
                                            child: Text(
                                              "Viewing & accessibility",
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: "coach",
                                            child: Text("Quick guide"),
                                          ),
                                          const PopupMenuItem(
                                            value: 'reset',
                                            child: Text('Reset view'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'fit',
                                            child: Text('Fit all 118 elements'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'filters',
                                            child: Text(
                                              'Highlight group / period',
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'trends',
                                            child: Text('Periodic trends'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'compare',
                                            child: Text('Compare elements'),
                                          ),
                                          PopupMenuItem(
                                            value: 'names',
                                            child: Text(
                                              showNames
                                                  ? 'Hide element names'
                                                  : 'Show element names',
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'isotopes',
                                            child: Text('Isotope explorer'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'details',
                                            child: Text('Element details'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 43,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    2,
                                    14,
                                    5,
                                  ),
                                  child: Row(
                                    children: [
                                      for (final c in categories)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 7,
                                          ),
                                          child: Semantics(
                                            selected: categoryFilters.contains(
                                              c,
                                            ),
                                            button: true,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                              onTap: () => _refresh(() {
                                                categoryFilters.contains(c)
                                                    ? categoryFilters.remove(c)
                                                    : categoryFilters.add(c);
                                              }),
                                              child: NeonSurface(
                                                selected: categoryFilters
                                                    .contains(c),
                                                radius: 11,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 7,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 9,
                                                      height: 9,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: categoryColor(c),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color:
                                                                categoryColor(c)
                                                                    .withValues(
                                                                      alpha: .5,
                                                                    ),
                                                            blurRadius: 7,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '${s.preferences.patterns ? '${_categoryTag(c)} · ' : ''}$c (${s.data.elements.where((e) => e.category == c).length})',
                                                      style: TextStyle(
                                                        color:
                                                            categoryFilters
                                                                .contains(c)
                                                            ? Colors.white
                                                            : muted,
                                                        fontSize: 11,
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
                              if (trend != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.gradient,
                                        color: cyan,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '$trend · dark → bright = low → high · gray = unavailable',
                                          style: const TextStyle(fontSize: 9),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'Clear trend',
                                        onPressed: () =>
                                            setState(() => trend = null),
                                        icon: const Icon(Icons.close, size: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              if (trend != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: _trendScale(s),
                                ),
                              if (comparing) _comparisonTray(),
                              if (comparing)
                                Row(
                                  children: [
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        'Tap 2–4 elements · ${compared.length} selected',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: compared.length < 2
                                          ? null
                                          : () => _compare(s),
                                      child: const Text('Compare'),
                                    ),
                                    IconButton(
                                      tooltip: 'Close comparison',
                                      onPressed: () =>
                                          setState(() => comparing = false),
                                      icon: const Icon(Icons.close, size: 18),
                                    ),
                                  ],
                                ),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, box) {
                                    viewport = box.biggest;
                                    return Stack(
                                      children: [
                                        Positioned.fill(
                                          child: ClipRect(
                                            child: InteractiveViewer(
                                              key: const ValueKey(
                                                'periodic-viewport',
                                              ),
                                              transformationController:
                                                  transform,
                                              constrained: false,
                                              alignment: Alignment.topLeft,
                                              minScale: .08,
                                              maxScale: 4,
                                              boundaryMargin:
                                                  const EdgeInsets.all(900),
                                              panEnabled: !gesturesLocked,
                                              scaleEnabled: !gesturesLocked,
                                              child: GestureDetector(
                                                onDoubleTap: () => _zoom(1.5),
                                                child: RepaintBoundary(
                                                  child: SizedBox(
                                                    width: tableSize.width,
                                                    height: tableSize.height,
                                                    child: Stack(
                                                      children: [
                                                        Positioned.fill(
                                                          child: IgnorePointer(
                                                            child: CustomPaint(
                                                              painter:
                                                                  _EmptyCellsPainter(
                                                                    s
                                                                        .data
                                                                        .elements,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                        for (
                                                          var col = 1;
                                                          col <= 18;
                                                          col++
                                                        )
                                                          Positioned(
                                                            left:
                                                                28 +
                                                                (col - 1) *
                                                                    45.0,
                                                            top: 8,
                                                            width: 42,
                                                            child: GestureDetector(
                                                              onTap: () =>
                                                                  setState(
                                                                    () => group =
                                                                        group ==
                                                                            col
                                                                        ? null
                                                                        : col,
                                                                  ),
                                                              child: Text(
                                                                '$col',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color:
                                                                      group ==
                                                                          col
                                                                      ? cyan
                                                                      : muted,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        for (
                                                          var row = 1;
                                                          row <= 7;
                                                          row++
                                                        )
                                                          Positioned(
                                                            left: 6,
                                                            top:
                                                                45 +
                                                                (row - 1) *
                                                                    53.0,
                                                            child: GestureDetector(
                                                              onTap: () =>
                                                                  setState(
                                                                    () => period =
                                                                        period ==
                                                                            row
                                                                        ? null
                                                                        : row,
                                                                  ),
                                                              child: Text(
                                                                '$row',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color:
                                                                      period ==
                                                                          row
                                                                      ? cyan
                                                                      : muted,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        const Positioned(
                                                          left: 3,
                                                          top: 465,
                                                          child: Text(
                                                            'Ln',
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                            ),
                                                          ),
                                                        ),
                                                        const Positioned(
                                                          left: 3,
                                                          top: 518,
                                                          child: Text(
                                                            'An',
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                            ),
                                                          ),
                                                        ),
                                                        for (final e
                                                            in s.data.elements)
                                                          _tile(e, s),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: ListenableBuilder(
                                              listenable: transform,
                                              builder: (context, _) =>
                                                  CustomPaint(
                                                    painter:
                                                        _StickyLabelsPainter(
                                                          transform.value,
                                                        ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                        if (minimap)
                                          Positioned(
                                            right: 12,
                                            top: panControls ? 145 : 18,
                                            child: _minimap(),
                                          ),
                                        if (s.preferences.periodicHints)
                                          Positioned(
                                            left: 12,
                                            top: 24,
                                            child: NeonSurface(
                                              radius: 9,
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text(
                                                    'Drag to explore · pinch to zoom',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Dismiss table guidance',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    onPressed: () {
                                                      s
                                                              .preferences
                                                              .periodicHints =
                                                          false;
                                                      s.preferences.persist();
                                                    },
                                                    icon: const Icon(
                                                      Icons.close,
                                                      size: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        if (panControls)
                                          Positioned(
                                            right: 12,
                                            top: 4,
                                            child: NeonSurface(
                                              radius: 14,
                                              padding: const EdgeInsets.all(2),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _viewButton(
                                                    Icons.keyboard_arrow_up,
                                                    'Move up',
                                                    () => _pan(
                                                      const Offset(0, -70),
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      _viewButton(
                                                        Icons
                                                            .keyboard_arrow_left,
                                                        'Move left',
                                                        () => _pan(
                                                          const Offset(-70, 0),
                                                        ),
                                                      ),
                                                      _viewButton(
                                                        Icons
                                                            .keyboard_arrow_right,
                                                        'Move right',
                                                        () => _pan(
                                                          const Offset(70, 0),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  _viewButton(
                                                    Icons.keyboard_arrow_down,
                                                    'Move down',
                                                    () => _pan(
                                                      const Offset(0, 70),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        Positioned(
                                          left: 12,
                                          right: 12,
                                          top: dockTop ? 4 : null,
                                          bottom: dockTop ? null : 5,
                                          child: Center(
                                            child: NeonSurface(
                                              radius: 13,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2,
                                                  ),
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    _viewButton(
                                                      Icons.open_with,
                                                      'Pan controls',
                                                      () => setState(
                                                        () => panControls =
                                                            !panControls,
                                                      ),
                                                    ),
                                                    _viewButton(
                                                      Icons.remove,
                                                      'Zoom out',
                                                      () => _zoom(1 / 1.25),
                                                    ),
                                                    ListenableBuilder(
                                                      listenable: transform,
                                                      builder: (context, _) =>
                                                          SizedBox(
                                                            width: 36,
                                                            child: Text(
                                                              '${(transform.value.getMaxScaleOnAxis() * 100).round()}%',
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    color:
                                                                        muted,
                                                                  ),
                                                            ),
                                                          ),
                                                    ),
                                                    _viewButton(
                                                      Icons.add,
                                                      'Zoom in',
                                                      () => _zoom(1.25),
                                                    ),
                                                    _viewButton(
                                                      Icons.fit_screen,
                                                      'Fit all elements',
                                                      _fit,
                                                    ),
                                                    _viewButton(
                                                      Icons.my_location,
                                                      'Focus selected element',
                                                      () => _focus(selected),
                                                    ),
                                                    _viewButton(
                                                      gesturesLocked
                                                          ? Icons.lock_outline
                                                          : Icons.lock_open,
                                                      'Lock or unlock gestures',
                                                      () => setState(
                                                        () => gesturesLocked =
                                                            !gesturesLocked,
                                                      ),
                                                    ),
                                                    _viewButton(
                                                      Icons.restart_alt,
                                                      'Reset table view',
                                                      () => transform.value =
                                                          Matrix4.identity(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              _elementInspector(
                                selected,
                                s,
                                height,
                                screen.maxWidth,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  9,
                                  12,
                                  10,
                                ),
                                child: NeonSurface(
                                  radius: 23,
                                  padding: EdgeInsets.zero,
                                  child: Row(
                                    children: [
                                      _navItem(
                                        Icons.home_outlined,
                                        'Home',
                                        false,
                                        () => context.go('/'),
                                      ),
                                      _navItem(
                                        Icons.grid_view_rounded,
                                        'Periodic Table',
                                        true,
                                        () => transform.value =
                                            Matrix4.identity(),
                                      ),
                                      _navItem(
                                        Icons.hub_outlined,
                                        'Molecule Studio',
                                        false,
                                        () => context.go('/molecule'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _roundAction(IconData icon, String label, VoidCallback action) =>
      NeonSurface(
        radius: 30,
        padding: EdgeInsets.zero,
        child: IconButton(
          tooltip: label,
          onPressed: action,
          icon: Icon(icon, color: Colors.white, size: 22),
        ),
      );
  Widget _viewButton(IconData icon, String label, VoidCallback action) =>
      compactDock &&
          [
            'Pan controls',
            'Lock or unlock gestures',
            'Reset table view',
          ].contains(label)
      ? const SizedBox.shrink()
      : SizedBox(
          width: ref.read(studioProvider).preferences.largeControls ? 40 : 34,
          height: ref.read(studioProvider).preferences.largeControls ? 44 : 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
            tooltip: label,
            onPressed: action,
            icon: Icon(icon, size: 17, color: muted),
          ),
        );
  Widget _navItem(IconData icon, String label, bool active, VoidCallback tap) =>
      Expanded(
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(23),
          child: NeonSurface(
            selected: active,
            radius: 23,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 23,
                  color: active ? cyan : muted,
                  shadows: active
                      ? const [Shadow(color: Color(0xff1c9dff), blurRadius: 12)]
                      : null,
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? cyan : muted,
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  Widget _elementInspector(
    ElementData e,
    StudioStore s,
    double screenHeight,
    double width,
  ) {
    final collapsed = inspectorFraction < .2;
    final height = (screenHeight * inspectorFraction).clamp(
      86.0,
      math.max(100.0, screenHeight - 300),
    );
    return GestureDetector(
      onHorizontalDragEnd: (d) =>
          _selectAdjacent((d.primaryVelocity ?? 0) < 0 ? 1 : -1),
      child: Container(
        key: const ValueKey('element-inspector'),
        height: height.toDouble(),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: const Color(0xff275b91)),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff102e51), Color(0xff03142a), Color(0xff031126)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff0674e8).withValues(alpha: .14),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous element',
                    padding: EdgeInsets.zero,
                    onPressed: () => _selectAdjacent(-1),
                    icon: const Icon(Icons.chevron_left, size: 19),
                  ),
                  Expanded(
                    child: Text(
                      'Swipe through ${group != null
                          ? 'group $group'
                          : period != null
                          ? 'period $period'
                          : 'elements'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Favorite element',
                    padding: EdgeInsets.zero,
                    onPressed: () => s.preferences.favoriteElement(e.number),
                    icon: Icon(
                      s.preferences.favoriteElements.contains(e.number)
                          ? Icons.star
                          : Icons.star_border,
                      color: cyan,
                      size: 18,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next element',
                    padding: EdgeInsets.zero,
                    onPressed: () => _selectAdjacent(1),
                    icon: const Icon(Icons.chevron_right, size: 19),
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  setState(() => inspectorFraction = collapsed ? .39 : .14),
              onVerticalDragUpdate: (d) => setState(
                () => inspectorFraction =
                    (inspectorFraction - d.delta.dy / screenHeight).clamp(
                      .14,
                      .65,
                    ),
              ),
              onVerticalDragEnd: (_) => _refresh(
                () => inspectorFraction = [.14, .39, .62].reduce(
                  (a, b) =>
                      (a - inspectorFraction).abs() <
                          (b - inspectorFraction).abs()
                      ? a
                      : b,
                ),
              ),
              child: SizedBox(
                height: 23,
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xff6097d0),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: cyan.withValues(alpha: .1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 1, 14, 12),
                child: NeonSurface(
                  radius: 18,
                  padding: const EdgeInsets.all(9),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => _details(e, s),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 42,
                              child: SizedBox(
                                height: collapsed ? 45 : 124,
                                child: NeonSurface(
                                  radius: 14,
                                  padding: EdgeInsets.zero,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: e.number == 6
                                            ? MoleculeView(
                                                molecule: s.data.presets
                                                    .firstWhere(
                                                      (m) =>
                                                          m.name == 'Methane',
                                                    ),
                                                camera: camera,
                                                grid: false,
                                              )
                                            : CustomPaint(
                                                painter: AtomPainter(
                                                  e,
                                                  .2,
                                                  1,
                                                  false,
                                                  false,
                                                ),
                                              ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: InkWell(
                                          onTap: () => _atom(e),
                                          child: NeonSurface(
                                            radius: 8,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 3,
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.view_in_ar_outlined,
                                                  size: 12,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  '3D',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: IconButton(
                                          tooltip: 'Expand atom viewer',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => _atom(e),
                                          icon: const Icon(
                                            Icons.open_in_full,
                                            size: 12,
                                            color: muted,
                                          ),
                                        ),
                                      ),
                                      if (!collapsed)
                                        Positioned(
                                          bottom: 7,
                                          left: 0,
                                          right: 0,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              for (var i = 0; i < 4; i++)
                                                Container(
                                                  width: 5,
                                                  height: 5,
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: i == 0
                                                        ? cyan
                                                        : const Color(
                                                            0xff315780,
                                                          ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              flex: 58,
                              child: Stack(
                                children: [
                                  if (!collapsed)
                                    Positioned(
                                      right: 0,
                                      top: 27,
                                      child: IgnorePointer(
                                        child: Opacity(
                                          opacity: .7,
                                          child: CustomPaint(
                                            size: const Size(82, 82),
                                            painter: ShellIllustration(
                                              (e.data['shells'] as List)
                                                  .cast<int>(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${e.number}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: muted,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xff0c305c),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: const Color(0xff27578b),
                                              ),
                                            ),
                                            child: Text(
                                              _shortCategory(e.category),
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: categoryColor(
                                                  e.category,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        e.symbol,
                                        style: TextStyle(
                                          fontSize: collapsed ? 28 : 37,
                                          height: 1.08,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xff3bbaff),
                                          shadows: [
                                            Shadow(
                                              color: const Color(0xff068dff)
                                                  .withValues(alpha: .6),
                                              blurRadius: 15,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        e.name,
                                        style: const TextStyle(
                                          fontSize: 19,
                                          height: 1.12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${e.mass} u',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: muted,
                                        ),
                                      ),
                                      if (!collapsed) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          _elementCaption(e),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            height: 1.3,
                                            color: muted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!collapsed) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final key
                                in s.preferences.pinnedProperties.take(3))
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: _pinCard(key, e),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            _inspectorAction(
                              Icons.info_outline,
                              'Details',
                              () => _details(e, s),
                            ),
                            _inspectorAction(
                              Icons.blur_circular,
                              'Isotopes',
                              () => _isotopes(e),
                            ),
                            _inspectorAction(
                              Icons.trending_up,
                              'Trends',
                              _trends,
                            ),
                            _inspectorAction(Icons.balance, 'Compare', () {
                              setState(() => comparing = !comparing);
                            }),
                            _inspectorAction(
                              Icons.hub_outlined,
                              'Use atom',
                              () {
                                _handoff(e, s);
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fact(IconData icon, String label, String value) => NeonSurface(
    radius: 9,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 21, color: const Color(0xff62b4ff)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 7, color: muted),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _inspectorAction(IconData icon, String label, VoidCallback tap) =>
      TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size(45, 32),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: tap,
        icon: Icon(icon, size: 13),
        label: Text(label, style: const TextStyle(fontSize: 9)),
      );
  String _shortCategory(String c) => switch (c) {
    'diatomic nonmetal' || 'polyatomic nonmetal' => 'Nonmetal',
    'alkaline earth metal' => 'Alkaline earth',
    _ => c[0].toUpperCase() + c.substring(1),
  };
  String _elementCaption(ElementData e) => e.number == 6
      ? 'Carbon forms the backbone of organic compounds and is essential to life.'
      : '${e.name} · ${e.data['phase']} at standard conditions. Explore its electron configuration, isotopes and periodic properties.';
  String _superscript(String configuration) => configuration.replaceAllMapped(
    RegExp(r'([spdf])(\d+)'),
    (m) =>
        '${m[1]}${m[2]!.split('').map((d) => '⁰¹²³⁴⁵⁶⁷⁸⁹'[int.parse(d)]).join()}',
  );
  Widget _tile(ElementData e, StudioStore s) {
    final match =
        (categoryFilters.isEmpty || categoryFilters.contains(e.category)) &&
        (group == null || e.data['group'] == group) &&
        (period == null || e.data['period'] == period);
    var color = categoryColor(e.category);
    if (trend != null) {
      final values = s.data.elements.map(value).whereType<double>().toList();
      final v = value(e);
      if (v == null) {
        color = Colors.blueGrey;
      } else {
        final min = values.reduce(math.min), max = values.reduce(math.max);
        color = Color.lerp(
          const Color(0xff163451),
          cyan,
          max == min ? .5 : (v - min) / (max - min),
        )!;
      }
    }
    final active =
        e.number == s.selectedElement ||
        (comparing && compared.contains(e.number));
    return Positioned(
      left: 28 + (e.column - 1) * 45.0,
      top: 29 + (e.row - 1) * 53.0,
      width: 42,
      height: 49,
      child: Opacity(
        opacity: match ? (trend == null ? 1 : heatIntensity) : .16,
        child: Tooltip(
          message:
              '${e.number} · ${e.name}${trend == null ? '' : ' · ${value(e)?.toStringAsPrecision(4) ?? 'Unavailable'}'}',
          child: Semantics(
            label:
                '${e.name}, atomic number ${e.number}, ${e.category}, atomic mass ${e.mass} unified atomic mass units',
            selected: active,
            button: true,
            child: InkWell(
              onTap: () {
                if (comparing) {
                  setState(() {
                    if (compared.contains(e.number)) {
                      compared.remove(e.number);
                    } else if (compared.length < 4) {
                      compared.add(e.number);
                    }
                  });
                  return;
                }
                if (s.selectedElement == e.number) {
                  _details(e, s);
                } else {
                  s.selectElement(e.number);
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(
                        alpha: .34 * (trend == null ? 1 : heatIntensity),
                      ),
                      const Color(0xff031023),
                      color.withValues(alpha: .13),
                    ],
                  ),
                  border: Border.all(
                    color: active ? const Color(0xff72e5ff) : color,
                    width: active ? 1.7 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (active ? cyan : color).withValues(
                        alpha: (active ? .48 : .12) * s.preferences.glow,
                      ),
                      blurRadius: active ? 12 : 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ElementOrb(color: color, seed: e.number),
                        ),
                      ),
                      Positioned(
                        left: 4,
                        top: 3,
                        child: Text(
                          '${e.number}',
                          style: TextStyle(
                            color: Color.lerp(color, Colors.white, .45),
                            fontSize: 8,
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.only(
                            top:
                                (showNames &&
                                    (!semanticZoom || detailLevel > 0))
                                ? 1
                                : 6,
                          ),
                          child: Text(
                            e.symbol,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 3),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (s.preferences.patterns)
                        Positioned(
                          right: 3,
                          top: 3,
                          child: Text(
                            _categoryTag(e.category),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 6.5,
                            ),
                          ),
                        ),
                      if (semanticZoom && detailLevel == 2)
                        Positioned(
                          left: 1,
                          right: 1,
                          bottom: 2,
                          child: Text(
                            '${e.mass} u',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 5.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (showNames && (!semanticZoom || detailLevel > 0))
                        Positioned(
                          left: 1,
                          right: 1,
                          bottom: semanticZoom && detailLevel == 2 ? 12 : 4,
                          child: Text(
                            e.name,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 6.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _search(StudioStore s) async {
    search.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .8,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  TextField(
                    controller: search,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Name, symbol or atomic number',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => update(() {}),
                  ),
                  if (search.text.isEmpty)
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final n in s.preferences.recentElements)
                          ActionChip(
                            label: Text(s.data.element(n).symbol),
                            onPressed: () {
                              s.selectElement(n);
                              Navigator.pop(context);
                              _focus(s.data.element(n));
                            },
                          ),
                      ],
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final e in s.data.elements.where(
                          (e) => '${e.name} ${e.symbol} ${e.number}'
                              .toLowerCase()
                              .contains(search.text.toLowerCase()),
                        ))
                          ListTile(
                            leading: SizedBox(
                              width: 44,
                              height: 44,
                              child: NeonSurface(
                                padding: const EdgeInsets.all(3),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${e.number}',
                                      style: const TextStyle(
                                        fontSize: 7,
                                        height: 1,
                                      ),
                                    ),
                                    Text(
                                      e.symbol,
                                      style: TextStyle(
                                        color: categoryColor(e.category),
                                        fontSize: 16,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            title: Text(e.name),
                            subtitle: Text(
                              '${e.number} · ${e.mass} u · ${e.category}',
                            ),
                            onTap: () {
                              s.selectElement(e.number);
                              Navigator.pop(context);
                              _focus(e);
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

  void _details(ElementData e, StudioStore s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        maxChildSize: .94,
        minChildSize: .35,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(22),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${e.symbol}  ${e.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Favorite element',
                  onPressed: () => s.preferences.favoriteElement(e.number),
                  icon: Icon(
                    s.preferences.favoriteElements.contains(e.number)
                        ? Icons.star
                        : Icons.star_border,
                    color: cyan,
                  ),
                ),
              ],
            ),
            const Chip(
              avatar: Icon(Icons.info_outline, size: 14),
              label: Text(
                'Reference · uncertainty unspecified',
                style: TextStyle(fontSize: 10),
              ),
            ),
            Text(
              '${e.symbol}  ${e.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            PropertyRow('Atomic number', '${e.number}'),
            PropertyRow('Relative atomic mass', '${e.mass} u'),
            PropertyRow('Classification', e.category),
            PropertyRow('Electron configuration', e.configuration),
            PropertyRow(
              'Common oxidation states',
              (e.data['oxidation_states'] as List).isEmpty
                  ? 'Unavailable'
                  : (e.data['oxidation_states'] as List).join(', '),
            ),
            for (final ionic in (e.data['ionic_radii'] as List))
              PropertyRow(
                'Ionic radius (${ionic['charge']}, CN ${ionic['coordination']} ${ionic['spin']})',
                '${ionic['ionic_radius']} pm',
              ),
            PropertyRow(
              'Outer shell electrons',
              '${(e.data['shells'] as List).last} (shell count)',
            ),
            for (final pair in [
              ('electronegativity_pauling', 'Electronegativity', 'Pauling'),
              ('melt', 'Melting point', 'K'),
              ('boil', 'Boiling point', 'K'),
              ('density_g_cm3', 'Density', 'g/cm³'),
              ('electron_affinity', 'Electron affinity', 'kJ/mol'),
            ])
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PropertyRow(
                    pair.$2,
                    e.property(pair.$1) == null
                        ? 'Unavailable'
                        : '${e.property(pair.$1)} ${pair.$3}',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: line),
                      ),
                      child: Text(
                        e.valueQuality(pair.$1),
                        style: TextStyle(
                          fontSize: 9,
                          color: e.valueQuality(pair.$1) == 'Estimated'
                              ? Colors.amber
                              : muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            PropertyRow(
              'First ionization energy',
              (e.data['ionization_energies'] as List).isEmpty
                  ? 'Unavailable'
                  : '${(e.data['ionization_energies'] as List).first} kJ/mol',
            ),
            PropertyRow(
              'Empirical atomic radius',
              '${(e.data['atomic_radii'] as Map?)?['empirical'] ?? 'Unavailable'} pm',
            ),
            const SizedBox(height: 16),
            const Text(
              'Reference dataset: Bowserinator Periodic-Table-JSON (CC BY-SA 3.0). Values carry the source dataset’s uncertainty; missing values remain unavailable. Masses in brackets in primary references are isotope mass numbers, not standard atomic weights.',
              style: TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _handoff(e, s);
              },
              icon: const Icon(Icons.hub),
              label: const Text('Use in Molecule Studio'),
            ),
          ],
        ),
      ),
    );
  }

  void _trends() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Periodic Trends',
              style: TextStyle(fontSize: 22, color: Colors.white),
            ),
            const SizedBox(height: 12),
            for (final key in trendKeys.keys)
              ListTile(
                title: Text(key),
                trailing: const Icon(Icons.gradient, color: cyan),
                onTap: () {
                  setState(() => trend = key);
                  Navigator.pop(context);
                },
              ),
            const Text(
              'Atomic radii use the empirical definition. Ionic radii specify charge and coordination; missing values stay gray.',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _compare(StudioStore s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Element comparison',
                  style: TextStyle(fontSize: 22, color: Colors.white),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final n in compared)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: SizedBox(
                            width: 220,
                            child: Panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${s.data.element(n).symbol} · ${s.data.element(n).name}',
                                    style: const TextStyle(
                                      color: cyan,
                                      fontSize: 20,
                                    ),
                                  ),
                                  PropertyRow(
                                    'Mass',
                                    '${s.data.element(n).mass} u',
                                  ),
                                  for (final key in trendKeys.keys)
                                    SizedBox(
                                      height: 88,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            key,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                          PropertyRow(
                                            'Value',
                                            _trendValue(
                                                  s.data.element(n),
                                                  key,
                                                )?.toStringAsPrecision(5) ??
                                                'Unavailable',
                                          ),
                                          if (_trendValue(
                                                s.data.element(n),
                                                key,
                                              ) !=
                                              null)
                                            LinearProgressIndicator(
                                              value:
                                                  (_trendValue(
                                                            s.data.element(n),
                                                            key,
                                                          )!.abs() /
                                                          math.max(
                                                            .0001,
                                                            compared
                                                                .map(
                                                                  (other) =>
                                                                      _trendValue(
                                                                        s.data.element(
                                                                          other,
                                                                        ),
                                                                        key,
                                                                      )?.abs() ??
                                                                      0,
                                                                )
                                                                .reduce(
                                                                  math.max,
                                                                ),
                                                          ))
                                                      .clamp(0, 1),
                                              color: categoryColor(
                                                s.data.element(n).category,
                                              ),
                                              backgroundColor: line,
                                              minHeight: 4,
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Bars compare magnitudes within each property. Signs and units are retained above. CN = coordination number; ionic radii use high spin where specified.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double? _trendValue(ElementData e, String key) {
    if (trendKeys[key] == 'ionization') {
      final list = e.data['ionization_energies'] as List;
      return list.isEmpty ? null : (list.first as num).toDouble();
    }
    return e.property(trendKeys[key]!);
  }

  void _filters() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 5,
                children: [
                  for (var i = 1; i <= 18; i++)
                    ActionChip(
                      label: Text('G$i'),
                      onPressed: () {
                        setState(() => group = group == i ? null : i);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              Wrap(
                spacing: 5,
                children: [
                  for (var i = 1; i <= 7; i++)
                    ActionChip(
                      label: Text('P$i'),
                      onPressed: () {
                        setState(() => period = period == i ? null : i);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    group = null;
                    period = null;
                    category = null;
                    categoryFilters.clear();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Clear highlights'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _isotopes(ElementData e) {
    final records = ref.read(studioProvider).data.records('isotopes', e.number);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '${e.name} isotopes',
                  style: const TextStyle(fontSize: 23, color: Colors.white),
                ),
                const Text(
                  'Mendeleev dataset · abundance in % · tap to model nucleus',
                  style: TextStyle(fontSize: 10),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final iso in records)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ActionChip(
                            avatar: Icon(
                              iso['is_radioactive'] == 0
                                  ? Icons.check_circle_outline
                                  : Icons.timelapse,
                              size: 14,
                            ),
                            label: Text('${iso['mass_number']}'),
                            onPressed: () {
                              Navigator.pop(context);
                              _atom(e, mass: iso['mass_number'] as int);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final iso in records)
                        ListTile(
                          title: Text(
                            '${e.symbol}-${iso['mass_number']} · ${e.number} p⁺ · ${(iso['mass_number'] as int) - e.number} n',
                          ),
                          subtitle: Text(
                            '${iso['is_radioactive'] == 1 ? 'Radioactive' : 'Stable'} · abundance ${iso['abundance'] ?? 'unavailable'}${iso['abundance'] == null ? '' : '%'}\nHalf-life: ${iso['is_radioactive'] == 0
                                ? 'stable'
                                : iso['half_life'] == null
                                ? 'unavailable'
                                : '${iso['half_life']} ${iso['half_life_unit']}'}',
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _atom(e, mass: iso['mass_number'] as int);
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
    );
  }

  void _atom(ElementData e, {int? mass}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AtomExplorer(element: e, mass: mass),
    );
  }
}

class AtomExplorer extends StatefulWidget {
  final ElementData element;
  final int? mass;
  const AtomExplorer({super.key, required this.element, this.mass});
  @override
  State<AtomExplorer> createState() => _AtomExplorerState();
}

class _AtomExplorerState extends State<AtomExplorer> {
  double rotation = 0, zoom = 1;
  bool quantum = false, labels = true;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '${widget.element.name} · Atom explorer',
              style: const TextStyle(fontSize: 22, color: Colors.white),
            ),
            SwitchListTile(
              title: const Text('Quantum probability illustration'),
              value: quantum,
              onChanged: (v) => setState(() => quantum = v),
            ),
            Expanded(
              child: GestureDetector(
                onScaleUpdate: (d) => setState(() {
                  rotation += d.focalPointDelta.dx * .01;
                  zoom = (zoom * d.scale).clamp(.5, 2);
                }),
                child: CustomPaint(
                  painter: AtomPainter(
                    widget.element,
                    rotation,
                    zoom,
                    quantum,
                    labels,
                    widget.mass,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
            Text(
              quantum
                  ? 'Schematic 1s-like probability cloud; not this element’s complete orbital solution.'
                  : 'Schematic electron shells; electrons do not follow literal planetary orbits.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
            PropertyRow('Protons', '${widget.element.number}'),
            PropertyRow(
              'Neutrons',
              widget.mass == null
                  ? 'Choose a supported isotope'
                  : '${widget.mass! - widget.element.number}',
            ),
            PropertyRow('Electrons', '${widget.element.number} (neutral)'),
            Text(widget.element.configuration),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    rotation = 0;
                    zoom = 1;
                  }),
                  child: const Text('Reset view'),
                ),
                TextButton(
                  onPressed: () => setState(() => labels = !labels),
                  child: Text(labels ? 'Hide labels' : 'Show labels'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class AtomPainter extends CustomPainter {
  final ElementData e;
  final double rotation, zoom;
  final bool quantum, labels;
  final int? mass;
  AtomPainter(
    this.e,
    this.rotation,
    this.zoom,
    this.quantum,
    this.labels, [
    this.mass,
  ]);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2),
        r = math.min(size.width, size.height) * .36 * zoom;
    final shells = e.data['shells'] as List;
    if (quantum) {
      final random = math.Random(42);
      for (var i = 0; i < 1600; i++) {
        final theta = random.nextDouble() * math.pi * 2,
            rad = -math.log(1 - random.nextDouble()) * r * .23;
        canvas.drawCircle(
          center +
              Offset(
                math.cos(theta + rotation) * rad,
                math.sin(theta + rotation) * rad * .85,
              ),
          1.2,
          Paint()..color = cyan.withValues(alpha: .18),
        );
      }
    } else {
      for (var s = 0; s < shells.length; s++) {
        final radius = r * (s + 1) / shells.length;
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(rotation + s * .18);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * 2,
            height: radius * 1.4,
          ),
          Paint()
            ..color = line
            ..style = PaintingStyle.stroke,
        );
        for (var i = 0; i < (shells[s] as int); i++) {
          final a = i * math.pi * 2 / (shells[s] as int) + rotation;
          canvas.drawCircle(
            Offset(math.cos(a) * radius, math.sin(a) * radius * .7),
            3,
            Paint()..color = cyan,
          );
        }
        canvas.restore();
      }
    }
    canvas.drawCircle(
      center,
      16,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xff7ad9ff), Color(0xff074bb5)],
        ).createShader(Rect.fromCircle(center: center, radius: 16)),
    );
    if (mass != null) {
      for (var i = 0; i < mass!; i++) {
        final radius = math.sqrt((i + .5) / mass!) * 23,
            theta = i * 2.39996 + rotation;
        canvas.drawCircle(
          center + Offset(math.cos(theta), math.sin(theta)) * radius,
          2.6,
          Paint()
            ..color = i < e.number
                ? const Color(0xfff35e7b)
                : const Color(0xff6dd6ff),
        );
      }
    }
    if (labels) {
      final text = TextPainter(
        text: TextSpan(
          text: '${e.number} p⁺',
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, center - Offset(text.width / 2, 5));
    }
  }

  @override
  bool shouldRepaint(covariant AtomPainter oldDelegate) => true;
}

class _EmptyCellsPainter extends CustomPainter {
  final List<ElementData> elements;
  _EmptyCellsPainter(this.elements);
  @override
  void paint(Canvas canvas, Size size) {
    final occupied = elements.map((e) => '${e.column}:${e.row}').toSet();
    final paint = Paint()
      ..color = const Color(0xff13406a).withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .4;
    for (var row = 1; row <= 7; row++) {
      for (var col = 1; col <= 18; col++) {
        if (occupied.contains('$col:$row')) {
          continue;
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(28 + (col - 1) * 45.0, 29 + (row - 1) * 53.0, 42, 49),
            const Radius.circular(6),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EmptyCellsPainter oldDelegate) => false;
}
