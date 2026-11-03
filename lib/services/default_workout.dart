
import '../models/exercise_model.dart';
import '../models/workout_model.dart';

class DefaultWorkout {
  static ExerciseModel exercise({
    required String id,
    required String name,
    required int order,
    int sets = 0,
    int minReps = 0,
    int maxReps = 0,
    int restSeconds = 0,
    String type = 'normal',
    String? notes,
    bool isTimed = false,
    int? durationSeconds,
  }) {
    return ExerciseModel(
      id: id,
      name: name,
      order: order,
      sets: sets,
      minReps: minReps,
      maxReps: maxReps,
      restSeconds: restSeconds,
      type: type,
      notes: notes,
      isTimed: isTimed,
      durationSeconds: durationSeconds,
    );
  }

  static final List<WorkoutModel> workouts = [

    // DÍA 1 - PUSH A
    WorkoutModel(
      id: 'push_a',
      name: 'PUSH A - Pecho',
      dayOfWeek: 1,
      exercises: [
        exercise(id: 'push_a_01', name: 'Press banca plano', order: 1,
            sets: 4, minReps: 6, maxReps: 8, restSeconds: 180),
        exercise(id: 'push_a_02', name: 'Press inclinado mancuernas', order: 2,
            sets: 3, minReps: 8, maxReps: 10, restSeconds: 90),
        exercise(id: 'push_a_03', name: 'Press militar mancuernas 70°', order: 3,
            sets: 3, minReps: 8, maxReps: 10, restSeconds: 120),
        exercise(id: 'push_a_04', name: 'Elevaciones laterales', order: 4,
            sets: 3, minReps: 12, maxReps: 15, restSeconds: 60),
        exercise(id: 'push_a_05', name: 'Fondos paralelas', order: 5,
            sets: 2, minReps: 8, maxReps: 12, restSeconds: 75),
        exercise(id: 'push_a_06', name: 'Extensión tríceps polea', order: 6,
            sets: 3, minReps: 10, maxReps: 12, restSeconds: 60),
        exercise(id: 'push_a_07', name: 'Tríceps katana', order: 7),
      ],
    ),

    // DÍA 2 - PULL A
    WorkoutModel(
      id: 'pull_a',
      name: 'PULL A - Espalda + ABS',
      dayOfWeek: 2,
      circuitRounds: 3,
      exercises: [
        exercise(id: 'pull_a_01', name: 'Dominadas lastradas', order: 1,
            sets: 4, minReps: 6, maxReps: 8, restSeconds: 150),
        exercise(id: 'pull_a_02', name: 'Remo punta', order: 2,
            sets: 3, minReps: 8, maxReps: 10, restSeconds: 120),
        exercise(id: 'pull_a_03', name: 'Jalón neutro', order: 3,
            sets: 3, minReps: 10, maxReps: 12, restSeconds: 90),
        exercise(id: 'pull_a_04', name: 'Face pull', order: 4,
            sets: 3, minReps: 12, maxReps: 15, restSeconds: 60),
        exercise(id: 'pull_a_05', name: 'Encogimientos trapecio', order: 5),
        exercise(id: 'pull_a_06', name: 'Curl barra Z', order: 6,
            sets: 3, minReps: 8, maxReps: 10, restSeconds: 75),
        exercise(id: 'pull_a_07', name: 'Curl inclinado mancuernas', order: 7,
            sets: 2, minReps: 10, maxReps: 12, restSeconds: 60),

        exercise(id: 'pull_a_abs_01', name: 'Crunch polea', order: 8,
            minReps: 12, maxReps: 15, restSeconds: 60, type: 'abs'),
        exercise(id: 'pull_a_abs_02', name: 'Elevación piernas colgado', order: 9,
            minReps: 12, maxReps: 15, restSeconds: 60, type: 'abs'),
        exercise(id: 'pull_a_abs_03', name: 'Oblicuos polea', order: 10,
            minReps: 12, maxReps: 15, restSeconds: 60,
            type: 'abs', notes: '12-15 repeticiones por lado'),
      ],
    ),

    // DÍA 3 - PIERNA A
    WorkoutModel(
      id: 'pierna_a',
      name: 'PIERNA A',
      dayOfWeek: 3,
      targetDurationMinutes: 60,
      exercises: [
        exercise(id: 'pierna_a_01', name: 'Prensa', order: 1,
            sets: 3, minReps: 8, maxReps: 10, restSeconds: 120),
        exercise(id: 'pierna_a_02', name: 'Curl femoral', order: 2,
            sets: 3, minReps: 10, maxReps: 12, restSeconds: 75),
        exercise(id: 'pierna_a_03', name: 'Extensión cuádriceps', order: 3,
            sets: 3, minReps: 12, maxReps: 15, restSeconds: 75),
        exercise(id: 'pierna_a_04', name: 'Hip thrust', order: 4,
            sets: 3, minReps: 10, maxReps: 12, restSeconds: 90),
        exercise(id: 'pierna_a_05', name: 'Gemelos de pie', order: 5,
            sets: 4, minReps: 12, maxReps: 15, restSeconds: 60),
      ],
    ),

    // DÍA 4 - PUSH B
    WorkoutModel(
      id: 'push_b',
      name: 'PUSH B - Hombro',
      dayOfWeek: 4,
      exercises: [
        exercise(id: 'push_b_01', name: 'Banca Bilbo', order: 1,
            sets: 1, minReps: 15, maxReps: 20,
            type: 'bilbo', notes: 'Serie especial Bilbo'),
        exercise(id: 'push_b_02', name: 'Press inclinado barra 30°', order: 2,
            sets: 4, minReps: 8, maxReps: 10, restSeconds: 150),
        exercise(id: 'push_b_03', name: 'Press declinado máquina', order: 3),
        exercise(id: 'push_b_04', name: 'Cruces polea / aperturas', order: 4,
            sets: 3, minReps: 12, maxReps: 15, restSeconds: 60),
        exercise(id: 'push_b_05', name: 'Press militar máquina', order: 5,
            sets: 3, minReps: 8, maxReps: 10, restSeconds: 120),
        exercise(id: 'push_b_06', name: 'Elevaciones laterales máquina', order: 6,
            sets: 3, minReps: 12, maxReps: 15, restSeconds: 60),
        exercise(id: 'push_b_07', name: 'Press francés polea', order: 7,
            sets: 3, minReps: 10, maxReps: 12, restSeconds: 75),
        exercise(id: 'push_b_08', name: 'Tríceps polea', order: 8,
            sets: 2, minReps: 12, maxReps: 12, restSeconds: 60),
      ],
    ),

    // DÍA 5 - PULL B
    WorkoutModel(
      id: 'pull_b',
      name: 'PULL B - Espalda + ABS',
      dayOfWeek: 5,
      circuitRounds: 3,
      exercises: [
        exercise(id: 'pull_b_01', name: 'Remo máquina agarre bajo', order: 1,
            sets: 4, minReps: 8, maxReps: 10, restSeconds: 120),
        exercise(id: 'pull_b_02', name: 'Jalón abierto', order: 2,
            sets: 3, minReps: 10, maxReps: 12, restSeconds: 90),
        exercise(id: 'pull_b_03', name: 'Pullover polea', order: 3,
            sets: 3, minReps: 12, maxReps: 15, restSeconds: 75),
        exercise(id: 'pull_b_04', name: 'Face pull', order: 4,
            sets: 3, minReps: 12, maxReps: 15, restSeconds: 60),
        exercise(id: 'pull_b_05', name: 'Curl predicador', order: 5,
            sets: 3, minReps: 10, maxReps: 12, restSeconds: 75),
        exercise(id: 'pull_b_06', name: 'Curl concentrado', order: 6,
            sets: 2, minReps: 10, maxReps: 12, restSeconds: 60),
        exercise(id: 'pull_b_07', name: 'Curl martillo', order: 7,
            sets: 2, minReps: 10, maxReps: 12, restSeconds: 60),
        exercise(id: 'pull_b_08', name: 'Curl muñeca sentado', order: 8),

        exercise(id: 'pull_b_abs_01', name: 'Crunch polea', order: 9,
            minReps: 12, maxReps: 15, restSeconds: 60, type: 'abs'),
        exercise(id: 'pull_b_abs_02', name: 'Elevación piernas colgado', order: 10,
            minReps: 12, maxReps: 15, restSeconds: 60, type: 'abs'),
        exercise(id: 'pull_b_abs_03', name: 'Oblicuos polea', order: 11,
            minReps: 12, maxReps: 15, restSeconds: 60,
            type: 'abs', notes: '12-15 repeticiones por lado'),
      ],
    ),

    // DÍA 6 - PIERNA B
    WorkoutModel(
      id: 'pierna_b',
      name: 'PIERNA B',
      dayOfWeek: 6,
      circuitRounds: 3,
      exercises: [
        exercise(id: 'pierna_b_01', name: 'Hip thrust', order: 1,
            sets: 3, minReps: 10, maxReps: 12, restSeconds: 90),
        exercise(id: 'pierna_b_02', name: 'Prensa pies altos', order: 2,
            sets: 3, minReps: 10, maxReps: 12, restSeconds: 120),
        exercise(id: 'pierna_b_03', name: 'Curl femoral', order: 3,
            sets: 4, minReps: 10, maxReps: 12, restSeconds: 75),
        exercise(id: 'pierna_b_04', name: 'Extensión cuádriceps', order: 4,
            sets: 3, minReps: 12, maxReps: 15, restSeconds: 60),
        exercise(id: 'pierna_b_05', name: 'Abductores', order: 5,
            sets: 3, minReps: 15, maxReps: 20, restSeconds: 60),
        exercise(id: 'pierna_b_06', name: 'Gemelo sentado', order: 6,
            sets: 4, minReps: 15, maxReps: 20, restSeconds: 60),

        exercise(id: 'pierna_b_core_01', name: 'Plancha peso', order: 7,
            restSeconds: 60, type: 'core', isTimed: true,
            durationSeconds: 40),
        exercise(id: 'pierna_b_core_02', name: 'Elevación piernas', order: 8,
            minReps: 12, maxReps: 15, restSeconds: 60, type: 'core'),
        exercise(id: 'pierna_b_core_03', name: 'Plancha lateral', order: 9,
            restSeconds: 60, type: 'core', isTimed: true,
            durationSeconds: 30, notes: '30 segundos por lado'),
        exercise(id: 'pierna_b_core_04', name: 'Ab wheel', order: 10,
            minReps: 8, maxReps: 12, restSeconds: 60, type: 'core'),
      ],
    ),

    // DÍA 7 - DESCANSO
    WorkoutModel(
      id: 'descanso',
      name: 'DESCANSO',
      dayOfWeek: 7,
      exercises: [],
      isRestDay: true,
    ),
  ];
}
