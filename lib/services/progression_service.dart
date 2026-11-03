import '../models/exercise_model.dart';

class ProgressionSet {
  final double weight;
  final int reps;
  final int? rir;

  const ProgressionSet({required this.weight, required this.reps, this.rir});
}

class ProgressionTarget {
  final double weight;
  final int reps;
  final bool increasedLoad;
  final bool deload;
  final bool belowMinimum;

  const ProgressionTarget({
    required this.weight,
    required this.reps,
    required this.increasedLoad,
    required this.deload,
    required this.belowMinimum,
  });
}

class ProgressionService {
  const ProgressionService._();

  static Map<int, ProgressionTarget>? suggestNextSession({
    required ExerciseModel exercise,
    required List<ProgressionSet> previousSets,
    bool reduceNextLoad = false,
    double? previousBodyWeight,
    double? currentBodyWeight,
  }) {
    if (exercise.muscleGroup == 'Cardio' ||
        exercise.type == 'cardio' ||
        exercise.sets < 1 ||
        previousSets.isEmpty) {
      return null;
    }

    final prescribedSets = previousSets.take(exercise.sets).toList();
    final completedAllSets = prescribedSets.length == exercise.sets;
    final increasedLoad =
        completedAllSets &&
        prescribedSets.every(
          (set) =>
              set.reps >= exercise.maxReps && set.rir != null && set.rir! <= 2,
        );
    final firstSet = prescribedSets.first;
    final belowMinimum = firstSet.reps <= exercise.minReps - 2;
    final deload =
        reduceNextLoad ||
        (!increasedLoad && (belowMinimum || firstSet.rir == 0));

    final exerciseName = exercise.name.toLowerCase();
    final usesBodyWeight =
        exerciseName.contains('dominadas') || exerciseName.contains('fondos');
    final bodyWeightAdjustment =
        usesBodyWeight &&
            previousBodyWeight != null &&
            currentBodyWeight != null
        ? previousBodyWeight - currentBodyWeight
        : 0.0;

    final targets = <int, ProgressionTarget>{};
    for (var index = 0; index < exercise.sets; index++) {
      final previous = index < previousSets.length
          ? previousSets[index]
          : previousSets.last;
      var weight = previous.weight + bodyWeightAdjustment;
      var reps = (previous.reps + 1)
          .clamp(exercise.minReps, exercise.maxReps)
          .toInt();

      if (deload) {
        weight -= exercise.progressionIncrementKg * 2;
        reps = exercise.minReps;
      } else if (increasedLoad) {
        weight += exercise.progressionIncrementKg;
        reps = exercise.minReps;
      }

      targets[index + 1] = ProgressionTarget(
        weight: weight < 0 ? 0 : weight,
        reps: reps,
        increasedLoad: increasedLoad,
        deload: deload,
        belowMinimum: previous.reps < exercise.minReps,
      );
    }
    return targets;
  }
}
