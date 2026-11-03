import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/exercise_model.dart';
import '../models/workout_model.dart';
import '../services/workout_service.dart';

import 'calendar_screen.dart';
import 'settings_screen.dart';
import 'training_screen.dart';
import 'utilities_screen.dart';

class HomeScreen extends StatelessWidget {
  final Future<void> Function(bool isDark) onDarkModeChanged;

  const HomeScreen({super.key, required this.onDarkModeChanged});

  static const Color blue = Color(0xFF0755A6);

  static const List<String> days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No hay ningún usuario conectado.')),
      );
    }

    final today = DateTime.now().weekday;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GYM NOTEBOOK',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Configuración de ejercicios y rutinas',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SettingsScreen(onDarkModeChanged: onDarkModeChanged),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Calculadora y progreso',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UtilitiesScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Calendario',
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<WorkoutModel?>(
        stream: WorkoutService().watchWorkout(user.uid, today),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error al cargar el entrenamiento:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final workout = snapshot.data;

          if (workout == null) {
            return const Center(
              child: Text('No hay entrenamiento configurado para hoy.'),
            );
          }

          if (workout.isRestDay) {
            return _restDay();
          }

          return _workoutContent(context, workout, today);
        },
      ),
    );
  }

  Widget _restDay() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hotel_outlined, size: 80, color: blue),
          SizedBox(height: 20),
          Text(
            'DÍA DE DESCANSO',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Hoy toca recuperar fuerzas.'),
        ],
      ),
    );
  }

  Widget _workoutContent(BuildContext context, WorkoutModel workout, int day) {
    final exercises = [...workout.exercises]
      ..sort((a, b) => a.order.compareTo(b.order));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          days[day - 1].toUpperCase(),
          style: const TextStyle(
            color: blue,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          workout.name,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        if (workout.targetDurationMinutes != null)
          _infoChip(
            context,
            Icons.timer_outlined,
            '${workout.targetDurationMinutes} minutos previstos',
          ),

        if (workout.circuitRounds != null)
          _infoChip(
            context,
            Icons.repeat,
            '${workout.circuitRounds} vueltas de circuito',
          ),

        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TrainingScreen(workout: workout),
            ),
          ),
          icon: const Icon(Icons.play_arrow),
          label: const Text('INICIAR ENTRENAMIENTO'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 20),

        const Text(
          'EJERCICIOS',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),

        const SizedBox(height: 10),

        ...exercises.map((exercise) => _ExerciseCard(exercise: exercise)),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String label) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: colors.onSecondaryContainer),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final ExerciseModel exercise;

  const _ExerciseCard({required this.exercise});

  String _formatRest(int seconds) {
    if (seconds <= 0) return 'No especificado';

    if (seconds >= 60) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;

      if (remainingSeconds == 0) return '$minutes min';

      return '$minutes min $remainingSeconds s';
    }

    return '$seconds s';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            if (exercise.type == 'cardio' || exercise.muscleGroup == 'Cardio')
              Text(
                'Duración: ${((exercise.durationSeconds ?? 0) / 60).ceil()} min',
              )
            else if (exercise.isTimed)
              Text('Duración: ${exercise.durationSeconds ?? 0} segundos')
            else if (exercise.sets > 0)
              Text(
                '${exercise.sets} series · '
                '${exercise.minReps}-${exercise.maxReps} repeticiones',
              )
            else if (exercise.minReps > 0)
              Text('${exercise.minReps}-${exercise.maxReps} repeticiones')
            else
              const Text(
                'Series y repeticiones pendientes de configurar',
                style: TextStyle(color: Colors.orangeAccent),
              ),

            if (exercise.restSeconds > 0) ...[
              const SizedBox(height: 5),
              Text(
                'Descanso: ${_formatRest(exercise.restSeconds)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                exercise.notes!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
