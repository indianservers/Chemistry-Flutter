import 'package:flutter/material.dart';

import '../shared/viewing_preferences.dart';

const background = Color(0xff020d1c),
    panel = Color(0xff071b32),
    line = Color(0xff173a59),
    cyan = Color(0xff25c9ff),
    muted = Color(0xffa3c4e4);
ThemeData universeTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: background,
  colorScheme: const ColorScheme.dark(
    primary: cyan,
    surface: panel,
    onSurface: Color(0xfff5f9ff),
  ),
  fontFamily: 'Roboto',
  dividerColor: line,
  appBarTheme: const AppBarTheme(
    backgroundColor: background,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: panel,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    ),
  ),
  dialogTheme: const DialogThemeData(backgroundColor: background),
  chipTheme: ChipThemeData(
    backgroundColor: panel,
    selectedColor: const Color(0xff073b6b),
    side: const BorderSide(color: line),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    labelStyle: const TextStyle(color: muted, fontSize: 11),
    showCheckmark: false,
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12)),
      foregroundColor: const WidgetStatePropertyAll(muted),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xff074780)
            : background,
      ),
      side: const WidgetStatePropertyAll(BorderSide(color: line)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: background,
    showDragHandle: true,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 13, color: muted),
    titleLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  ),
);

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool active;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.active = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: active ? const Color(0xff063464) : panel.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: active ? cyan : line),
      boxShadow: active
          ? [
              BoxShadow(
                color: cyan.withValues(
                  alpha: .12 * (StudioAppearance.of(context)?.glow ?? 1),
                ),
                blurRadius: 14,
              ),
            ]
          : null,
    ),
    child: child,
  );
}

class StudioHeader extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> actions;
  const StudioHeader(
    this.title,
    this.subtitle, {
    super.key,
    this.actions = const [],
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 12, 16),
    child: Row(
      children: [
        const Icon(Icons.hub_outlined, color: cyan, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        ...actions,
      ],
    ),
  );
}

class ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  const ToolButton(
    this.icon,
    this.label,
    this.onTap, {
    super.key,
    this.active = false,
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Panel(
        active: active,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: onTap == null
                  ? muted.withValues(alpha: .3)
                  : active
                  ? cyan
                  : muted,
              size: 23,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: active ? cyan : muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class PropertyRow extends StatelessWidget {
  final String label, value;
  const PropertyRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> message(BuildContext context, String title, String body) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: SelectableText(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
