import 'package:flutter/material.dart';

import '../core/workspace.dart';

class StudioAppearance extends InheritedNotifier<WorkspacePreferences> {
  const StudioAppearance({
    super.key,
    required WorkspacePreferences preferences,
    required super.child,
  }) : super(notifier: preferences);
  static WorkspacePreferences? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StudioAppearance>()?.notifier;
}

Future<void> showViewingPreferences(
  BuildContext context,
  WorkspacePreferences prefs,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Viewing & accessibility',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text('Glow ${(prefs.glow * 100).round()}%'),
            Slider(
              label: 'Glow intensity',
              value: prefs.glow,
              onChanged: (v) {
                prefs.glow = v;
                prefs.persist();
              },
            ),
            Text('Text size ${(prefs.textScale * 100).round()}%'),
            Slider(
              label: 'Text size',
              value: prefs.textScale,
              min: 1,
              max: 1.4,
              divisions: 4,
              onChanged: (v) {
                prefs.textScale = v;
                prefs.persist();
              },
            ),
            SwitchListTile(
              title: const Text('Larger touch controls'),
              value: prefs.largeControls,
              onChanged: (v) {
                prefs.largeControls = v;
                prefs.persist();
              },
            ),
            SwitchListTile(
              title: const Text('Reduce motion'),
              subtitle: const Text(
                'Use instant camera changes and pause illustrative vibration.',
              ),
              value: prefs.reducedMotion,
              onChanged: (v) {
                prefs.reducedMotion = v;
                prefs.persist();
              },
            ),
            SwitchListTile(
              title: const Text('Alternative atom colors'),
              subtitle: const Text(
                'Pair alternate colors with element labels.',
              ),
              value: prefs.alternativeColors,
              onChanged: (v) {
                prefs.alternativeColors = v;
                prefs.persist();
              },
            ),
            SwitchListTile(
              title: const Text('Category patterns'),
              subtitle: const Text(
                'Distinguish categories without relying on color.',
              ),
              value: prefs.patterns,
              onChanged: (v) {
                prefs.patterns = v;
                prefs.persist();
              },
            ),
            TextButton(
              onPressed: () {
                prefs.periodicHints = true;
                prefs.moleculeHints = true;
                prefs.persist();
              },
              child: const Text('Show studio guidance again'),
            ),
          ],
        ),
      ),
    ),
  ),
);
