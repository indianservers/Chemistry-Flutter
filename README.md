# Chemistry Universe

A new Flutter mobile foundation based on the supplied Molecule Studio and Periodic Table references in `Taret UI`. The app uses the dark navy, cyan-bordered visual language, with a touch-responsive molecular workspace and an offline element explorer. It is a working implementation, **not yet the complete Phase 1 described in the brief**.

## Run

Flutter 3.47.8 stable / Dart 3.13.7 were used on Windows.

```powershell
C:\tools\flutter\bin\flutter.bat pub get
C:\tools\flutter\bin\flutter.bat run -d emulator-5554
```

If Java reports `Unable to establish loopback connection` on this Windows host, use the project helper `tool/build_android.ps1`, which sets process-local temporary-directory overrides. It does not change machine settings.

## Architecture

- `lib/app/`: theme tokens, shared visual components, GoRouter routes, home and the two-entry studio registry.
- `lib/core/chemistry.dart`: shared immutable elements/atoms/bonds/molecules, datasets, formulas, mass, geometry, validation and limited bond relaxation.
- `lib/core/store.dart`: shared Riverpod-provided controller, undo/redo, selection and asynchronous local persistence.
- `lib/features/periodic_table.dart`: zoomable/pannable 118-element table, category/group/period highlights, search, element details, isotope explorer, atomic illustrations, heatmaps and 2–4 element comparisons.
- `lib/features/molecule_studio.dart`: atom/bond tools, preset/saved library, inspectors, graph editing, coordinate editing, Lewis projection, import/export and vibration controls.
- `lib/rendering/molecule_view.dart`: custom perspective sphere/cylinder mesh renderer, smooth vertex lighting, camera gestures, depth sorting and picking. This is software mesh rendering through Flutter Canvas, not a tested native GPU 3D engine.
- `assets/datasets/`: offline records and data licenses. References are never used as screen backgrounds or static molecular images.
- `test/`: chemistry/state correctness and responsive interaction tests.
- `integration_test/`, `test_driver/`: real Android workflow and screenshot capture.
- `docs/screenshots/`: ten captured workflow screens.

## Working features

The periodic table includes all 118 elements in their table positions, both detached series, search, selection persistence, category filtering, group/period highlights, details, isotope selection, schematic atom views, property heatmaps and numerical/bar comparisons. The entire table can be reached by pan/zoom without shrinking all 18 columns into unreadable tiles. Use Atom transfers the selected element into the molecular palette.

The molecular workspace loads twenty offline presets: hydrogen, water, oxygen, nitrogen, methane, ethane, ethene, ethyne, ethanol, methanol, benzene, carbon dioxide, ammonia, acetic acid, acetone, glucose, glycerol, lactic acid, caffeine and aspirin. Molecular graphs remain editable. Supported controls include atom addition/replacement/deletion, charges and coordinates, connecting atoms, bond-order changes/removal, undo/redo, display modes, labels, camera rotation/pan/zoom/reset, geometry measurements and local shape labels. The inspector expands without resetting the camera or graph.

Save, duplicate, rename, delete and reopen operate on local snapshots, preserving presets. Versioned JSON import checks malformed coordinates/connectivity and duplicate edges. JSON export preserves geometry and charge. MOL V2000 export includes connectivity, coordinates and formal charges; stereochemical annotations and MOL/SMILES import are not implemented. Export currently uses selectable text/clipboard rather than a native file/share picker.

See [data provenance and calculation conventions](docs/DATA_SOURCES.md).

## Dependencies and licensing

Direct runtime packages resolved in `pubspec.lock`:

- Flutter SDK: BSD-3-Clause.
- `flutter_riverpod` 3.4.3: MIT.
- `go_router` 18.1.1: BSD-3-Clause.
- `shared_preferences` 2.5.6: BSD-3-Clause; simple local snapshots, not transactional archival storage.
- `vector_math` 2.4.3: BSD-3-Clause.
- `cupertino_icons` 1.0.9: MIT (scaffold dependency; currently unused).

Development dependencies include Flutter test/driver/integration SDKs, Flutter lints and the preferences platform test implementation. Package licenses are also available through Flutter's license registry. Element data is CC BY-SA 3.0; Mendeleev data is MIT. See `assets/datasets/` and the provenance document.

## Validation

See [validation notes](docs/VALIDATION.md), machine logs in `docs/`, and the screenshots directory. Windows cannot verify an iOS build; the generated iOS target is present but needs macOS/Xcode/device testing.

## Remaining Phase 1 requirements

- A validated UFF/MMFF/native molecular mechanics optimizer. The existing harmonic bond relaxation is only a limited educational calculation and does not satisfy the brief's force-field optimization requirement.
- Scientifically calculated electrostatic surfaces and validated normal modes. Electrostatic data is unavailable; vibration is explicitly illustrative.
- Full aromaticity perception/editing, stereochemical editing, robust radical/valence exceptions and a proper chemistry-aware 2D layout. Lewis currently projects the shared 3D coordinates and allows shared atom editing; overlaps are possible.
- A genuine three-dimensional atomic/orbital renderer; current shell/cloud views are labeled schematics.
- Uniform uncertainty/estimated/experimental status for all measurements, plus independent primary-source validation of the compiled elemental dataset.
- Native share/file import/export, durable file-based archival storage and SMILES parsing/serialization for edited structures.
- Measured release-mode performance on physical Android and iOS devices, accessibility/text-scale and landscape validation, and closer visual matching across device families. Current tests cover portrait phones and tablet sizes; screenshots follow the design language but are not a pixel-exact reproduction.

These are outstanding Phase 1 work, not completed features or deferred features falsely presented as available. Future development can then expand the registry into additional chemistry studios.
