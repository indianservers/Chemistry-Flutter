# Studio UI/UX enhancements

Implemented for the neon navy design. Workspace settings persist locally. The controls below extend the supplied visual reference; screenshots are Android captures, not a claim of pixel equivalence.

## Periodic Table — 30 enhancements

1. Adaptive phone/tablet layout with a movable table rather than unreadably small cells.
2. Semantic zoom changes tile detail from symbols to names and atomic masses.
3. Optional minimap shows the viewport; tap it to navigate.
4. Animated focus moves the viewport to the selected element.
5. Workspace zoom slider complements pinch and plus/minus controls.
6. Dock placement and compact controls are configurable.
7. Lock control visibly indicates whether table gestures are enabled.
8. Whole-table, main-table and detached-series view presets.
9. Sticky group and period labels aid navigation.
10. Multiple category filters with element counts.
11. Live search results include element previews.
12. Recently viewed elements are available in the workspace shelf.
13. Favorites can be starred and reopened.
14. Inspector has three snap sizes and a drag handle.
15. Configurable pinned property cards.
16. Property labels include applicable units, including mass and trend scales.
17. Quality badges distinguish unavailable values and explicit measured/estimated metadata; absent uncertainty metadata is labeled unspecified.
18. Trend scales show numeric endpoints and units.
19. Adjustable heatmap intensity.
20. Neighbor buttons and inspector swipes move between elements.
21. Comparison selections form a removable tray.
22. Comparison cards use aligned property bars.
23. Isotopes include a horizontal mass-number strip.
24. Camera, filters and workspace preferences restore locally.
25. Keyboard shortcuts support search, neighbors, zoom, fit and reset.
26. Element controls expose screen-reader descriptions.
27. Optional category abbreviations supplement color.
28. Shared glow, text size, larger controls and reduced-motion preferences.
29. Dismissible first-use navigation guide.
30. Cross-studio handoff requires a review confirmation.

## Molecule Studio — 30 enhancements

1. Explicit Rotate, Select, Move, Place, Connect and Measure modes.
2. Persistent selection information and visible selection halos.
3. Larger atom and bond picking targets.
4. Long-press selection context actions.
5. XYZ/plane movement constraints with visible axes; movement commits as one undoable action.
6. Ghost placement with Confirm and Cancel.
7. Bond preview with confirmation.
8. Inline graph validation and warning halos.
9. Selected-bond order controls.
10. Named undo/redo history and history restoration.
11. Delete provides an Undo snackbar.
12. Full element palette in addition to quick atom choices.
13. Preset structure previews and formula/name search.
14. Favorite and recent molecule shelves.
15. Debounced local autosave, lifecycle flush and previous-draft recovery.
16. Dirty-state indication relative to the opened/saved baseline.
17. Orientation cube with front/side/top actions.
18. Animated focus on selected atoms or bonds.
19. Named camera bookmarks.
20. Two-, three- and four-atom length, angle and dihedral measurement modes.
21. Pinned measurements remain as scene overlays.
22. Three inspector snap sizes.
23. Local geometry sketch uses actual neighboring graph coordinates.
24. Lewis and 3D selections share atom identity.
25. Representation changes crossfade, respecting reduced motion.
26. Scientific legend describes rendering modes and unavailable calculations.
27. Illustrative vibration has play/pause, reset, speed, amplitude and mode controls; pause freezes its phase.
28. Bond relaxation exposes cancellable progress and before/after residuals.
29. Import validates and previews before committing; export previews graph/text and states format limitations.
30. Shared accessible viewing preferences, alternative colors and labels.

## Verification and scope

Widget/unit tests cover editing, previews, filters, import, persistence, recovery, history, camera serialization, measurements and narrow/large-text layouts. Android integration workflows exercise table navigation, editing, measurements, bookmarks, presets, viewing settings and restoration. Captures are in `screenshots/enhancements/`.

These UI changes do not manufacture scientific data. The relaxer remains a limited harmonic bond-length calculation, not UFF/MMFF. Vibrations are illustrative, atom shells are schematic, and calculated electrostatic surfaces remain unavailable. Clipboard exports are supported; native file sharing and full edited-structure SMILES serialization remain separate Phase 1 requirements. Shared preferences provide local recovery, not durable archival storage. See `VALIDATION.md` and the README for broader limitations.
