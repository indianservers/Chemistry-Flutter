import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/store.dart';
import '../features/periodic_table.dart';
import '../features/molecule_studio.dart';
import '../rendering/molecule_view.dart';
import 'design.dart';
import '../shared/viewing_preferences.dart';
import '../shared/draft_lifecycle.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/periodic', builder: (_, _) => const PeriodicScreen()),
    GoRoute(path: '/molecule', builder: (_, _) => const MoleculeScreen()),
  ],
);

class UniverseApp extends ConsumerWidget {
  const UniverseApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(studioProvider).preferences;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => StudioAppearance(
        preferences: prefs,
        child: MaterialApp.router(
          title: 'Chemistry Universe',
          debugShowCheckedModeBanner: false,
          theme: universeTheme(),
          routerConfig: router,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(
                  prefs.textScale > media.textScaler.scale(1)
                      ? prefs.textScale
                      : media.textScaler.scale(1),
                ),
                disableAnimations:
                    prefs.reducedMotion || media.disableAnimations,
              ),
              child: DraftLifecycle(
                store: ref.read(studioProvider),
                child: child!,
              ),
            );
          },
        ),
      ),
    );
  }
}

const studios = [
  (
    title: 'Periodic Table',
    subtitle: '118 elements. Endless discoveries.',
    route: '/periodic',
    icon: Icons.grid_view_rounded,
  ),
  (
    title: 'Molecule Studio',
    subtitle: 'Build. Optimize. Understand.',
    route: '/molecule',
    icon: Icons.hub_outlined,
  ),
];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final camera = CameraState();
  @override
  void dispose() {
    camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(studioProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                const SizedBox(height: 12),
                const StudioHeader(
                  'Chemistry Universe',
                  'YOUR PERSONAL DISCOVERY SPACE',
                ),
                const SizedBox(height: 8),
                if (store.recoveryNotice != null)
                  Panel(
                    child: Text(
                      store.recoveryNotice!,
                      style: const TextStyle(color: Colors.amber),
                    ),
                  ),
                const Text(
                  'Small atoms.\nInfinite possibilities.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Explore the elements. Build something extraordinary.',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(
                  height: 130,
                  child: MoleculeView(
                    molecule: store.molecule,
                    camera: camera,
                    grid: false,
                  ),
                ),
                const Text(
                  'CHOOSE YOUR STUDIO',
                  style: TextStyle(letterSpacing: 2, fontSize: 11, color: cyan),
                ),
                const SizedBox(height: 16),
                for (final studio in studios)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () => context.go(studio.route),
                      borderRadius: BorderRadius.circular(16),
                      child: Panel(
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Icon(studio.icon, size: 42, color: cyan),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    studio.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(studio.subtitle),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward, color: cyan),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.offline_bolt_outlined, size: 16, color: cyan),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Made for discovery. Available offline.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
