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

enum InteractionMode { rotate, select, move, addAtom, addBond, measure }

class SceneMeasurement {
  final List<int> atoms;
  final String kind;
  SceneMeasurement(this.kind, List<int> atoms)
    : atoms = List.unmodifiable(atoms);
  String value(Molecule m) {
    if (atoms.any((id) => !m.atoms.any((a) => a.id == id))) {
      return 'Removed atoms';
    }
    final a = atoms.map(m.atom).toList();
    return switch (kind) {
      'Length' =>
        '${a[0].position.distanceTo(a[1].position).toStringAsFixed(3)} Å',
      'Angle' => '${angle(a[0], a[1], a[2]).toStringAsFixed(1)}°',
      _ => '${dihedral(a[0], a[1], a[2], a[3]).toStringAsFixed(1)}°',
    };
  }
}

class CameraState extends ChangeNotifier {
  double yaw = .3, pitch = -.2, zoom = 1;
  Offset pan = Offset.zero;
  Vector3? focus;
  Map<String, dynamic> toJson() => {
    'yaw': yaw,
    'pitch': pitch,
    'zoom': zoom,
    'x': pan.dx,
    'y': pan.dy,
    'focus': focus == null ? null : [focus!.x, focus!.y, focus!.z],
  };
  void restore(Map<String, dynamic> j) {
    yaw = (j['yaw'] as num).toDouble();
    pitch = (j['pitch'] as num).toDouble();
    zoom = (j['zoom'] as num).toDouble().clamp(.25, 4);
    pan = Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
    final f = j['focus'] as List?;
    focus = f == null
        ? null
        : Vector3(
            (f[0] as num).toDouble(),
            (f[1] as num).toDouble(),
            (f[2] as num).toDouble(),
          );
    notifyListeners();
  }

  void orient(String view) {
    focus = null;
    pan = Offset.zero;
    yaw = view == 'Side' ? math.pi / 2 : 0;
    pitch = view == 'Top' ? math.pi / 2 : 0;
    notifyListeners();
  }

  void reset() {
    yaw = .3;
    pitch = -.2;
    zoom = 1;
    pan = Offset.zero;
    focus = null;
    notifyListeners();
  }

  void update() => notifyListeners();
}

class MoleculeView extends StatefulWidget {
  final bool vibrationVisible;
  final String vibrationKind;
  final VoidCallback? onInteractionStart;
  final Molecule molecule;
  final CameraState camera;
  final Map<int, String> atomLabels;
  final int? selected;
  final ValueChanged<int?>? onPick;
  final ValueChanged<Bond>? onBond;
  final DisplayMode mode;
  final InteractionMode interaction;
  final ValueChanged<Vector3>? onMove, onPlace;
  final VoidCallback? onMoveEnd;
  final ValueChanged<int>? onContext;
  final ValueChanged<Size>? onViewport;
  final Atom? ghost;
  final Bond? previewBond, selectedBond;
  final Set<int> highlights, warnings;
  final List<SceneMeasurement> measurements;
  final bool labels, vibration, grid, alternativeColors;
  final double amplitude, speed;
  const MoleculeView({
    this.vibrationVisible = false,
    this.vibrationKind = 'Alternating',
    this.onInteractionStart,
    super.key,
    required this.molecule,
    required this.camera,
    this.atomLabels = const {},
    this.selected,
    this.onPick,
    this.onBond,
    this.mode = DisplayMode.ballAndStick,
    this.interaction = InteractionMode.rotate,
    this.onMove,
    this.onMoveEnd,
    this.onPlace,
    this.onContext,
    this.onViewport,
    this.ghost,
    this.previewBond,
    this.selectedBond,
    this.highlights = const {},
    this.warnings = const {},
    this.measurements = const [],
    this.alternativeColors = false,
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
  double startZoom = 1;
  @override
  void initState() {
    super.initState();
    animation.duration = Duration(milliseconds: (3000 / widget.speed).round());
    if (widget.vibration) {
      animation.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MoleculeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed) {
      animation.duration = Duration(
        milliseconds: (3000 / widget.speed).round(),
      );
      if (widget.vibration) {
        animation.repeat();
      }
    }
    if (widget.vibration && !animation.isAnimating) {
      animation.repeat();
    }
    if (!widget.vibration && animation.isAnimating) {
      animation.stop();
    }
  }

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
        (widget.vibration || widget.vibrationVisible)
            ? math.sin(animation.value * math.pi * 2) * widget.amplitude
            : 0,
        widget.grid,
        atomLabels: widget.atomLabels,
        ghost: widget.ghost,
        previewBond: widget.previewBond,
        selectedBond: widget.selectedBond,
        highlights: widget.highlights,
        warnings: widget.warnings,
        measurements: widget.measurements,
        alternativeColors: widget.alternativeColors,
        vibrationKind: widget.vibrationKind,
        showHandles: widget.interaction == InteractionMode.move,
      );
      return LayoutBuilder(
        builder: (context, box) {
          widget.onViewport?.call(box.biggest);
          int? pick(Offset point) {
            final points = painter.project(box.biggest);
            final ordered = widget.molecule.atoms.toList()
              ..sort((a, b) => points[b.id]!.z.compareTo(points[a.id]!.z));
            for (final a in ordered) {
              final p = points[a.id]!;
              if ((Offset(p.x, p.y) - point).distance < 30) {
                return a.id;
              }
            }
            return null;
          }

          return GestureDetector(
            onScaleStart: (_) {
              widget.onInteractionStart?.call();
              startZoom = widget.camera.zoom;
            },
            onScaleUpdate: (d) {
              final c = widget.camera;
              if (d.pointerCount > 1) {
                c.zoom = (startZoom * d.scale).clamp(.25, 4);
                c.pan += d.focalPointDelta;
              } else {
                if (widget.interaction == InteractionMode.move) {
                  widget.onMove?.call(
                    painter.screenDeltaToWorld(d.focalPointDelta, box.biggest),
                  );
                  return;
                }
                if (widget.interaction != InteractionMode.rotate) {
                  return;
                }
                c.yaw += d.focalPointDelta.dx * .012;
                c.pitch = (c.pitch + d.focalPointDelta.dy * .012).clamp(
                  -1.5,
                  1.5,
                );
              }
              c.update();
            },
            onScaleEnd: (_) => widget.onMoveEnd?.call(),
            onDoubleTap: widget.camera.reset,
            onLongPressStart: (d) {
              final id = pick(d.localPosition);
              if (id != null) {
                widget.onContext?.call(id);
              }
            },
            onTapUp: (d) {
              if (widget.interaction == InteractionMode.addAtom) {
                final delta =
                    d.localPosition -
                    box.biggest.center(Offset.zero) -
                    widget.camera.pan;
                widget.onPlace?.call(
                  painter.center +
                      painter.screenDeltaToWorld(delta, box.biggest),
                );
                return;
              }
              final id = pick(d.localPosition);
              if (id != null) {
                widget.onPick?.call(id);
                return;
              }
              final points = painter.project(box.biggest);
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
                    14) {
                  widget.onBond?.call(b);
                  return;
                }
              }
              widget.onPick?.call(null);
            },
            child: Semantics(
              label:
                  'Interactive 3D molecule. Mode ${widget.interaction.name}. ${widget.molecule.atoms.length} atoms. Drag to rotate or move, pinch to zoom, tap atoms or bonds.',
              child: CustomPaint(painter: painter, size: Size.infinite),
            ),
          );
        },
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
  final String vibrationKind;
  final bool showHandles;
  final Atom? ghost;
  final Bond? previewBond, selectedBond;
  final Set<int> highlights, warnings;
  final List<SceneMeasurement> measurements;
  final bool alternativeColors;
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
    this.ghost,
    this.previewBond,
    this.selectedBond,
    this.highlights = const {},
    this.warnings = const {},
    this.measurements = const [],
    this.alternativeColors = false,
    this.vibrationKind = 'Alternating',
    this.showHandles = false,
  });
  late final Vector3 _center = _findCenter();
  Vector3 get center => _center;
  Vector3 _findCenter() {
    if (camera.focus != null) {
      return camera.focus!.clone();
    }
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
      a.position +
      (vibrationKind == 'Radial breathing'
          ? (a.position - center).normalized() * vibration
          : Vector3(0, vibration * (a.id.isEven ? 1 : -1), 0));
  Vector3 screenDeltaToWorld(Offset delta, Size size) {
    final scale =
        math.min(size.width * .9, size.height * 1.3) *
        .55 /
        extent() *
        camera.zoom;
    if (scale <= 0) {
      return Vector3.zero();
    }
    final dx = delta.dx / scale, dy = -delta.dy / scale;
    final y = dy * math.cos(camera.pitch), z = -dy * math.sin(camera.pitch);
    return Vector3(
      dx * math.cos(camera.yaw) - z * math.sin(camera.yaw),
      y,
      dx * math.sin(camera.yaw) + z * math.cos(camera.yaw),
    );
  }

  Color _color(int n) => alternativeColors
      ? switch (n) {
          7 => const Color(0xffb28cff),
          8 => const Color(0xffffa544),
          9 || 17 => const Color(0xff33d5ce),
          _ => atomColor(n),
        }
      : atomColor(n);
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
              _color(a.number),
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
      if (a.id == selected ||
          highlights.contains(a.id) ||
          warnings.contains(a.id)) {
        canvas.drawCircle(
          Offset(p.x, p.y),
          27,
          Paint()
            ..color = warnings.contains(a.id) ? Colors.amber : Colors.cyanAccent
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
    for (final bond in [?previewBond, ?selectedBond]) {
      if (!points.containsKey(bond.a) || !points.containsKey(bond.b)) {
        continue;
      }
      final a = points[bond.a]!, b = points[bond.b]!;
      canvas.drawLine(
        Offset(a.x, a.y),
        Offset(b.x, b.y),
        Paint()
          ..color = Colors.cyanAccent.withValues(alpha: .7)
          ..strokeWidth = previewBond == bond ? 3 : 5,
      );
      _text(
        canvas,
        '${previewBond == bond ? 'Connect · ' : ''}order ${bond.order}',
        Offset((a.x + b.x) / 2, (a.y + b.y) / 2 - 14),
        Colors.cyanAccent,
        11,
      );
    }
    if (showHandles && selected != null && points.containsKey(selected)) {
      final origin = molecule.atom(selected!).position;
      final start = screen(origin, size);
      for (final axis in [
        (Vector3(.9, 0, 0), 'X', Colors.redAccent),
        (Vector3(0, .9, 0), 'Y', Colors.greenAccent),
        (Vector3(0, 0, .9), 'Z', Colors.lightBlueAccent),
      ]) {
        final end = screen(origin + axis.$1, size);
        canvas.drawLine(
          Offset(start.x, start.y),
          Offset(end.x, end.y),
          Paint()
            ..color = axis.$3
            ..strokeWidth = 2,
        );
        _text(canvas, axis.$2, Offset(end.x, end.y), axis.$3, 12);
      }
    }
    if (ghost != null) {
      final p = screen(ghost!.position, size);
      final center = Offset(p.x, p.y);
      canvas.drawCircle(
        center,
        17,
        Paint()..color = _color(ghost!.number).withValues(alpha: .5),
      );
      canvas.drawCircle(
        center,
        20,
        Paint()
          ..color = Colors.cyanAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      if (selected != null && points.containsKey(selected)) {
        final a = points[selected]!;
        canvas.drawLine(
          Offset(a.x, a.y),
          center,
          Paint()
            ..color = Colors.cyanAccent.withValues(alpha: .6)
            ..strokeWidth = 2,
        );
      }
      _text(
        canvas,
        'Preview',
        center + const Offset(20, -10),
        Colors.cyanAccent,
        11,
      );
    }
    for (final measure in measurements) {
      if (measure.atoms.any((id) => !points.containsKey(id))) {
        continue;
      }
      Offset midpoint = Offset.zero;
      for (var i = 0; i < measure.atoms.length; i++) {
        final p = points[measure.atoms[i]]!;
        midpoint += Offset(p.x, p.y);
        if (i > 0) {
          final q = points[measure.atoms[i - 1]]!;
          canvas.drawLine(
            Offset(q.x, q.y),
            Offset(p.x, p.y),
            Paint()
              ..color = Colors.amber
              ..strokeWidth = 1.3,
          );
        }
      }
      midpoint /= measure.atoms.length.toDouble();
      _text(
        canvas,
        measure.value(molecule),
        midpoint + const Offset(7, -18),
        Colors.amber,
        12,
      );
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
