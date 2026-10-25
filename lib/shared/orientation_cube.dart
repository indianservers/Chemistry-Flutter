import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../app/design.dart';

class OrientationCube extends StatelessWidget {
  final ValueChanged<String> onView;
  const OrientationCube({super.key, required this.onView});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Camera orientation cube',
    customSemanticsActions: {
      CustomSemanticsAction(label: 'Front view'): () => onView('Front'),
      CustomSemanticsAction(label: 'Side view'): () => onView('Side'),
      CustomSemanticsAction(label: 'Top view'): () => onView('Top'),
    },
    child: Tooltip(
      message: 'Tap a cube face: top, front or side',
      child: GestureDetector(
        onTapUp: (d) => onView(
          d.localPosition.dy < 23
              ? 'Top'
              : d.localPosition.dx > 29
              ? 'Side'
              : 'Front',
        ),
        child: CustomPaint(size: const Size(58, 58), painter: _CubePainter()),
      ),
    ),
  );
}

class _CubePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size size) {
    void face(List<Offset> vertices, Color fill) {
      c.drawPath(Path()..addPolygon(vertices, true), Paint()..color = fill);
      c.drawPath(
        Path()..addPolygon(vertices, true),
        Paint()
          ..color = cyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
    }

    face([
      const Offset(4, 20),
      const Offset(29, 6),
      const Offset(54, 20),
      const Offset(29, 34),
    ], const Color(0xff154169));
    face([
      const Offset(4, 20),
      const Offset(29, 34),
      const Offset(29, 56),
      const Offset(4, 42),
    ], const Color(0xff09243e));
    face([
      const Offset(29, 34),
      const Offset(54, 20),
      const Offset(54, 42),
      const Offset(29, 56),
    ], const Color(0xff0b3054));
    for (final label in [
      ('Top', const Offset(21, 16)),
      ('Front', const Offset(7, 31)),
      ('Side', const Offset(33, 34)),
    ]) {
      final t = TextPainter(
        text: TextSpan(
          text: label.$1,
          style: const TextStyle(color: muted, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(c, label.$2);
    }
  }

  @override
  bool shouldRepaint(covariant _CubePainter oldDelegate) => false;
}
