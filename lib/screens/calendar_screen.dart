import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/workout_model.dart';
import '../services/calendar_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const Color blue = Color(0xFF0755A6);
  static const Color green = Color(0xFF218838);

  static const List<String> months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static const List<String> weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  final CalendarService _service = CalendarService();

  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  late Future<List<WorkoutModel>> _routineFuture;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _visibleMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);

    final user = FirebaseAuth.instance.currentUser;

    _routineFuture = user == null
        ? Future.value([])
        : _service.getWeeklyRoutine(user.uid);
  }

  void _changeMonth(int amount) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + amount,
      );

      _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    });
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  WorkoutModel? _workoutForDay(List<WorkoutModel> routine, DateTime date) {
    for (final workout in routine) {
      if (workout.dayOfWeek == date.weekday) {
        return workout;
      }
    }

    return null;
  }

  List<CompletedWorkoutEntry> _completedForDay(
    List<CompletedWorkoutEntry> completed,
    DateTime date,
  ) {
    return completed.where((entry) => _sameDay(entry.date, date)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No hay ningún usuario conectado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CALENDARIO',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<WorkoutModel>>(
        future: _routineFuture,
        builder: (context, routineSnapshot) {
          if (routineSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (routineSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error al cargar la rutina:\n'
                  '${routineSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final routine = routineSnapshot.data ?? [];

          return StreamBuilder<List<CompletedWorkoutEntry>>(
            stream: _service.watchCompletedWorkouts(user.uid, _visibleMonth),
            builder: (context, historySnapshot) {
              if (historySnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error al cargar el historial:\n'
                      '${historySnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (historySnapshot.connectionState == ConnectionState.waiting &&
                  !historySnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final completed = historySnapshot.data ?? [];

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _monthHeader(),
                  const SizedBox(height: 16),
                  _calendarGrid(routine, completed),
                  const SizedBox(height: 16),
                  _legend(),
                  const SizedBox(height: 24),
                  _selectedDayDetails(routine, completed),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // --------------------------------------------------
  // CABECERA DEL MES
  // --------------------------------------------------

  Widget _monthHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          '${months[_visibleMonth.month - 1]} '
          '${_visibleMonth.year}',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // CALENDARIO MENSUAL
  // --------------------------------------------------

  Widget _calendarGrid(
    List<WorkoutModel> routine,
    List<CompletedWorkoutEntry> completed,
  ) {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);

    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;

    final offset = firstDay.weekday - 1;
    final totalCells = ((offset + daysInMonth + 6) ~/ 7) * 7;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        Row(
          children: weekdays.map((day) {
            return Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.85,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
          ),
          itemBuilder: (context, index) {
            if (index < offset || index >= offset + daysInMonth) {
              return const SizedBox();
            }

            final dayNumber = index - offset + 1;

            final date = DateTime(
              _visibleMonth.year,
              _visibleMonth.month,
              dayNumber,
            );

            final workout = _workoutForDay(routine, date);

            final isRest = workout == null || workout.isRestDay;

            final isCompleted = _completedForDay(completed, date).isNotEmpty;

            final isSelected = _sameDay(date, _selectedDate);
            final isToday = _sameDay(date, today);

            Color? background;
            Color textColor = Theme.of(context).colorScheme.onSurface;

            if (isSelected) {
              background = blue;
              textColor = Colors.white;
            } else if (isToday) {
              background = blue.withValues(alpha: 0.08);
            }

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _selectedDate = date;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                  border: isToday && !isSelected
                      ? Border.all(color: blue, width: 1.5)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: isToday || isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (isCompleted)
                      _dot(isSelected ? Colors.white : green)
                    else if (!isRest)
                      _dot(isSelected ? Colors.white : blue)
                    else
                      const SizedBox(height: 7),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // --------------------------------------------------
  // LEYENDA
  // --------------------------------------------------

  Widget _legend() {
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        _legendItem(blue, 'Programado'),
        _legendItem(green, 'Completado'),
        _legendItem(Colors.grey, 'Descanso'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // --------------------------------------------------
  // DETALLE DEL DÍA SELECCIONADO
  // --------------------------------------------------

  Widget _selectedDayDetails(
    List<WorkoutModel> routine,
    List<CompletedWorkoutEntry> completed,
  ) {
    final date = _selectedDate;

    final workout = _workoutForDay(routine, date);

    final completedEntries = _completedForDay(completed, date);

    // Convertimos los ejercicios en una lista independiente
    // y los ordenamos antes de crear los widgets.
    final exercises = workout?.exercises.toList() ?? [];

    exercises.sort((a, b) => a.order.compareTo(b.order));

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final isPast = date.isBefore(today);

    final dateLabel =
        '${date.day} de ${months[date.month - 1]} '
        'de ${date.year}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateLabel,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            // ENTRENAMIENTO COMPLETADO
            if (completedEntries.isNotEmpty) ...[
              const Row(
                children: [
                  Icon(Icons.check_circle, color: green),
                  SizedBox(width: 8),
                  Text(
                    'ENTRENAMIENTO COMPLETADO',
                    style: TextStyle(color: green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              ...completedEntries.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fitness_center, color: blue),
                  title: Text(
                    entry.workoutName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Entrenamiento realizado'),
                ),
              ),
            ]
            // DÍA DE DESCANSO
            else if (workout == null || workout.isRestDay) ...[
              const Icon(Icons.hotel_outlined, size: 40, color: Colors.grey),

              const SizedBox(height: 8),

              const Text(
                'DÍA DE DESCANSO',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const Text('Hoy toca recuperar fuerzas.'),
            ]
            // ENTRENAMIENTO PENDIENTE O FUTURO
            else ...[
              Row(
                children: [
                  Icon(
                    isPast ? Icons.info_outline : Icons.fitness_center,
                    color: blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPast
                          ? 'ENTRENAMIENTO PROGRAMADO'
                          : 'PRÓXIMO ENTRENAMIENTO',
                      style: const TextStyle(
                        color: blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Text(
                workout.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text('${exercises.length} ejercicios'),

              if (isPast) ...[
                const SizedBox(height: 10),
                const Text(
                  'Todavía no consta como completado.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],

              const SizedBox(height: 12),

              const Divider(),

              // CADA EJERCICIO SE CONVIERTE EN UN WIDGET
              ...exercises.map<Widget>((exercise) {
                final subtitle = exercise.isTimed
                    ? '${exercise.durationSeconds ?? 0} segundos'
                    : '${exercise.sets} series · '
                          '${exercise.minReps}-${exercise.maxReps} repeticiones';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.check_box_outline_blank,
                    color: blue,
                  ),
                  title: Text(exercise.name),
                  subtitle: Text(subtitle),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
