import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/design.dart';
import '../shared/viewing_preferences.dart';

/// Vector-painted surfaces keep the reference's glow crisp at every zoom level.
class NeonSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool selected;
  final Color accent;
  const NeonSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 16,
    this.selected = false,
    this.accent = cyan,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: selected
            ? [
                const Color(0xff104578),
                const Color(0xff07264d),
                const Color(0xff083e83),
              ]
            : [
                const Color(0xff0b2442).withValues(alpha: .93),
                const Color(0xff031327).withValues(alpha: .96),
              ],
      ),
      border: Border.all(
        color: selected ? const Color(0xff68dcff) : const Color(0xff234e7c),
        width: selected ? 1.5 : .8,
      ),
      boxShadow: [
        if (selected) ...[
          BoxShadow(
            color: accent.withValues(
              alpha: .48 * (StudioAppearance.of(context)?.glow ?? 1),
            ),
            blurRadius: 17,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(
              0xff0876ff,
            ).withValues(alpha: .3 * (StudioAppearance.of(context)?.glow ?? 1)),
            blurRadius: 30,
          ),
        ],
        BoxShadow(
          color: Colors.black.withValues(alpha: .18),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class ScienceBackdrop extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff071d3b), Color(0xff010d1b), Color(0xff03162d)],
        ).createShader(Offset.zero & size),
    );
    final halo = Rect.fromCircle(
      center: Offset(size.width * .88, 0),
      radius: size.width * .6,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xff07438a).withValues(alpha: .25),
            Colors.transparent,
          ],
        ).createShader(halo),
    );
    final paint = Paint()
      ..color = const Color(0xff1760a0).withValues(alpha: .14)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var row = -1; row < 3; row++) {
      for (var col = 0; col < 5; col++) {
        final c = Offset(
          size.width * .57 + col * 39 + (row.isOdd ? 19 : 0),
          row * 34.0,
        );
        final p = Path();
        for (var i = 0; i < 6; i++) {
          final a = math.pi / 3 * i;
          final v = c + Offset(math.cos(a), math.sin(a)) * 22;
          if (i == 0) {
            p.moveTo(v.dx, v.dy);
          } else {
            p.lineTo(v.dx, v.dy);
          }
        }
        p.close();
        canvas.drawPath(p, paint);
      }
    }
    for (var i = 0; i < 5; i++) {
      final p = Offset(size.width * .77 + i * 20, 18 + math.sin(i * 1.1) * 28);
      canvas.drawCircle(
        p,
        3,
        Paint()
          ..color = const Color(0xff1783d0).withValues(alpha: .22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScienceBackdrop oldDelegate) => false;
}

class AtomMark extends StatelessWidget {
  final double size;
  const AtomMark({super.key, this.size = 38});
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _AtomMarkPainter(StudioAppearance.of(context)?.glow ?? 1),
  );
}

class _AtomMarkPainter extends CustomPainter {
  final double glow;
  _AtomMarkPainter(this.glow);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * .45;
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * math.pi / 3);
      final oval = Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2,
        height: radius * .7,
      );
      canvas.drawOval(
        oval,
        Paint()
          ..color = cyan.withValues(alpha: .6 * glow)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawOval(
        oval,
        Paint()
          ..color = const Color(0xff51cfff)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
      canvas.restore();
    }
    canvas.drawCircle(center, size.width * .085, Paint()..color = cyan);
    for (var i = 0; i < 3; i++) {
      final a = i * 2.1 + .3;
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * (radius * .93),
        2,
        Paint()..color = const Color(0xff9eeaff),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AtomMarkPainter oldDelegate) =>
      oldDelegate.glow != glow;
}

class ElementOrb extends StatelessWidget {
  final Color color;
  final int seed;
  const ElementOrb({super.key, required this.color, required this.seed});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _OrbPainter(color, seed));
}

class _OrbPainter extends CustomPainter {
  final Color color;
  final int seed;
  _OrbPainter(this.color, this.seed);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * .76, size.height * .3), r = size.width * .19;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.5, -.65),
          colors: [
            Color.lerp(color, Colors.white, .5)!,
            color.withValues(alpha: .85),
            Color.lerp(color, const Color(0xff020d1c), .88)!,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    final random = math.Random(seed);
    for (var i = 0; i < 20; i++) {
      final p =
          c +
          Offset(random.nextDouble() * 2 - 1, random.nextDouble() * 2 - 1) * r;
      canvas.drawCircle(
        p,
        random.nextDouble() * 2 + .3,
        Paint()..color = Colors.black.withValues(alpha: .08),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed;
}

class ShellIllustration extends CustomPainter {
  final List<int> shells;
  ShellIllustration(this.shells);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * .46;
    canvas.drawCircle(
      c,
      r * .35,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.5, -.5),
          colors: [Color(0xff1e6fa9), Color(0xff031027)],
        ).createShader(Rect.fromCircle(center: c, radius: r * .35)),
    );
    for (var s = 0; s < math.min(shells.length, 4); s++) {
      final radius = r * (.58 + s * .2);
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..color = const Color(0xff144e83).withValues(alpha: .6)
          ..style = PaintingStyle.stroke,
      );
      for (var i = 0; i < shells[s]; i++) {
        final a = i * math.pi * 2 / shells[s] + s * .7;
        final p = c + Offset(math.cos(a), math.sin(a)) * radius;
        canvas.drawCircle(
          p,
          2.5,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-.3, -.4),
              colors: [Color(0xff70baff), Color(0xff084574)],
            ).createShader(Rect.fromCircle(center: p, radius: 2.5)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ShellIllustration oldDelegate) =>
      oldDelegate.shells != shells;
}
