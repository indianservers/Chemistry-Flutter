import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import '../core/chemistry.dart';

Color atomColor(int n) => switch (n) {
  1 => const Color(0xffe7f0fc),
  6 => const Color(0xff424c61),
  7 => const Color(0xff1677ec),
  8 => const Color(0xfff52c42),
  9 || 17 => const Color(0xff13c47d),
  15 => Colors.orange,
  16 => Colors.yellow,
  35 => Colors.brown,
  53 => Colors.purple,
  _ => Colors.cyan,
};

enum DisplayMode { ballAndStick, spacefill, wireframe, sticks }

class CameraState extends ChangeNotifier {
  double yaw = .3, pitch = -.2, zoom = 1;
  Offset pan = Offset.zero;
  void reset() {
    yaw = .3;
    pitch = -.2;
    zoom = 1;
    pan = Offset.zero;
    notifyListeners();
  }

  void update() => notifyListeners();
}

class MoleculeView extends StatefulWidget {
  final Map<int, String> atomLabels;
  final Molecule molecule;
  final CameraState camera;
  final int? selected;
  final ValueChanged<int?>? onPick;
  final ValueChanged<Bond>? onBond;
  final DisplayMode mode;
  final bool labels, vibration, grid;
  final double amplitude, speed;
  const MoleculeView({
    this.atomLabels = const {},
    super.key,
    required this.molecule,
    required this.camera,
    this.selected,
    this.onPick,
    this.onBond,
    this.mode = DisplayMode.ballAndStick,
    this.labels = false,
    this.vibration = false,
    this.grid = true,
    this.amplitude = .1,
    this.speed = 1,
  });
  @override
  State<MoleculeView> createState() => _MoleculeViewState();
}

class _MoleculeViewState extends State<MoleculeView>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  @override
  void initState() {
    super.initState();
    if (widget.vibration) {
      animation.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MoleculeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vibration && !animation.isAnimating) {
      animation.repeat();
    }
    if (!widget.vibration && animation.isAnimating) {
      animation.stop();
    }
  }

  double startZoom = 1;
  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.camera, animation]),
    builder: (context, _) {
      final painter = ScenePainter(
        widget.molecule,
        widget.camera,
        widget.mode,
        widget.selected,
        widget.labels,
        widget.vibration
            ? math.sin(animation.value * math.pi * 2 * widget.speed) *
                  widget.amplitude
            : 0,
        widget.grid,
        atomLabels: widget.atomLabels,
      );
      return LayoutBuilder(
        builder: (context, box) => GestureDetector(
          onScaleStart: (_) {
            startZoom = widget.camera.zoom;
          },
          onScaleUpdate: (d) {
            final c = widget.camera;
            if (d.pointerCount > 1) {
              c.zoom = (startZoom * d.scale).clamp(.25, 4);
              c.pan += d.focalPointDelta;
            } else {
              c.yaw += d.focalPointDelta.dx * .012;
              c.pitch = (c.pitch + d.focalPointDelta.dy * .012).clamp(
                -1.5,
                1.5,
              );
            }
            c.update();
          },
          onDoubleTap: widget.camera.reset,
          onTapUp: (d) {
            final points = painter.project(Size(box.maxWidth, box.maxHeight));
            final ordered = widget.molecule.atoms.toList()
              ..sort((a, b) => points[b.id]!.z.compareTo(points[a.id]!.z));
            for (final a in ordered) {
              final p = points[a.id]!;
              if ((Offset(p.x, p.y) - d.localPosition).distance < 25) {
                widget.onPick?.call(a.id);
                return;
              }
            }
            for (final b in widget.molecule.bonds) {
              final a = points[b.a]!, c = points[b.b]!;
              final start = Offset(a.x, a.y),
                  delta = Offset(c.x - a.x, c.y - a.y);
              final t = delta.distanceSquared == 0
                  ? 0.0
                  : ((d.localPosition - start).dx * delta.dx +
                            (d.localPosition - start).dy * delta.dy) /
                        delta.distanceSquared;
              if ((d.localPosition - start - delta * t.clamp(0, 1)).distance <
                  10) {
                widget.onBond?.call(b);
                return;
              }
            }
            widget.onPick?.call(null);
          },
          child: Semantics(
            label: 'Interactive 3D molecule. Drag to rotate, pinch to zoom, tap atoms or bonds.',
            child: CustomPaint(painter: painter, size: Size.infinite),
          ),
        ),
      );
    },
  );
}

class _Face {
  final List<Offset> points;
  final double depth;
  final Color color;
  final List<Color>? colors;
  _Face(this.points, this.depth, this.color, [this.colors]);
}

/// Perspective software mesh renderer: real sphere/cylinder vertices, camera
/// transforms, diffuse illumination, painter's depth sorting and atom picking.
class ScenePainter extends CustomPainter {
  final Map<int, String> atomLabels;
  final Molecule molecule;
  final CameraState camera;
  final DisplayMode mode;
  final int? selected;
  final bool labels, grid;
  final double vibration;
  ScenePainter(
    this.molecule,
    this.camera,
    this.mode,
    this.selected,
    this.labels,
    this.vibration,
    this.grid, {
    this.atomLabels = const {},
  });
  late final Vector3 _center = _findCenter();
  Vector3 get center => _center;
  Vector3 _findCenter() {
    final c = Vector3.zero();
    for (final a in molecule.atoms) {
      c.add(a.position);
    }
    return molecule.atoms.isEmpty ? c : c / (molecule.atoms.length.toDouble());
  }

  late final double _extent = _findExtent();
  double extent() => _extent;
  double _findExtent() {
    final c = center;
    return molecule.atoms.fold(
      1.7,
      (v, a) => math.max(v, a.position.distanceTo(c) + .6),
    );
  }

  Vector3 rotate(Vector3 p) {
    final x = p.x * math.cos(camera.yaw) + p.z * math.sin(camera.yaw),
        z = -p.x * math.sin(camera.yaw) + p.z * math.cos(camera.yaw);
    return Vector3(
      x,
      p.y * math.cos(camera.pitch) - z * math.sin(camera.pitch),
      p.y * math.sin(camera.pitch) + z * math.cos(camera.pitch),
    );
  }

  Vector3 screen(Vector3 p, Size size) {
    final r = rotate(p - center);
    final distance = math.max(9.0, extent() * 3);
    final factor = distance / (distance - r.z);
    final scale =
        math.min(size.width * .9, size.height * 1.3) *
        .55 /
        extent() *
        camera.zoom;
    return Vector3(
      size.width / 2 + r.x * scale * factor + camera.pan.dx,
      size.height * .48 - r.y * scale * factor + camera.pan.dy,
      r.z,
    );
  }

  Vector3 position(Atom a) =>
      a.position + Vector3(0, vibration * (a.id.isEven ? 1 : -1), 0);
  Map<int, Vector3> project(Size size) => {
    for (final a in molecule.atoms) a.id: screen(position(a), size),
  };
  @override
  void paint(Canvas canvas, Size size) {
    if (grid) {
      final paint = Paint()
        ..color = const Color(0xff0a3150)
        ..strokeWidth = .5;
      final horizon = size.height * .67;
      for (var i = -10; i <= 10; i++) {
        canvas.drawLine(
          Offset(size.width * .5 + i * 12, horizon),
          Offset(size.width * .5 + i * 100, size.height),
          paint,
        );
      }
      for (var i = 0; i < 9; i++) {
        final y = horizon + (size.height - horizon) * math.pow(i / 8, 2);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
      _text(canvas, 'Y', Offset(23, size.height - 65), Colors.greenAccent, 12);
      _text(canvas, 'X', Offset(65, size.height - 24), Colors.redAccent, 12);
      canvas.drawLine(
        Offset(28, size.height - 25),
        Offset(28, size.height - 50),
        Paint()
          ..color = Colors.greenAccent
          ..strokeWidth = 2,
      );
      canvas.drawLine(
        Offset(28, size.height - 25),
        Offset(60, size.height - 25),
        Paint()
          ..color = Colors.redAccent
          ..strokeWidth = 2,
      );
    }
    final faces = <_Face>[];
    void face(List<Vector3> vertices, Color base, [Vector3? sphereCenter]) {
      final normal = (vertices[1] - vertices[0]).cross(
        vertices[2] - vertices[0],
      )..normalize();
      final rotated = rotate(normal);
      if (sphereCenter == null && rotated.z < -.1) {
        return;
      }
      final brightness =
          (.27 +
                  .73 *
                      math.max(
                        0,
                        rotated.dot(Vector3(-.4, .6, .7)..normalize()),
                      ))
              .clamp(0, 1);
      final color = Color.fromRGBO(
        (base.r * 255 * brightness).round(),
        (base.g * 255 * brightness).round(),
        (base.b * 255 * brightness).round(),
        1,
      );
      final p = vertices.map((v) => screen(v, size)).toList();
      faces.add(
        _Face(
          p.map((v) => Offset(v.x, v.y)).toList(),
          p.fold(0.0, (v, p) => v + p.z) / p.length,
          color,
          sphereCenter == null
              ? null
              : vertices.map((vertex) {
                  final n = rotate((vertex - sphereCenter).normalized());
                  final diffuse = math.max(
                    0.0,
                    n.dot(Vector3(-.4, .6, .7)..normalize()),
                  );
                  final specular =
                      math.pow(
                        math.max(
                          0.0,
                          n.dot(Vector3(-.2, .3, .93)..normalize()),
                        ),
                        24,
                      ) *
                      .55;
                  final intensity = .3 + .7 * diffuse;
                  return Color.fromRGBO(
                    (255 * (base.r * intensity + specular).clamp(0, 1)).round(),
                    (255 * (base.g * intensity + specular).clamp(0, 1)).round(),
                    (255 * (base.b * intensity + specular).clamp(0, 1)).round(),
                    1,
                  );
                }).toList(),
        ),
      );
    }

    if (mode != DisplayMode.spacefill) {
      for (final b in molecule.bonds) {
        final a = position(molecule.atom(b.a)),
            end = position(molecule.atom(b.b));
        final axis = end - a;
        if (axis.length < .001) {
          continue;
        }
        axis.normalize();
        final cross = axis.cross(
          axis.y.abs() < .9 ? Vector3(0, 1, 0) : Vector3(1, 0, 0),
        )..normalize();
        final up = axis.cross(cross)..normalize();
        if (mode == DisplayMode.wireframe) {
          final s = screen(a, size), e = screen(end, size);
          canvas.drawLine(
            Offset(s.x, s.y),
            Offset(e.x, e.y),
            Paint()
              ..color = Colors.lightBlueAccent
              ..strokeWidth = 2,
          );
          continue;
        }
        for (var order = 0; order < b.order; order++) {
          final offset = cross * ((order - (b.order - 1) / 2) * .19);
          for (var j = 0; j < 12; j++) {
            final t = j * math.pi / 6, t2 = (j + 1) * math.pi / 6;
            final u = (cross * math.cos(t) + up * math.sin(t)) * .095 + offset,
                v = (cross * math.cos(t2) + up * math.sin(t2)) * .095 + offset;
            face([a + u, end + u, end + v, a + v], const Color(0xffc8dcf8));
          }
        }
      }
    }
    if (mode != DisplayMode.wireframe) {
      for (final a in molecule.atoms) {
        final radius = mode == DisplayMode.sticks
            ? 0.14
            : mode == DisplayMode.spacefill
            ? (a.number == 1 ? 0.68 : 1.1)
            : (a.number == 1 ? 0.26 : .43);
        final origin = position(a);
        Vector3 vertex(int lat, int lon) {
          final t = lat * math.pi / 12, p = lon * math.pi / 10;
          return origin +
              Vector3(
                    math.sin(t) * math.cos(p),
                    math.cos(t),
                    math.sin(t) * math.sin(p),
                  ) *
                  radius;
        }

        for (var lat = 0; lat < 12; lat++) {
          for (var lon = 0; lon < 20; lon++) {
            face(
              [
                vertex(lat, lon),
                vertex(lat + 1, lon),
                vertex(lat + 1, lon + 1),
                vertex(lat, lon + 1),
              ],
              atomColor(a.number),
              origin,
            );
          }
        }
      }
    }
    faces.sort((a, b) => a.depth.compareTo(b.depth));
    for (final f in faces) {
      if (f.colors != null) {
        const order = [0, 1, 2, 0, 2, 3];
        canvas.drawVertices(
          ui.Vertices(
            ui.VertexMode.triangles,
            order.map((i) => f.points[i]).toList(),
            colors: order.map((i) => f.colors![i]).toList(),
          ),
          BlendMode.srcOver,
          Paint(),
        );
        continue;
      }
      final p = Path()..addPolygon(f.points, true);
      canvas.drawPath(
        p,
        Paint()
          ..color = f.color
          ..isAntiAlias = true,
      );
    }
    final points = project(size);
    for (final a in molecule.atoms) {
      final p = points[a.id]!;
      if (a.id == selected) {
        canvas.drawCircle(
          Offset(p.x, p.y),
          27,
          Paint()
            ..color = Colors.cyanAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      if (labels) {
        _text(
          canvas,
          '${atomLabels[a.id] ?? ''}${a.id}',
          Offset(p.x + 10, p.y - 14),
          Colors.white,
          12,
        );
      }
    }
    if (molecule.atoms.isEmpty) {
      _text(
        canvas,
        'Tap Add Atom to begin',
        Offset(size.width / 2 - 85, size.height / 2),
        const Color(0xffa3c4e4),
        15,
      );
    }
    if (labels) {
      for (final b in molecule.bonds) {
        final a = points[b.a]!, end = points[b.b]!;
        _text(
          canvas,
          '${b.order}',
          Offset((a.x + end.x) / 2, (a.y + end.y) / 2 - 10),
          Colors.cyanAccent,
          10,
        );
      }
    }
  }

  void _text(Canvas c, String s, Offset p, Color color, double size) {
    final t = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: color, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    t.paint(c, p);
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) => true;
}
