import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/exercise_model.dart';
import '../models/set_model.dart';
import '../services/calendar_service.dart';

Future<void> showExerciseProgress(
  BuildContext context,
  ExerciseModel exercise,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => ExerciseProgressDialog(exercise: exercise),
  );
}

class ExerciseProgressDialog extends StatelessWidget {
  final ExerciseModel exercise;

  const ExerciseProgressDialog({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'RM máximo por día',
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
              const SizedBox(height: 12),
              if (uid == null)
                const Expanded(
                  child: Center(
                    child: Text('Inicia sesión para ver el progreso.'),
                  ),
                )
              else
                Expanded(
                  child: StreamBuilder<List<CompletedWorkoutEntry>>(
                    stream: CalendarService().watchAllCompletedWorkouts(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('No se pudo cargar: ${snapshot.error}'),
                        );
                      }
                      final points = _dailyMaxima(snapshot.data ?? []);
                      if (points.isEmpty) {
                        return Center(
                          child: Text(
                            'Aún no hay series registradas para este ejercicio.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        );
                      }
                      final best = points
                          .map((point) => point.rm)
                          .reduce(math.max);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _stat(
                                context,
                                'Récord estimado',
                                '${best.toStringAsFixed(1)} kg',
                              ),
                              const SizedBox(width: 10),
                              _stat(
                                context,
                                'Días registrados',
                                '${points.length}',
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
                                painter: _DailyRmPainter(
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
                            height: 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: points.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final point = points[index];
                                return Chip(
                                  label: Text(
                                    '${point.date.day}/${point.date.month} · ${point.rm.toStringAsFixed(1)} kg',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
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

  List<_DailyRmPoint> _dailyMaxima(List<CompletedWorkoutEntry> workouts) {
    final maxima = <DateTime, _DailyRmPoint>{};
    final targetName = exercise.name.trim().toLowerCase();
    for (final workout in workouts) {
      final date = DateTime(
        workout.date.year,
        workout.date.month,
        workout.date.day,
      );
      for (final result in workout.results) {
        final resultId = result['exerciseId']?.toString();
        final resultName = result['exerciseName']
            ?.toString()
            .trim()
            .toLowerCase();
        if (resultId != exercise.id && resultName != targetName) continue;
        for (final rawSet in result['sets'] as List<dynamic>? ?? []) {
          final set = Map<String, dynamic>.from(rawSet as Map);
          final weight = (set['weight'] as num?)?.toDouble() ?? 0;
          final reps = (set['reps'] as num?)?.toInt() ?? 0;
          final savedRm = (set['rm'] as num?)?.toDouble() ?? 0;
          final rm = savedRm > 0 ? savedRm : SetModel.calculateRM(weight, reps);
          final current = maxima[date];
          if (rm > (current?.rm ?? 0)) {
            maxima[date] = _DailyRmPoint(date, rm, weight);
          }
        }
      }
    }
    return maxima.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }
}

class _DailyRmPoint {
  final DateTime date;
  final double rm;
  final double weight;

  const _DailyRmPoint(this.date, this.rm, this.weight);
}

class _DailyRmPainter extends CustomPainter {
  final List<_DailyRmPoint> points;
  final Color axisColor;
  final Color labelColor;
  final Color accentColor;

  const _DailyRmPainter(
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
    for (var i = 0; i < 4; i++) {
      final y = plot.top + plot.height * i / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }

    final minRm = points.map((point) => point.rm).reduce(math.min);
    final maxRm = points.map((point) => point.rm).reduce(math.max);
    final spread = math.max(maxRm - minRm, 1.0);
    final firstDay = points.first.date;
    final totalDays = points.last.date.difference(firstDay).inDays;
    final offsets = points.map((point) {
      final x = totalDays == 0
          ? plot.center.dx
          : plot.left +
                plot.width * point.date.difference(firstDay).inDays / totalDays;
      final y = plot.bottom - (point.rm - minRm) / spread * plot.height;
      return Offset(x, y);
    }).toList();

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
    final dots = Paint()..color = accentColor;
    for (var i = 0; i < offsets.length; i++) {
      canvas.drawCircle(offsets[i], 4.5, dots);
      _drawLabel(
        canvas,
        points[i].rm.toStringAsFixed(1),
        Offset(offsets[i].dx - 20, offsets[i].dy - 20),
        labelColor,
      );
    }
    _drawLabel(
      canvas,
      '${maxRm.toStringAsFixed(1)} kg',
      const Offset(0, 0),
      labelColor,
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _DailyRmPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.axisColor != axisColor ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.accentColor != accentColor;
}
