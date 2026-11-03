import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/calendar_service.dart';

class UtilitiesScreen extends StatefulWidget {
  const UtilitiesScreen({super.key});

  @override
  State<UtilitiesScreen> createState() => _UtilitiesScreenState();
}

class _UtilitiesScreenState extends State<UtilitiesScreen>
    with SingleTickerProviderStateMixin {
  final _liftController = TextEditingController();
  final _repsController = TextEditingController();
  final _totalController = TextEditingController();
  final _bodyweightController = TextEditingController();
  late final TabController _tabs;
  String _sex = 'male';
  String? _selectedExercise;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _liftController.dispose();
    _repsController.dispose();
    _totalController.dispose();
    _bodyweightController.dispose();
    super.dispose();
  }

  double? get _weight =>
      double.tryParse(_liftController.text.replaceAll(',', '.'));
  int? get _reps => int.tryParse(_repsController.text);
  double? get _bodyweight =>
      double.tryParse(_bodyweightController.text.replaceAll(',', '.'));
  double? get _totalLift =>
      double.tryParse(_totalController.text.replaceAll(',', '.'));
  double get _estimatedRm {
    final weight = _weight ?? 0;
    final reps = _reps ?? 0;
    return weight > 0 && reps > 0 ? weight * (1 + reps / 30) : 0;
  }

  double get _wilks {
    final bodyweight = _bodyweight ?? 0;
    final lifted = _totalLift ?? 0;
    if (bodyweight <= 0 || lifted <= 0) return 0;
    final coefficients = _sex == 'male'
        ? [
            -216.0475144,
            16.2606339,
            -0.002388645,
            -0.00113732,
            0.00000701863,
            -0.00000001291,
          ]
        : [
            594.31747775582,
            -27.23842536447,
            0.82112226871,
            -0.00930733913,
            0.00004731582,
            -0.00000009054,
          ];
    final denominator =
        coefficients[0] +
        coefficients[1] * bodyweight +
        coefficients[2] * math.pow(bodyweight, 2) +
        coefficients[3] * math.pow(bodyweight, 3) +
        coefficients[4] * math.pow(bodyweight, 4) +
        coefficients[5] * math.pow(bodyweight, 5);
    return denominator > 0 ? lifted * 500 / denominator : 0;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HERRAMIENTAS',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Calculadora'),
            Tab(text: 'Progreso'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _calculator(),
          uid == null
              ? const Center(child: Text('Inicia sesión para ver tu progreso.'))
              : StreamBuilder<List<CompletedWorkoutEntry>>(
                  stream: CalendarService().watchAllCompletedWorkouts(uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'No se pudo cargar el progreso: ${snapshot.error}',
                        ),
                      );
                    }
                    return _progress(snapshot.data ?? []);
                  },
                ),
        ],
      ),
    );
  }

  Widget _calculator() {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'ESTIMACIÓN DE FUERZA',
          style: TextStyle(
            color: Color(0xFF4DD0A1),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Introduce una serie reciente para calcular tu repetición máxima estimada.',
          style: TextStyle(color: mutedColor),
        ),
        const SizedBox(height: 20),
        _numberField(_liftController, 'Peso levantado', 'kg', decimal: true),
        const SizedBox(height: 12),
        _numberField(_repsController, 'Repeticiones', 'reps'),
        const SizedBox(height: 20),
        _resultPanel(
          context,
          '1RM estimado',
          '${_estimatedRm.toStringAsFixed(1)} kg',
          'Fórmula de Epley',
        ),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 16),
        const Text(
          'PUNTOS WILKS',
          style: TextStyle(
            color: Color(0xFF4DD0A1),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _sex,
          decoration: const InputDecoration(
            labelText: 'Coeficiente',
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: const [
            DropdownMenuItem(value: 'male', child: Text('Hombre')),
            DropdownMenuItem(value: 'female', child: Text('Mujer')),
          ],
          onChanged: (value) => setState(() => _sex = value ?? _sex),
        ),
        const SizedBox(height: 12),
        _numberField(
          _totalController,
          'Total de competición',
          'kg',
          decimal: true,
        ),
        const SizedBox(height: 12),
        _numberField(
          _bodyweightController,
          'Peso corporal',
          'kg',
          decimal: true,
        ),
        const SizedBox(height: 12),
        _resultPanel(
          context,
          'Puntuación Wilks',
          _wilks.toStringAsFixed(2),
          'Clásica · peso levantado y peso corporal en kg',
        ),
      ],
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    String suffix, {
    bool decimal = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }

  Widget _resultPanel(
    BuildContext context,
    String title,
    String value,
    String caption,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: colors.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4DD0A1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.insights_outlined,
            color: Color(0xFF4DD0A1),
            size: 30,
          ),
        ],
      ),
    );
  }

  Widget _progress(List<CompletedWorkoutEntry> workouts) {
    final colors = Theme.of(context).colorScheme;
    final records = <_LiftRecord>[];
    for (final workout in workouts) {
      for (final exercise in workout.results) {
        final name = exercise['exerciseName']?.toString() ?? '';
        final sets = exercise['sets'] as List<dynamic>? ?? [];
        for (final rawSet in sets) {
          final set = Map<String, dynamic>.from(rawSet as Map);
          final rm = (set['rm'] as num?)?.toDouble() ?? 0;
          final weight = (set['weight'] as num?)?.toDouble() ?? 0;
          if (name.isNotEmpty && rm > 0) {
            records.add(_LiftRecord(name, workout.date, rm, weight));
          }
        }
      }
    }
    final names = records.map((record) => record.name).toSet().toList()..sort();
    if (_selectedExercise != null && !names.contains(_selectedExercise)) {
      _selectedExercise = null;
    }
    if (names.isNotEmpty) _selectedExercise ??= names.first;
    final selected =
        records.where((record) => record.name == _selectedExercise).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final bestWeight = selected.fold<double>(
      0,
      (best, item) => math.max(best, item.weight),
    );
    final bestRm = selected.fold<double>(
      0,
      (best, item) => math.max(best, item.rm),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (names.isEmpty) ...[
          const SizedBox(height: 90),
          const Icon(
            Icons.monitor_heart_outlined,
            size: 52,
            color: Color(0xFF4DD0A1),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'Aún no hay series registradas',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Al guardar tu próximo entrenamiento, aquí aparecerán tus marcas y evolución.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            initialValue: _selectedExercise,
            decoration: const InputDecoration(labelText: 'Ejercicio'),
            items: names
                .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                .toList(),
            onChanged: (value) => setState(() => _selectedExercise = value),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _recordCard(
                  context,
                  'Récord de carga',
                  '${bestWeight.toStringAsFixed(1)} kg',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _recordCard(
                  context,
                  '1RM estimado',
                  '${bestRm.toStringAsFixed(1)} kg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'EVOLUCIÓN · ${selected.length} series',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Container(
            height: 230,
            padding: const EdgeInsets.fromLTRB(8, 14, 14, 10),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomPaint(
              painter: _ProgressPainter(
                selected,
                colors.onSurface,
                colors.onSurfaceVariant,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          for (final record in selected.reversed.take(8))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.trending_up, color: Color(0xFF4DD0A1)),
              title: Text(
                '${record.weight.toStringAsFixed(1)} kg · RM ${record.rm.toStringAsFixed(1)} kg',
              ),
              trailing: Text(
                '${record.date.day}/${record.date.month}/${record.date.year}',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
        ],
      ],
    );
  }

  Widget _recordCard(BuildContext context, String title, String value) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF4DD0A1),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiftRecord {
  final String name;
  final DateTime date;
  final double rm;
  final double weight;
  const _LiftRecord(this.name, this.date, this.rm, this.weight);
}

class _ProgressPainter extends CustomPainter {
  final List<_LiftRecord> records;
  final Color axisColor;
  final Color labelColor;

  const _ProgressPainter(this.records, this.axisColor, this.labelColor);

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 24.0;
    final chart = Rect.fromLTRB(
      inset,
      inset,
      size.width - 8,
      size.height - inset,
    );
    final grid = Paint()
      ..color = axisColor.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = chart.top + chart.height * index / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }
    if (records.isEmpty) return;
    final minValue = records.map((item) => item.rm).reduce(math.min);
    final maxValue = records.map((item) => item.rm).reduce(math.max);
    final spread = math.max(maxValue - minValue, 1.0);
    final points = <Offset>[];
    for (var index = 0; index < records.length; index++) {
      final x = records.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (records.length - 1);
      final y =
          chart.bottom - (records[index].rm - minValue) / spread * chart.height;
      points.add(Offset(x, y));
    }
    final line = Paint()
      ..color = const Color(0xFF4DD0A1)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, line);
    }
    final pointPaint = Paint()..color = const Color(0xFF4DD0A1);
    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }
    final label = TextPainter(textDirection: TextDirection.ltr);
    label.text = TextSpan(
      text: '${maxValue.toStringAsFixed(0)} kg',
      style: TextStyle(color: labelColor, fontSize: 10),
    );
    label.layout();
    label.paint(canvas, Offset(0, chart.top - 5));
    label.text = TextSpan(
      text: '${minValue.toStringAsFixed(0)} kg',
      style: TextStyle(color: labelColor, fontSize: 10),
    );
    label.layout();
    label.paint(canvas, Offset(0, chart.bottom - 8));
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) =>
      oldDelegate.records != records;
}
