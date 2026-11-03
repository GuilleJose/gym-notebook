import 'package:flutter_test/flutter_test.dart';
import 'package:gym_notebook/models/exercise_model.dart';
import 'package:gym_notebook/services/progression_service.dart';

ExerciseModel _exercise({
  String name = 'Press banca plano',
  String muscleGroup = 'Pecho',
  int sets = 4,
  int minReps = 6,
  int maxReps = 8,
  double increment = 2.5,
}) {
  return ExerciseModel(
    id: 'exercise-1',
    name: name,
    muscleGroup: muscleGroup,
    order: 1,
    sets: sets,
    minReps: minReps,
    maxReps: maxReps,
    restSeconds: 120,
    progressionIncrementKg: increment,
  );
}

void main() {
  group('ProgressionService.suggestNextSession', () {
    test(
      'increases load after every prescribed set reaches the top at RIR 0-2',
      () {
        final targets = ProgressionService.suggestNextSession(
          exercise: _exercise(),
          previousSets: List.generate(
            4,
            (_) => const ProgressionSet(weight: 50, reps: 8, rir: 2),
          ),
        )!;

        expect(targets.length, 4);
        for (final target in targets.values) {
          expect(target.weight, 52.5);
          expect(target.reps, 6);
          expect(target.increasedLoad, isTrue);
        }
      },
    );

    test('keeps load and adds a rep while performance remains in range', () {
      final reps = [7, 7, 6, 6];
      final targets = ProgressionService.suggestNextSession(
        exercise: _exercise(),
        previousSets: reps
            .map((value) => ProgressionSet(weight: 50, reps: value, rir: 2))
            .toList(),
      )!;

      expect(targets.values.map((target) => target.weight), everyElement(50));
      expect(targets.values.map((target) => target.reps), [8, 8, 7, 7]);
      expect(targets.values.every((target) => !target.increasedLoad), isTrue);
    });

    test('deloads two configured increments after a drastic rep drop', () {
      final targets = ProgressionService.suggestNextSession(
        exercise: _exercise(),
        previousSets: const [
          ProgressionSet(weight: 50, reps: 4),
          ProgressionSet(weight: 50, reps: 6, rir: 2),
          ProgressionSet(weight: 50, reps: 6, rir: 2),
          ProgressionSet(weight: 50, reps: 6, rir: 2),
        ],
      )!;

      expect(targets[1]!.weight, 45);
      expect(targets[1]!.reps, 6);
      expect(targets[1]!.deload, isTrue);
    });

    test('adjusts weighted pull-up load when body weight changes', () {
      final targets = ProgressionService.suggestNextSession(
        exercise: _exercise(name: 'Dominadas lastradas', sets: 2),
        previousSets: const [
          ProgressionSet(weight: 10, reps: 6, rir: 2),
          ProgressionSet(weight: 10, reps: 6, rir: 2),
        ],
        previousBodyWeight: 80,
        currentBodyWeight: 77,
      )!;

      expect(targets[1]!.weight, 13);
      expect(targets[1]!.reps, 7);
    });

    test('does not generate load progression for cardio exercises', () {
      final targets = ProgressionService.suggestNextSession(
        exercise: _exercise(name: 'Cinta', muscleGroup: 'Cardio'),
        previousSets: const [ProgressionSet(weight: 0, reps: 0)],
      );

      expect(targets, isNull);
    });
  });
}
