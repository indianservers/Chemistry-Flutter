part of 'periodic_table.dart';

extension _PeriodicTools on _PeriodicState {
  void _refresh(VoidCallback fn) {
    _apply(fn);
    _remember();
  }

  void _remember() {
    final prefs = workspaceStore.preferences;
    prefs.setPeriodic({
      'matrix': transform.value.storage.toList(),
      'categories': categoryFilters.toList(),
      'group': group,
      'period': period,
      'trend': trend,
      'inspector': inspectorFraction,
      'dock': dockTop ? 'top' : 'bottom',
      'compact': compactDock,
      'minimap': minimap,
      'semantic': semanticZoom,
      'intensity': heatIntensity,
    });
  }

  void _viewChanged() {
    final scale = transform.value.getMaxScaleOnAxis();
    final level = scale < .55
        ? 0
        : scale < 1.6
        ? 1
        : 2;
    if (level != detailLevel && mounted) {
      _apply(() => detailLevel = level);
    }
    rememberTimer?.cancel();
    rememberTimer = Timer(const Duration(milliseconds: 300), _remember);
  }

  void _restoreWorkspace() {
    final state = ref.read(studioProvider).preferences.periodic;
    if (state['matrix'] is List && (state['matrix'] as List).length == 16) {
      transform.value = Matrix4.fromList(
        (state['matrix'] as List).map((n) => (n as num).toDouble()).toList(),
      );
    }
    categoryFilters.addAll((state['categories'] as List? ?? []).cast<String>());
    group = state['group'] as int?;
    period = state['period'] as int?;
    trend = state['trend'] as String?;
    inspectorFraction = (state['inspector'] as num? ?? .39).toDouble().clamp(
      .14,
      .65,
    );
    dockTop = state['dock'] == 'top';
    compactDock = state['compact'] == true;
    minimap = state['minimap'] == true;
    semanticZoom = state['semantic'] != false;
    heatIntensity = (state['intensity'] as num? ?? 1).toDouble();
  }

  void _animateFocus(ElementData e) {
    final scale = math.max(.9, transform.value.getMaxScaleOnAxis());
    final point = Offset(49 + (e.column - 1) * 45, 54 + (e.row - 1) * 53);
    final offset =
        Offset(viewport.width / 2, math.max(40, (viewport.height - 60) / 2)) -
        point * scale;
    final target = Matrix4.identity()
      ..translateByDouble(offset.dx, offset.dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
    if (ref.read(studioProvider).preferences.reducedMotion) {
      transform.value = target;
      return;
    }
    viewAnimation.stop();
    viewTween = Matrix4Tween(begin: transform.value.clone(), end: target);
    viewAnimation.forward(from: 0);
  }

  void _selectAdjacent(int delta) {
    final s = ref.read(studioProvider);
    var n = s.selectedElement + delta;
    if (group != null || period != null) {
      final candidates = s.data.elements
          .where(
            (e) =>
                (group == null || e.data['group'] == group) &&
                (period == null || e.data['period'] == period),
          )
          .map((e) => e.number)
          .toList();
      final index = candidates.indexOf(s.selectedElement);
      if (candidates.isNotEmpty) {
        n = candidates[((index < 0 ? 0 : index) + delta) % candidates.length];
      }
    }
    n = n.clamp(1, 118);
    s.selectElement(n);
    _animateFocus(s.data.element(n));
  }

  void _preset(String name) {
    switch (name) {
      case 'Entire table':
        _fit();
      case 'Main groups':
        _setView(.8, Offset.zero);
      case 'Detached series':
        _setView(.9, const Offset(-50, -370));
    }
    _remember();
  }

  Future<void> _handoff(ElementData e, StudioStore s) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${e.symbol} · ${e.name}',
                  style: const TextStyle(fontSize: 24, color: cyan),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Make this element available in the molecular editor. Your molecule will stay intact; choose a parent atom before placing a connected atom.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    s.chooseAtom(e.number);
                    Navigator.pop(context);
                    this.context.go('/molecule');
                  },
                  icon: const Icon(Icons.hub_outlined),
                  label: Text('Use ${e.name} in Molecule Studio'),
                ),
              ],
            ),
          ),
        ),
      );
  void _shelf() {
    final s = ref.read(studioProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListenableBuilder(
          listenable: s.preferences,
          builder: (context, _) => ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Favorite elements', style: TextStyle(fontSize: 22)),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in s.preferences.favoriteElements)
                    InputChip(
                      label: Text(
                        '${s.data.element(n).symbol} · ${s.data.element(n).name}',
                      ),
                      onPressed: () {
                        s.selectElement(n);
                        Navigator.pop(context);
                        _animateFocus(s.data.element(n));
                      },
                      onDeleted: () => s.preferences.favoriteElement(n),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Recently explored'),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in s.preferences.recentElements)
                    ActionChip(
                      label: Text(s.data.element(n).symbol),
                      onPressed: () {
                        s.selectElement(n);
                        Navigator.pop(context);
                        _animateFocus(s.data.element(n));
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _workspaceTools() {
    final s = ref.read(studioProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: StatefulBuilder(
            builder: (context, update) => ListenableBuilder(
              listenable: transform,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Table workspace', style: TextStyle(fontSize: 22)),
                  Text(
                    'Scale ${(transform.value.getMaxScaleOnAxis() * 100).round()}%',
                  ),
                  Slider(
                    label: 'Table scale',
                    min: .08,
                    max: 4,
                    value: transform.value.getMaxScaleOnAxis().clamp(.08, 4),
                    onChanged: (v) =>
                        _zoom(v / transform.value.getMaxScaleOnAxis()),
                  ),
                  Wrap(
                    spacing: 7,
                    children: [
                      for (final name in [
                        'Entire table',
                        'Main groups',
                        'Detached series',
                      ])
                        ActionChip(
                          label: Text(name),
                          onPressed: () => _preset(name),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Table minimap'),
                    value: minimap,
                    onChanged: (v) {
                      _refresh(() => minimap = v);
                      update(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Semantic zoom details'),
                    subtitle: const Text(
                      'Symbols → names → atomic masses as you zoom in.',
                    ),
                    value: semanticZoom,
                    onChanged: (v) {
                      _refresh(() => semanticZoom = v);
                      update(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Control dock at top'),
                    value: dockTop,
                    onChanged: (v) {
                      _refresh(() => dockTop = v);
                      update(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Compact control dock'),
                    subtitle: const Text(
                      'Keep zoom, fit and focus visible; reset remains in Table options.',
                    ),
                    value: compactDock,
                    onChanged: (v) {
                      _refresh(() => compactDock = v);
                      update(() {});
                    },
                  ),
                  const Text('Inspector position'),
                  Wrap(
                    spacing: 7,
                    children: [
                      for (final snap in [
                        ('Collapsed', .14),
                        ('Summary', .39),
                        ('Expanded', .62),
                      ])
                        ChoiceChip(
                          label: Text(snap.$1),
                          selected: (inspectorFraction - snap.$2).abs() < .04,
                          onSelected: (_) {
                            _refresh(() => inspectorFraction = snap.$2);
                            update(() {});
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Pinned property cards · choose up to three'),
                  for (final key in [
                    'configuration',
                    'shell',
                    'position',
                    'mass',
                    'phase',
                  ])
                    CheckboxListTile(
                      title: Text(
                        {
                          'configuration': 'Electron configuration',
                          'shell': 'Outer shell electrons',
                          'position': 'Group / period',
                          'mass': 'Atomic mass (u)',
                          'phase': 'Phase',
                        }[key]!,
                      ),
                      value: s.preferences.pinnedProperties.contains(key),
                      onChanged: (v) {
                        final pins = s.preferences.pinnedProperties;
                        if (v == true && pins.length < 3) {
                          pins.add(key);
                        } else if (v == false && pins.length > 1) {
                          pins.remove(key);
                        }
                        s.preferences.persist();
                        _refresh(() {});
                        update(() {});
                      },
                    ),
                  const SizedBox(height: 12),
                  Text('Heatmap intensity ${(heatIntensity * 100).round()}%'),
                  Slider(
                    min: .2,
                    max: 1,
                    value: heatIntensity,
                    onChanged: (v) {
                      _refresh(() => heatIntensity = v);
                      update(() {});
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        showViewingPreferences(this.context, s.preferences),
                    icon: const Icon(Icons.accessibility_new),
                    label: const Text('Viewing & accessibility'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _minimap() => ListenableBuilder(
    listenable: transform,
    builder: (context, _) => GestureDetector(
      onTapDown: (d) {
        final scale = transform.value.getMaxScaleOnAxis();
        final point = Offset(
          d.localPosition.dx / 112 * _PeriodicState.tableSize.width,
          d.localPosition.dy / 76 * _PeriodicState.tableSize.height,
        );
        _setView(scale, viewport.center(Offset.zero) - point * scale);
      },
      child: Semantics(
        label: 'Periodic table minimap. Tap to move the viewport.',
        button: true,
        child: NeonSurface(
          radius: 9,
          padding: EdgeInsets.zero,
          child: CustomPaint(
            size: const Size(112, 76),
            painter: _TableMapPainter(
              ref.read(studioProvider).data.elements,
              transform.value,
              viewport,
              _PeriodicState.tableSize,
            ),
          ),
        ),
      ),
    ),
  );
  Widget _trendScale(StudioStore s) {
    final values = s.data.elements.map(value).whereType<double>().toList();
    if (values.isEmpty) {
      return const Text('No values available for this property');
    }
    return Row(
      children: [
        Text(
          values.reduce(math.min).toStringAsPrecision(3),
          style: const TextStyle(fontSize: 9),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 6,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xff163451), cyan]),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          values.reduce(math.max).toStringAsPrecision(3),
          style: const TextStyle(fontSize: 9),
        ),
        const SizedBox(width: 8),
        const Text('gray: unavailable', style: TextStyle(fontSize: 9)),
      ],
    );
  }

  Widget _comparisonTray() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final n in compared)
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: InputChip(
              label: Text(ref.read(studioProvider).data.element(n).symbol),
              onDeleted: () => _refresh(() => compared.remove(n)),
            ),
          ),
      ],
    ),
  );
  String _categoryTag(String c) => switch (c) {
    'alkali metal' => 'Alk',
    'alkaline earth metal' => 'AE',
    'transition metal' => 'Tr',
    'post-transition metal' => 'Post',
    'metalloid' => 'Met',
    'diatomic nonmetal' => 'ND',
    'polyatomic nonmetal' => 'NP',
    'halogen' => 'Hal',
    'noble gas' => 'NG',
    'lanthanide' => 'Ln',
    'actinide' => 'An',
    _ => '?',
  };
  Widget _pinCard(String key, ElementData e) => switch (key) {
    'mass' => _fact(Icons.scale_outlined, 'Atomic mass', '${e.mass} u'),
    'phase' => _fact(Icons.water_drop_outlined, 'Phase', '${e.data['phase']}'),
    'shell' => _fact(
      Icons.hub_outlined,
      'Outer shell',
      '${(e.data['shells'] as List).last} e⁻',
    ),
    'position' => _fact(
      Icons.diamond_outlined,
      'Group / Period',
      '${e.data['group']} / ${e.data['period']}',
    ),
    _ => _fact(
      Icons.layers_outlined,
      'Electron configuration',
      _superscript(e.configuration),
    ),
  };
}

class _TableMapPainter extends CustomPainter {
  final List<ElementData> elements;
  final Matrix4 matrix;
  final Size viewport, scene;
  _TableMapPainter(this.elements, this.matrix, this.viewport, this.scene);
  @override
  void paint(Canvas c, Size size) {
    final sx = size.width / scene.width, sy = size.height / scene.height;
    for (final e in elements) {
      c.drawRect(
        Rect.fromLTWH(
          (28 + (e.column - 1) * 45) * sx,
          (29 + (e.row - 1) * 53) * sy,
          40 * sx,
          47 * sy,
        ),
        Paint()..color = categoryColor(e.category),
      );
    }
    final scale = matrix.getMaxScaleOnAxis();
    final rect = Rect.fromLTWH(
      -matrix.storage[12] / scale * sx,
      -matrix.storage[13] / scale * sy,
      viewport.width / scale * sx,
      viewport.height / scale * sy,
    ).intersect(Offset.zero & size);
    c.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TableMapPainter oldDelegate) => true;
}

class _StickyLabelsPainter extends CustomPainter {
  final Matrix4 matrix;
  _StickyLabelsPainter(this.matrix);
  @override
  void paint(Canvas c, Size size) {
    final scale = matrix.getMaxScaleOnAxis();
    void label(String s, Offset p) {
      final t = TextPainter(
        text: TextSpan(
          text: s,
          style: const TextStyle(
            fontSize: 10,
            color: muted,
            backgroundColor: background,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(c, p);
    }

    if (matrix.storage[13] < -10) {
      for (var i = 1; i <= 18; i++) {
        final x = matrix.storage[12] + (30 + (i - 1) * 45) * scale;
        if (x > 0 && x < size.width - 10) {
          label('$i', Offset(x, 0));
        }
      }
    }
    if (matrix.storage[12] < -10) {
      for (var i = 1; i <= 7; i++) {
        final y = matrix.storage[13] + (42 + (i - 1) * 53) * scale;
        if (y > 10 && y < size.height - 45) {
          label('$i', Offset(0, y));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StickyLabelsPainter oldDelegate) => true;
}
