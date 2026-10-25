part of 'molecule_studio.dart';

extension _MoleculeTools on _MoleculeState {
  void _setMode(InteractionMode value) {
    _apply(() {
      interaction = value;
      if (MediaQuery.sizeOf(context).height < 700 &&
          (value == InteractionMode.move || value == InteractionMode.measure)) {
        inspectorSnap = 0;
      }
      connecting = value == InteractionMode.addBond;
      ghost = null;
      pendingBond = null;
      measureSelection.clear();
    });
  }

  void _pickAtom(int? id) {
    final s = ref.read(studioProvider);
    if (id == null) {
      s.selectAtom(null);
      return;
    }
    if (interaction == InteractionMode.measure) {
      _apply(() {
        if (measureSelection.contains(id)) {
          measureSelection.remove(id);
        } else if (measureSelection.length < measurementCount) {
          measureSelection.add(id);
        }
      });
      s.selectAtom(id);
      return;
    }
    if (interaction == InteractionMode.addBond) {
      if (s.selectedAtom != null && s.selectedAtom != id) {
        _apply(() => pendingBond = Bond(s.selectedAtom!, id, s.bondOrder));
      } else {
        s.selectAtom(id);
      }
      return;
    }
    s.selectAtom(id);
    _apply(() => selectedBond = null);
  }

  int get measurementCount => measurementKind == 'Length'
      ? 2
      : measurementKind == 'Angle'
      ? 3
      : 4;
  void _beginPlacement() {
    final s = ref.read(studioProvider);
    final parent = s.selectedAtom == null
        ? null
        : s.molecule.atom(s.selectedAtom!);
    _apply(() {
      interaction = InteractionMode.addAtom;
      if (MediaQuery.sizeOf(context).height < 700) {
        inspectorSnap = 0;
      }
      ghost = Atom(
        -1,
        s.atomType,
        (parent?.x ?? -1.5) + 1.5,
        (parent?.y ?? 0) + .7,
        parent?.z ?? 0,
      );
    });
  }

  void _commitPlacement() {
    final s = ref.read(studioProvider);
    if (ghost == null) {
      return;
    }
    final id = s.molecule.atoms.fold(0, (v, a) => math.max(v, a.id)) + 1;
    final parent = s.selectedAtom;
    s.edit(
      s.molecule.copy(
        atoms: [
          ...s.molecule.atoms,
          Atom(id, s.atomType, ghost!.x, ghost!.y, ghost!.z),
        ],
        bonds: [
          ...s.molecule.bonds,
          if (parent != null) Bond(parent, id, s.bondOrder),
        ],
      ),
      label: 'Place ${s.data.element(s.atomType).symbol}',
    );
    s.selectAtom(id);
    _apply(() {
      ghost = null;
      interaction = InteractionMode.select;
    });
  }

  void _moveAtom(Vector3 delta) {
    final s = ref.read(studioProvider);
    final id = s.selectedAtom;
    if (id == null) {
      return;
    }
    final mask = switch (moveAxis) {
      'X' => Vector3(delta.x, 0, 0),
      'Y' => Vector3(0, delta.y, 0),
      'Z' => Vector3(0, 0, delta.length * (delta.x + delta.y >= 0 ? 1 : -1)),
      'XY' => Vector3(delta.x, delta.y, 0),
      'XZ' => Vector3(delta.x, 0, delta.z + delta.y),
      'YZ' => Vector3(0, delta.y, delta.z + delta.x),
      _ => delta,
    };
    final current = movingPreview ?? s.molecule;
    _apply(
      () => movingPreview = current.copy(
        atoms: current.atoms
            .map((a) => a.id == id ? a.copy(position: a.position + mask) : a)
            .toList(),
      ),
    );
  }

  void _commitMove() {
    final s = ref.read(studioProvider);
    if (movingPreview == null) {
      return;
    }
    final id = s.selectedAtom;
    s.edit(movingPreview!, label: 'Move atom $id ($moveAxis)');
    s.selectAtom(id);
    _apply(() => movingPreview = null);
  }

  void _deleteAtom() {
    final s = ref.read(studioProvider);
    if (s.selectedAtom == null) {
      return;
    }
    s.removeSelected();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Atom and connected bonds removed'),
        action: SnackBarAction(label: 'Undo', onPressed: s.undo),
      ),
    );
  }

  void _contextAtom(int id) {
    final s = ref.read(studioProvider);
    s.selectAtom(id);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Text(
                '${s.data.element(s.molecule.atom(id).number).name} · Atom $id',
                style: const TextStyle(fontSize: 20),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _editAtom(s);
                },
                child: const Text('Element / charge / coordinates'),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _setMode(InteractionMode.move);
                },
                child: const Text('Move atom'),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  final atom = s.molecule.atom(id);
                  final next =
                      s.molecule.atoms.fold(0, (v, a) => math.max(v, a.id)) + 1;
                  s.edit(
                    s.molecule.copy(
                      atoms: [
                        ...s.molecule.atoms,
                        Atom(
                          next,
                          atom.number,
                          atom.x + 1,
                          atom.y + .5,
                          atom.z,
                          atom.charge,
                        ),
                      ],
                    ),
                    label: 'Duplicate atom $id',
                  );
                  s.selectAtom(next);
                },
                child: const Text('Duplicate atom'),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _focusSelection();
                },
                child: const Text('Focus camera'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteAtom();
                },
                child: const Text('Delete atom'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _atomList() {
    final s = workspaceStore;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Atoms & validation', style: TextStyle(fontSize: 22)),
              for (final a in s.molecule.atoms)
                ListTile(
                  title: Text(
                    '${s.data.element(a.number).name} · atom ${a.id}',
                  ),
                  subtitle: Text(
                    'Charge ${a.charge} · (${a.x.toStringAsFixed(2)}, ${a.y.toStringAsFixed(2)}, ${a.z.toStringAsFixed(2)}) Å${validate(s.molecule).where((w) => w.startsWith('Atom ${a.id}:')).isEmpty ? '' : ' · verify valence'}',
                  ),
                  onTap: () {
                    _pickAtom(a.id);
                    Navigator.pop(context);
                  },
                  trailing: IconButton(
                    tooltip: 'Focus atom ${a.id}',
                    onPressed: () {
                      s.selectAtom(a.id);
                      Navigator.pop(context);
                      _focusSelection();
                    },
                    icon: const Icon(Icons.my_location),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _focusSelection() {
    final s = ref.read(studioProvider);
    Vector3? target;
    if (s.selectedAtom != null) {
      target = s.molecule.atom(s.selectedAtom!).position;
    } else if (selectedBond != null &&
        s.molecule.atoms.any((a) => a.id == selectedBond!.a) &&
        s.molecule.atoms.any((a) => a.id == selectedBond!.b)) {
      target =
          (s.molecule.atom(selectedBond!.a).position +
              s.molecule.atom(selectedBond!.b).position) /
          2;
    }
    if (target == null) {
      return;
    }
    final start =
        camera.focus?.clone() ??
        (s.molecule.atoms.fold(Vector3.zero(), (v, a) => v + a.position) /
            math.max(1, s.molecule.atoms.length).toDouble());
    cameraFrom = start;
    cameraTo = target;
    cameraAnimation.stop();
    if (s.preferences.reducedMotion) {
      camera.focus = target;
      camera.pan = Offset.zero;
      camera.zoom = 1.5;
      camera.update();
    } else {
      cameraAnimation.forward(from: 0);
    }
  }

  void _showHistory() {
    final s = ref.read(studioProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Editing history', style: TextStyle(fontSize: 22)),
              for (var i = 0; i < s.history.length; i++)
                ListTile(
                  leading: Icon(
                    i == s.history.length - 1
                        ? Icons.radio_button_checked
                        : Icons.history,
                    color: cyan,
                  ),
                  title: Text(s.historyLabels[i]),
                  subtitle: Text(
                    '${s.history[i].atoms.length} atoms · ${s.history[i].bonds.length} bonds',
                  ),
                  onTap: () {
                    s.restoreHistory(i);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveCamera() async {
    final s = workspaceStore;
    final name = await promptText(
      context,
      title: 'Bookmark camera',
      initial: 'View ${s.preferences.cameras.length + 1}',
      confirm: 'Save view',
      maxLength: 40,
    );
    if (name != null) {
      s.preferences.cameras.add({'name': name, ...camera.toJson()});
      await s.preferences.persist();
    }
  }

  void _cameraBookmarks() {
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
              const Text('Camera bookmarks', style: TextStyle(fontSize: 22)),
              for (final view in s.preferences.cameras)
                ListTile(
                  title: Text('${view['name']}'),
                  onTap: () {
                    camera.restore(view);
                    Navigator.pop(context);
                  },
                  trailing: IconButton(
                    tooltip: 'Delete camera bookmark',
                    onPressed: () {
                      s.preferences.cameras.remove(view);
                      s.preferences.persist();
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveCamera();
                },
                child: const Text('Save current view'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLegend() {
    final s = ref.read(studioProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Scientific visualization legend',
              style: TextStyle(fontSize: 22),
            ),
            const Text(
              'Atom colors identify elements; they do not represent electrostatic potential. Cyan rings mark selections; amber rings mark atoms with validation warnings. Lengths are Å; angles are degrees.',
            ),
            for (final n in s.molecule.atoms.map((a) => a.number).toSet())
              ListTile(
                leading: CircleAvatar(
                  radius: 9,
                  backgroundColor: s.preferences.alternativeColors
                      ? switch (n) {
                          7 => const Color(0xffb28cff),
                          8 => const Color(0xffffa544),
                          9 || 17 => const Color(0xff33d5ce),
                          _ => atomColor(n),
                        }
                      : atomColor(n),
                ),
                title: Text(s.data.element(n).name),
              ),
            const Text(
              'Electrostatic surfaces: unavailable without validated charges/potential grids. Vibration: illustrative displacement, not normal-mode frequencies. Geometry: measured from the current coordinates, not proof of electronic structure.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeToolbar(StudioStore s) => SizedBox(
    height: s.preferences.largeControls ? 49 : 37,
    child: Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                for (final m in InteractionMode.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: ChoiceChip(
                      label: Text(
                        {
                          'rotate': 'Rotate',
                          'select': 'Select',
                          'move': 'Move atom',
                          'addAtom': 'Place atom',
                          'addBond': 'Connect',
                          'measure': 'Measure',
                        }[m.name]!,
                        style: const TextStyle(fontSize: 10),
                      ),
                      selected: interaction == m,
                      onSelected: (_) {
                        if (m == InteractionMode.addAtom) {
                          _beginPlacement();
                        } else {
                          _setMode(m);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Molecule workspace',
          onPressed: _workspaceTools,
          icon: const Icon(Icons.tune, size: 20, color: cyan),
        ),
      ],
    ),
  );
  Widget _selectionBanner(StudioStore s) {
    String text =
        '${interaction.name} · ${s.dirty ? 'Unsaved changes' : 'Saved / original'}';
    if (s.selectedAtom != null) {
      final a = s.molecule.atom(s.selectedAtom!);
      text =
          '${s.data.element(a.number).symbol}${a.id} · charge ${a.charge} · ${s.molecule.bonds.where((b) => b.a == a.id || b.b == a.id).length} neighbors${validate(s.molecule).any((w) => w.startsWith('Atom ${a.id}:')) ? ' · valence warning' : ''}';
    }
    if (ghost != null) {
      text =
          'Preview ${s.data.element(s.atomType).symbol} · tap canvas to reposition';
    }
    if (pendingBond != null) {
      text =
          'Connect ${pendingBond!.a}–${pendingBond!.b} · order ${s.bondOrder}';
    }
    if (interaction == InteractionMode.measure) {
      text =
          '$measurementKind · select ${measurementCount - measureSelection.length} more atom(s)';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
          ),
          if (pendingBond != null || selectedBond != null)
            PopupMenuButton<int>(
              tooltip: 'Bond order',
              icon: const Icon(Icons.linear_scale, size: 19, color: cyan),
              onSelected: (order) {
                s.bondOrder = order;
                if (pendingBond != null) {
                  _apply(
                    () => pendingBond = Bond(
                      pendingBond!.a,
                      pendingBond!.b,
                      order,
                    ),
                  );
                } else if (selectedBond != null) {
                  final b = selectedBond!;
                  s.connect(b.a, b.b);
                  _apply(() => selectedBond = Bond(b.a, b.b, order));
                }
              },
              itemBuilder: (_) => [
                for (var order = 1; order <= 3; order++)
                  PopupMenuItem(
                    value: order,
                    child: Text(['Single', 'Double', 'Triple'][order - 1]),
                  ),
              ],
            ),
          if (ghost != null)
            IconButton(
              tooltip: 'Confirm placement',
              onPressed: _commitPlacement,
              icon: const Icon(Icons.check, color: cyan, size: 20),
            ),
          if (pendingBond != null)
            IconButton(
              tooltip: 'Confirm bond',
              onPressed: () {
                s.connect(pendingBond!.a, pendingBond!.b);
                _apply(() => pendingBond = null);
              },
              icon: const Icon(Icons.check, color: cyan, size: 20),
            ),
          if (ghost != null || pendingBond != null)
            IconButton(
              tooltip: 'Cancel preview',
              onPressed: () => _setMode(InteractionMode.select),
              icon: const Icon(Icons.close, size: 18),
            ),
          if (ghost == null && s.selectedAtom != null)
            IconButton(
              tooltip: 'Selected atom actions',
              onPressed: () => _contextAtom(s.selectedAtom!),
              icon: const Icon(Icons.more_horiz, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _orientationCube() => OrientationCube(onView: camera.orient);
  Widget _inspectorPanel(StudioStore s) {
    final h = MediaQuery.sizeOf(context).height;
    final height = inspectorSnap == 0
        ? 76.0
        : inspectorSnap == 1
        ? (h < 700 ? 158.0 : 220.0)
        : math.max(180.0, math.min(h * .48, h - 390));
    return GestureDetector(
      onVerticalDragEnd: (d) => _apply(
        () => inspectorSnap =
            (inspectorSnap + ((d.primaryVelocity ?? 0) < 0 ? 1 : -1)).clamp(
              0,
              2,
            ),
      ),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: background,
          border: Border(top: BorderSide(color: line)),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            GestureDetector(
              key: const ValueKey('molecule-inspector-handle'),
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  _apply(() => inspectorSnap = (inspectorSnap + 1) % 3),
              child: SizedBox(
                height: 14,
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: line,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.molecule.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${s.data.formula(s.molecule)}${s.dirty ? ' · Edited' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rename molecule',
                    onPressed: () => _rename(s),
                    icon: const Icon(Icons.edit_outlined, size: 19),
                  ),
                  if (s.preferences.largeControls ||
                      s.preferences.textScale > 1.1)
                    IconButton(
                      tooltip: 'Relax bonds',
                      onPressed: () => _calculate(s),
                      icon: const Icon(Icons.auto_awesome, size: 20),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => _calculate(s),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text(
                        'Relax bonds',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            if (inspectorSnap > 0) ...[
              SizedBox(
                height: 33,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (var i = 0; i < 4; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: ChoiceChip(
                          label: Text(
                            [
                              'Properties',
                              'Geometry',
                              'Interactions',
                              'Lewis structure',
                            ][i],
                            style: const TextStyle(fontSize: 10),
                          ),
                          selected: inspector == i,
                          onSelected: (_) => _apply(() {
                            inspector = i;
                            inspectorSnap = 2;
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  child: _inspector(s),
                ),
              ),
            ],
          ],
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
            builder: (context, update) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Molecule workspace',
                  style: TextStyle(fontSize: 22),
                ),
                const Text('Atom movement constraint'),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final axis in [
                      'Free',
                      'X',
                      'Y',
                      'Z',
                      'XY',
                      'XZ',
                      'YZ',
                    ])
                      ChoiceChip(
                        label: Text(axis),
                        selected: moveAxis == axis,
                        onSelected: (_) {
                          _apply(() => moveAxis = axis);
                          update(() {});
                        },
                      ),
                  ],
                ),
                const Text('Measurement tool'),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final kind in ['Length', 'Angle', 'Dihedral'])
                      ChoiceChip(
                        label: Text(kind),
                        selected: measurementKind == kind,
                        onSelected: (_) {
                          _apply(() {
                            measurementKind = kind;
                            measureSelection.clear();
                            interaction = InteractionMode.measure;
                          });
                          update(() {});
                        },
                      ),
                  ],
                ),
                if (measureSelection.length == measurementCount)
                  ListTile(
                    title: Text(
                      SceneMeasurement(
                        measurementKind,
                        measureSelection,
                      ).value(s.molecule),
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        _apply(() {
                          pinnedMeasurements.add(
                            SceneMeasurement(measurementKind, measureSelection),
                          );
                          measureSelection.clear();
                        });
                        update(() {});
                      },
                      child: const Text('Pin measurement'),
                    ),
                  ),
                for (final pin in pinnedMeasurements)
                  ListTile(
                    title: Text(
                      '${pin.kind} ${pin.atoms.join('–')} · ${pin.value(s.molecule)}',
                    ),
                    trailing: IconButton(
                      onPressed: () {
                        _apply(() => pinnedMeasurements.remove(pin));
                        update(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ),
                const Text('Display representation'),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final display in DisplayMode.values)
                      ChoiceChip(
                        label: Text(
                          {
                            'ballAndStick': 'Ball & stick',
                            'spacefill': 'Space filling',
                            'wireframe': 'Wireframe',
                            'sticks': 'Sticks',
                          }[display.name]!,
                        ),
                        selected: mode == display,
                        onSelected: (_) {
                          _apply(() => mode = display);
                          update(() {});
                        },
                      ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Atom and bond-order labels'),
                  value: labels,
                  onChanged: (v) {
                    _apply(() => labels = v);
                    update(() {});
                  },
                ),
                const Text('Inspector size'),
                Wrap(
                  spacing: 7,
                  children: [
                    for (var i = 0; i < 3; i++)
                      ChoiceChip(
                        label: Text(['Collapsed', 'Summary', 'Expanded'][i]),
                        selected: inspectorSnap == i,
                        onSelected: (_) {
                          _apply(() => inspectorSnap = i);
                          update(() {});
                        },
                      ),
                  ],
                ),
                Wrap(
                  spacing: 7,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _atomList();
                      },
                      child: const Text('Atoms & validation'),
                    ),
                    OutlinedButton(
                      onPressed: _focusSelection,
                      child: const Text('Focus selection'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showHistory();
                      },
                      child: const Text('Editing history'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _cameraBookmarks();
                      },
                      child: const Text('Camera bookmarks'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _elementPalette(s);
                      },
                      child: const Text('Full element picker'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showLegend();
                      },
                      child: const Text('Visualization legend'),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => s.recoverBackup(),
                  child: const Text('Recover previous autosaved draft'),
                ),
                if (s.autosaveError != null)
                  Text(
                    s.autosaveError!,
                    style: const TextStyle(color: Colors.amber),
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
    );
  }

  void _elementPalette(StudioStore s) {
    String query = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .7,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Choose an element',
                    style: TextStyle(fontSize: 22),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Name, symbol or atomic number',
                    ),
                    onChanged: (v) => update(() => query = v),
                  ),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: s.preferences.largeControls ? 4 : 5,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      children: [
                        for (final e in s.data.elements.where(
                          (e) => '${e.symbol} ${e.name} ${e.number}'
                              .toLowerCase()
                              .contains(query.toLowerCase()),
                        ))
                          InkWell(
                            onTap: () {
                              s.chooseAtom(e.number);
                              Navigator.pop(context);
                            },
                            child: Panel(
                              active: s.atomType == e.number,
                              padding: const EdgeInsets.all(4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    e.symbol,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${e.number}',
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                ],
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
      ),
    );
  }

  Future<void> _previewMolecule(Molecule m, StudioStore s) async {
    final previewCamera = CameraState();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(m.name),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 160,
                  child: MoleculeView(
                    molecule: m,
                    camera: previewCamera,
                    grid: false,
                  ),
                ),
                Text(
                  '${s.data.formula(m)} · ${m.atoms.length} atoms · ${m.bonds.length} bonds',
                ),
                Text('${s.data.mass(m).toStringAsFixed(2)} g/mol'),
                const SizedBox(height: 10),
                Text(m.source, style: const TextStyle(fontSize: 10)),
                for (final warning in validate(m).take(4))
                  Text(
                    warning,
                    style: const TextStyle(color: Colors.amber, fontSize: 10),
                  ),
              ],
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
              s.open(m);
              camera.reset();
              Navigator.pop(context);
            },
            child: const Text('Load molecule'),
          ),
        ],
      ),
    );
    previewCamera.dispose();
  }

  Future<void> _guidedExport(StudioStore s, {String initial = 'JSON'}) async {
    String format = initial;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final data = switch (format) {
            'MOL' => _mol(s),
            'SMILES' => s.molecule.properties['smiles']?.toString() ?? 'A reference SMILES is unavailable for this edited structure.',
            _ => const JsonEncoder.withIndent(
              '  ',
            ).convert(s.molecule.toJson()),
          };
          return AlertDialog(
            title: const Text('Export molecule'),
            content: SizedBox(
              width: 550,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MoleculeThumbnail(molecule: s.molecule),
                    Text(
                      '${s.molecule.name} · ${s.data.formula(s.molecule)} · ${s.molecule.atoms.length} atoms',
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final f in ['JSON', 'MOL', 'SMILES'])
                          ChoiceChip(
                            label: Text(f),
                            selected: format == f,
                            onSelected: (_) => update(() => format = f),
                          ),
                      ],
                    ),
                    Text(switch (format) {
                      'MOL' => 'Coordinates, bond orders and formal charge; stereochemical annotations are not serialized.',
                      'SMILES' => 'Untouched reference structures only. Does not preserve 3D coordinates.',
                      _ => 'Versioned internal graph, coordinates, charges and metadata. Re-importable.',
                    }, style: const TextStyle(fontSize: 11)),
                    const SizedBox(height: 12),
                    SelectableText(
                      data,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed:
                    format == 'SMILES' &&
                        s.molecule.properties['smiles'] == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: data));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Export copied to clipboard'),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.copy),
                label: const Text('Copy export'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _calculate(StudioStore s) async {
    bool cancelled = false;
    final progress = ValueNotifier<double>(0);
    final original = s.molecule;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Harmonic bond relaxation'),
            content: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (context, value, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Covalent-radius bond targets. No angles, torsions or nonbonded energy; not UFF/MMFF.',
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: value),
                  Text('${(value * 100).round()}% of solver steps'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => cancelled = true,
                child: const Text('Cancel calculation'),
              ),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    try {
      final result = await relaxBondsCancellable(
        original,
        cancelled: () => cancelled,
        progress: (v) => progress.value = v,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      if (cancelled) {
        return;
      }
      s.edit(result.molecule, label: 'Relax bond lengths');
      await message(
        context,
        'Calculation result',
        'Method: harmonic bond-length residual minimization\nBefore: ${result.before.toStringAsFixed(6)} Å²\nAfter: ${result.after.toStringAsFixed(6)} Å²\n\nThe original structure is available in undo history. This residual is not molecular energy. Full force-field optimization remains unavailable.',
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        await message(
          context,
          cancelled ? 'Calculation cancelled' : 'Calculation unavailable',
          '$e',
        );
      }
    } finally {
      progress.dispose();
    }
  }
}
