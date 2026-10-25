import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/design.dart';
import '../core/chemistry.dart';
import '../core/store.dart';
import '../rendering/molecule_view.dart';

Color categoryColor(String category) => switch (category) {
  'alkali metal' => const Color(0xffff4563),
  'alkaline earth metal' => const Color(0xffffa42b),
  'transition metal' => const Color(0xffe6bb36),
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

class _PeriodicState extends ConsumerState<PeriodicScreen> {
  final transform = TransformationController();
  final camera = CameraState();
  final search = TextEditingController();
  String? category, trend;
  int? group, period;
  final Set<int> compared = {6, 14};
  bool comparing = false;
  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(studioProvider);
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final selected = s.data.element(s.selectedElement);
        final categories = s.data.elements
            .map((e) => e.category)
            .toSet()
            .toList();
        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    StudioHeader(
                      'Periodic Table',
                      'Explore elements, properties and trends',
                      actions: [
                        IconButton(
                          tooltip: 'Search elements',
                          icon: const Icon(Icons.search),
                          onPressed: () => _search(s),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'reset') {
                              transform.value = Matrix4.identity();
                            } else {
                              _filters();
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'reset',
                              child: Text('Reset zoom'),
                            ),
                            const PopupMenuItem(
                              value: 'filters',
                              child: Text('Highlight group / period'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 76,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Wrap(
                          direction: Axis.vertical,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final c in categories)
                              FilterChip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  c,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                avatar: CircleAvatar(
                                  backgroundColor: categoryColor(c),
                                  radius: 5,
                                ),
                                selected: category == c,
                                onSelected: (_) => setState(
                                  () => category = category == c ? null : c,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (trend != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.gradient, color: cyan, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$trend · dark → bright = low → high · gray = unavailable',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => trend = null),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                      ),
                    if (comparing)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Tap 2–4 elements · ${compared.length} selected',
                              ),
                            ),
                            TextButton(
                              onPressed: compared.length < 2
                                  ? null
                                  : () => _compare(s),
                              child: const Text('Compare'),
                            ),
                            IconButton(
                              onPressed: () =>
                                  setState(() => comparing = false),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      flex: 5,
                      child: LayoutBuilder(
                        builder: (context, box) => ClipRect(
                          child: InteractiveViewer(
                            transformationController: transform,
                            constrained: false,
                            minScale: .45,
                            maxScale: 3,
                            boundaryMargin: const EdgeInsets.all(20),
                            child: GestureDetector(
                              onDoubleTap: () {
                                transform.value = Matrix4.identity()
                                  ..scaleByDouble(1.5, 1.5, 1.5, 1);
                              },
                              child: SizedBox(
                                width: math.max(850, box.maxWidth),
                                height: 480,
                                child: Stack(
                                  children: [
                                    for (var col = 1; col <= 18; col++)
                                      Positioned(
                                        left: 28 + (col - 1) * 44.5,
                                        top: 0,
                                        width: 40,
                                        child: Text(
                                          '$col',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: group == col ? cyan : muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    for (var row = 1; row <= 7; row++)
                                      Positioned(
                                        left: 6,
                                        top: 30 + (row - 1) * 44,
                                        child: Text(
                                          '$row',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    const Positioned(
                                      left: 5,
                                      top: 390,
                                      child: Text(
                                        'Ln',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ),
                                    const Positioned(
                                      left: 5,
                                      top: 434,
                                      child: Text(
                                        'An',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ),
                                    for (final e in s.data.elements)
                                      _tile(e, s),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 5, 14, 12),
                        child: Panel(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Container(
                                width: 38,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: line,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              InkWell(
                                onTap: () => _details(selected, s),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: SizedBox(
                                        height: 142,
                                        child: Panel(
                                          padding: EdgeInsets.zero,
                                          child: MoleculeView(
                                            molecule: s.data.presets.firstWhere(
                                              (m) => m.name == 'Methane',
                                            ),
                                            camera: camera,
                                            grid: false,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${selected.number}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            selected.symbol,
                                            style: TextStyle(
                                              fontSize: 45,
                                              height: 1.1,
                                              fontWeight: FontWeight.bold,
                                              color: categoryColor(
                                                selected.category,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            selected.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 23,
                                            ),
                                          ),
                                          Text(
                                            '${selected.mass} u',
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            selected.category,
                                            style: TextStyle(
                                              color: categoryColor(
                                                selected.category,
                                              ),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: PropertyRow(
                                      'Group',
                                      '${selected.data['group']}',
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: PropertyRow(
                                      'Period',
                                      '${selected.data['period']}',
                                    ),
                                  ),
                                ],
                              ),
                              PropertyRow(
                                'Electron configuration',
                                selected.configuration,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ToolButton(
                                      Icons.view_in_ar,
                                      '3D Atom',
                                      () => _atom(selected),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ToolButton(
                                      Icons.blur_circular,
                                      'Isotopes',
                                      () => _isotopes(selected),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ToolButton(
                                      Icons.hub_outlined,
                                      'Use atom',
                                      () {
                                        s.chooseAtom(selected.number);
                                        context.go('/molecule');
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ToolButton(
                                      Icons.more_horiz,
                                      'Details',
                                      () => _details(selected, s),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _launch(
                                      Icons.trending_up,
                                      'Trends',
                                      'Explore periodic trends',
                                      _trends,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _launch(
                                      Icons.balance,
                                      'Compare',
                                      'Compare 2–4 elements',
                                      () {
                                        setState(() => comparing = !comparing);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: line)),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            child: ToolButton(
                              Icons.home_outlined,
                              'Home',
                              () => context.go('/'),
                            ),
                          ),
                          Expanded(
                            child: ToolButton(
                              Icons.grid_view_rounded,
                              'Periodic Table',
                              () => transform.value = Matrix4.identity(),
                              active: true,
                            ),
                          ),
                          Expanded(
                            child: ToolButton(
                              Icons.hub_outlined,
                              'Molecule Studio',
                              () => context.go('/molecule'),
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
        );
      },
    );
  }

  Widget _tile(ElementData e, StudioStore s) {
    final match =
        (category == null || e.category == category) &&
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
          max == min ? 0.5 : ((v - min) / (max - min)),
        )!;
      }
    }
    final active =
        e.number == s.selectedElement ||
        (comparing && compared.contains(e.number));
    return Positioned(
      left: 28 + (e.column - 1) * 44.5,
      top: 26 + (e.row - 1) * 44,
      width: 41,
      height: 41,
      child: Opacity(
        opacity: match ? 1 : .18,
        child: Tooltip(
          message:
              '${e.number} · ${e.name}${trend == null ? '' : ' · ${value(e)?.toStringAsPrecision(4) ?? 'Unavailable'}'}',
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
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: active ? 0.4 : .13),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: active ? cyan : color,
                  width: active ? 2 : 1,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: cyan.withValues(alpha: .4),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${e.number}',
                    style: TextStyle(fontSize: 8, color: color),
                  ),
                  Text(
                    e.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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

  Widget _launch(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback tap,
  ) => InkWell(
    onTap: tap,
    child: Panel(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Icon(icon, color: cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white)),
                Text(subtitle, style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 17),
        ],
      ),
    ),
  );
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
                  Expanded(
                    child: ListView(
                      children: [
                        for (final e in s.data.elements.where(
                          (e) => '${e.name} ${e.symbol} ${e.number}'
                              .toLowerCase()
                              .contains(search.text.toLowerCase()),
                        ))
                          ListTile(
                            leading: Text(
                              e.symbol,
                              style: TextStyle(
                                color: categoryColor(e.category),
                                fontSize: 22,
                              ),
                            ),
                            title: Text(e.name),
                            subtitle: Text('${e.number} · ${e.category}'),
                            onTap: () {
                              s.selectElement(e.number);
                              Navigator.pop(context);
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
              PropertyRow(
                pair.$2,
                e.property(pair.$1) == null
                    ? 'Unavailable'
                    : '${e.property(pair.$1)} ${pair.$3}',
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
                s.chooseAtom(e.number);
                Navigator.pop(context);
                this.context.go('/molecule');
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
