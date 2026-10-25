# Validation — 25 October 2026

## Results

- `flutter pub get`: passed with Flutter 3.47.8 stable / Dart 3.13.7.
- `dart format lib test integration_test test_driver`: passed.
- `flutter analyze`: no issues (see `analyze.log`).
- `flutter test`: 22 tests passed (see `tests.log`).
- Android integration workflow: passed on `emulator-5554`, Android 17 / API 37, x86_64, 720×1280 screenshot surface. Wi-Fi and cellular data were disabled for the test and restored afterward. See `android-integration.log`.
- Android debug APK: built successfully; the normal `lib/main.dart` entry point is used for the delivery build, not the integration-test harness. See `android-build.log` and `build/app/outputs/flutter-apk/app-debug.apk`.
- Flutter Web: updated release build passed (see `web-build.log`); mobile remains the primary target.
- iOS: generated target only. Not compiled or run because this host is Windows and has no macOS/Xcode environment.

## Coverage

Chemistry/state tests check 118 unique elements and shell electron totals, 20 preset formulas/connectivity, ethanol mass, isotope and ionic-radius records, oxidation states, charged structures, JSON round trips, malformed connectivity/duplicate edges, coordinate measurements, actual bond-residual reduction, atom editing, undo/redo, save/restore/delete, camera transforms, corrupt storage recovery and invalidation of recorded properties after edits.

Widget tests also verify that all 118 tiles, including the bottom actinide row, fit inside the pannable content bounds. Widget tests check both studios at 320×640, 390×844 and 900×1200 logical pixels; search/selection; opening/closing element details; atom addition/undo/redo; and home navigation. These are portrait layout tests, not a claim of full accessibility, landscape or iPhone validation.

The Android workflow exercises home navigation, Carbon search/details, periodic heatmap selection, molecule canvas dragging with camera-state assertions, actual atom addition and undo, inspector tabs, preset library, saving, reopening and navigation restoration. It captures ten screens. It does not prove every gesture, every element comparison, every scientific edge case, restart restoration on a second physical device, or all acceptance criteria from the master brief.

## Screenshots

- `screenshots/01-home.png`
- `screenshots/02-periodic-table.png`
- `screenshots/03-element-details.png`
- `screenshots/04-periodic-trends.png`
- `screenshots/05-ethanol.png`
- `screenshots/06-editing.png`
- `screenshots/07-inspector.png`
- `screenshots/08-presets.png`
- `screenshots/09-geometry.png`
- `screenshots/10-saved-library.png`

The images were captured from the running Android application through Flutter's integration-test screenshot API. Visual inspection prompted fixes to tile text overflow, selected colors, molecular scale/shading, keyboard resizing, navigation widths and camera-tool reachability. The small-screen table intentionally pans/zooms instead of fitting all columns into tiny cells. These screenshots are not a claim of exact visual equivalence to the supplied phone mockups.

## Measured rotation performance

`rotation-performance.json` records an 800 ms drag in a debug Android emulator run, 32 measured frames:

- Average frame build time: 7.196 ms; worst: 12.540 ms.
- Average raster time: 13.746 ms; worst: 21.525 ms.
- Build-budget misses: 0; raster-budget misses: 2.

This short debug-emulator sample is not evidence of sustained 60 FPS on physical Android/iOS devices or medium/large molecules. Software mesh rendering is idle when no camera/vibration state changes. Release/profile-mode tests with larger structures remain necessary.

## Host limitations and build workaround

`flutter doctor -v` found Flutter and the running Android emulator. Android SDK command-line tools were missing, and Windows desktop C++ components were incomplete; installed SDK build tools were sufficient for the APK. Flutter/Dart are installed at `C:\tools\flutter` but are not on PATH. Java's initial Windows loopback failure was resolved with process-local `TEMP`, `TMP`, `java.io.tmpdir` and `jdk.net.unixdomain.tmpdir` pointing to `C:\tmp`; see `tool/build_android.ps1`.

## Neon UI update

The Periodic Table was restyled against `Taret UI/Periodic-Glow-Reference.png`. New tests assert real camera scale/translation changes for zoom, directional movement, fit, focus and reset; gesture locking; and touch dragging. All 22 tests and analysis pass. The updated Android integration run also exercises the viewport controls and captures 13 screens in `screenshots/neon-final/`, including directional movement, all 118 elements fitted into view and focus on Carbon. See `neon-android-integration.log`. The earlier offline run remains the baseline offline validation; this UI verification run used the emulator's normal connectivity.

## 60 UI/UX enhancement update

The implementation inventory is in `UX_ENHANCEMENTS.md`. Final analysis reports no issues, and all 36 unit/widget tests pass (`analyze.log`, `tests.log`). New coverage includes placement cancellation/confirmation, constrained movement with undo, bond previews, category filters, import review, local persistence/recovery, named history, measurements, confidence metadata and 320×640 layouts with larger text.

The Android enhancement workflow passed (`enhancements-android.log`) and captured eight screens in `screenshots/enhancements/`. These exercise minimap/favorites, confirmed handoff, placement, constrained movement, pinned measurements, history, camera bookmarks, preset previews, viewing preferences and restored workspace. The original Android workflow also passed (`final-android-regression.log`), checking table controls, rotation, confirmed editing, geometry, save/load and navigation. Regression testing found and resolved a transient inspector expansion overflow. Screenshots were visually reviewed for controls, selection and overlays.

Local draft recovery uses shared preferences; it is not durable file archival. Quality labels show measured/estimated only when explicit metadata exists, otherwise reference uncertainty is unspecified. The broader scientific acceptance limitations below remain unchanged.

## Outstanding scientific acceptance requirements

The full master brief is **not fully accepted**. A validated force-field optimizer, calculated electrostatic surfaces, full aromatic/stereochemical handling, true 3D quantum atom rendering and further scientific/device validation remain outstanding. The limited bond relaxer, unavailable electrostatic data and illustrative vibrations are labeled accurately in the app. See the README's remaining Phase 1 list.
