import 'package:flutter/material.dart';

import '../app/design.dart';
import '../core/chemistry.dart';
import '../core/store.dart';
import '../rendering/molecule_view.dart';

class StudioLibrary extends StatefulWidget {
  final StudioStore store;
  final bool savedOnly;
  final ValueChanged<Molecule> onOpen, onPreview;
  const StudioLibrary({
    super.key,
    required this.store,
    this.savedOnly = false,
    required this.onOpen,
    required this.onPreview,
  });
  @override
  State<StudioLibrary> createState() => _LibraryState();
}

class _LibraryState extends State<StudioLibrary> {
  String query = '', filter = 'All';
  @override
  void initState() {
    super.initState();
    filter = widget.savedOnly ? 'Saved' : 'All';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: ListenableBuilder(
          listenable: Listenable.merge([s, s.preferences]),
          builder: (context, _) {
            final records = [...s.data.presets, ...s.saved]
                .where(
                  (m) => '${m.name} ${s.data.formula(m)} ${m.id}'
                      .toLowerCase()
                      .contains(query.toLowerCase()),
                )
                .where(
                  (m) => switch (filter) {
                    'Saved' => s.saved.any((v) => v.id == m.id),
                    'Favorites' => s.preferences.favoriteMolecules.contains(
                      m.id,
                    ),
                    'Recent' => s.preferences.recentMolecules.contains(m.id),
                    _ => true,
                  },
                )
                .toList();
            if (filter == 'Recent') {
              records.sort(
                (a, b) => s.preferences.recentMolecules
                    .indexOf(a.id)
                    .compareTo(s.preferences.recentMolecules.indexOf(b.id)),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(18),
              child: ListView(
                children: [
                  const Text(
                    'Molecule Library',
                    style: TextStyle(fontSize: 23, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search name or molecular formula',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in ['All', 'Saved', 'Favorites', 'Recent'])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(f),
                              selected: filter == f,
                              onSelected: (_) => setState(() => filter = f),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      if (records.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            filter == 'Saved'
                                ? 'No saved molecules yet. Save your work from the menu.'
                                : 'No matching molecules. Try another search or filter.',
                          ),
                        ),
                      for (final m in records)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: MoleculeThumbnail(molecule: m),
                          title: Text(
                            m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${s.data.formula(m)} · ${m.atoms.length} atoms · ${s.data.mass(m).toStringAsFixed(2)} g/mol',
                            style: const TextStyle(fontSize: 10),
                          ),
                          onTap: () => widget.onOpen(m),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Favorite ${m.name}',
                                onPressed: () =>
                                    s.preferences.favoriteMolecule(m.id),
                                icon: Icon(
                                  s.preferences.favoriteMolecules.contains(m.id)
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 18,
                                  color: cyan,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Preview ${m.name}',
                                onPressed: () => widget.onPreview(m),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                ),
                              ),
                              if (s.saved.any((v) => v.id == m.id))
                                IconButton(
                                  tooltip: 'Delete saved ${m.name}',
                                  onPressed: () => s.deleteSaved(m.id),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class MoleculeThumbnail extends StatefulWidget {
  final Molecule molecule;
  const MoleculeThumbnail({super.key, required this.molecule});
  @override
  State<MoleculeThumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<MoleculeThumbnail> {
  final camera = CameraState();
  @override
  void dispose() {
    camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 50,
    child: CustomPaint(
      painter: ScenePainter(
        widget.molecule,
        camera,
        DisplayMode.ballAndStick,
        null,
        false,
        0,
        false,
      ),
    ),
  );
}
