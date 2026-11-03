import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/calendar_service.dart';

Future<void> showBodyWeightProgress(
  BuildContext context,
  List<CompletedWorkoutEntry> workouts,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => BodyWeightProgressDialog(workouts: workouts),
  );
}

class BodyWeightProgressDialog extends StatelessWidget {
  final List<CompletedWorkoutEntry> workouts;

  const BodyWeightProgressDialog({super.key, required this.workouts});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final points =
        workouts
            .where(
              (workout) =>
                  workout.bodyWeight != null && workout.bodyWeight! > 0,
            )
            .map(
              (workout) => _BodyWeightPoint(workout.date, workout.bodyWeight!),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final latest = points.isEmpty ? null : points.last;
    final change = points.length > 1
        ? latest!.weight - points.first.weight
        : null;

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Peso corporal',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Evolución por sesión',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (latest == null)
                Expanded(
                  child: Center(
                    child: Text(
                      'Todavía no hay pesos guardados. Registra el peso corporal al terminar una sesión.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    _stat(
                      context,
                      'Último registro',
                      '${latest.weight.toStringAsFixed(1)} kg',
                    ),
                    const SizedBox(width: 10),
                    _stat(
                      context,
                      'Cambio desde el inicio',
                      change == null
                          ? '--'
                          : '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomPaint(
                      painter: _BodyWeightPainter(
                        points,
                        colors.onSurface,
                        colors.onSurfaceVariant,
                        colors.primary,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: points.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final point = points[index];
                      return Chip(
                        label: Text(
                          '${point.date.day}/${point.date.month} · ${point.weight.toStringAsFixed(1)} kg',
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _BodyWeightPoint {
  final DateTime date;
  final double weight;

  const _BodyWeightPoint(this.date, this.weight);
}

class _BodyWeightPainter extends CustomPainter {
  final List<_BodyWeightPoint> points;
  final Color axisColor;
  final Color labelColor;
  final Color accentColor;

  const _BodyWeightPainter(
    this.points,
    this.axisColor,
    this.labelColor,
    this.accentColor,
  );

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const right = 12.0;
    const top = 20.0;
    const bottom = 22.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    if (plot.width <= 0 || plot.height <= 0 || points.isEmpty) return;

    final grid = Paint()
      ..color = axisColor.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = plot.top + plot.height * index / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }

    final minWeight = points.map((point) => point.weight).reduce(math.min);
    final maxWeight = points.map((point) => point.weight).reduce(math.max);
    final spread = math.max(maxWeight - minWeight, 1.0);
    final offsets = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final x = points.length == 1
          ? plot.center.dx
          : plot.left + plot.width * index / (points.length - 1);
      final y =
          plot.bottom -
          (points[index].weight - minWeight) / spread * plot.height;
      offsets.add(Offset(x, y));
    }

    final line = Paint()
      ..color = accentColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (offsets.length > 1) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(path, line);
    }
    final dot = Paint()..color = accentColor;
    for (final offset in offsets) {
      canvas.drawCircle(offset, 4.5, dot);
    }
    _drawLabel(
      canvas,
      '${maxWeight.toStringAsFixed(1)} kg',
      Offset(0, plot.top - 5),
    );
    _drawLabel(
      canvas,
      '${minWeight.toStringAsFixed(1)} kg',
      Offset(0, plot.bottom - 8),
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _BodyWeightPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.axisColor != axisColor ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.accentColor != accentColor;
}
