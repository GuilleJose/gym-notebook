import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/exercise_model.dart';
import '../models/workout_model.dart';
import 'workout_service.dart';

class ExerciseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final WorkoutService _workouts = WorkoutService();

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _db.collection('usuarios').doc(uid).collection('ejercicios');
  }

  Future<List<ExerciseModel>> getCatalog(String uid) async {
    final collection = _collection(uid);
    final snapshot = await collection.orderBy('name').get();
    List<ExerciseModel> exercises;
    if (snapshot.docs.isNotEmpty) {
      exercises = snapshot.docs
          .map((doc) => ExerciseModel.fromMap(doc.data()))
          .toList();
    } else {
      exercises = await _migrateCatalog(uid, collection);
    }

    if (exercises.isNotEmpty) {
      exercises = await _repairUnknownCatalogGroups(uid, exercises);
      await _repairMissingRoutineGroups(uid, exercises);
    }
    return exercises..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<List<ExerciseModel>> _repairUnknownCatalogGroups(
    String uid,
    List<ExerciseModel> catalog,
  ) async {
    final batch = _db.batch();
    final repaired = <ExerciseModel>[];
    var changed = false;
    for (final exercise in catalog) {
      final inferredGroup = _guessGroup(exercise.name);
      if (exercise.muscleGroup == 'Otros' && inferredGroup != 'Otros') {
        final updated = _copyExercise(exercise, muscleGroup: inferredGroup);
        repaired.add(updated);
        batch.set(_collection(uid).doc(exercise.id), updated.toMap());
        changed = true;
      } else {
        repaired.add(exercise);
      }
    }
    if (changed) await batch.commit();
    return repaired;
  }

  Future<List<ExerciseModel>> _migrateCatalog(
    String uid,
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final routines = await _workouts.getAllWorkouts(uid);
    final exercises = <String, ExerciseModel>{};
    for (final routine in routines) {
      for (final exercise in routine.exercises) {
        exercises.putIfAbsent(
          exercise.name.trim().toLowerCase(),
          () => ExerciseModel(
            id: exercise.id,
            name: exercise.name,
            muscleGroup: _guessGroup(exercise.name),
            order: 0,
            sets: exercise.sets,
            minReps: exercise.minReps,
            maxReps: exercise.maxReps,
            restSeconds: exercise.restSeconds,
            progressionIncrementKg: _defaultIncrementForGroup(
              _guessGroup(exercise.name),
            ),
            type: exercise.type,
            notes: exercise.notes,
            isTimed: exercise.isTimed,
            durationSeconds: exercise.durationSeconds,
          ),
        );
      }
    }
    if (exercises.isEmpty) return [];

    final batch = _db.batch();
    for (final exercise in exercises.values) {
      batch.set(collection.doc(exercise.id), exercise.toMap());
    }
    await batch.commit();
    return exercises.values.toList();
  }

  Future<void> _repairMissingRoutineGroups(
    String uid,
    List<ExerciseModel> catalog,
  ) async {
    final byId = {for (final item in catalog) item.id: item};
    final byName = {
      for (final item in catalog) item.name.trim().toLowerCase(): item,
    };
    final routines = await _workouts.getAllWorkouts(uid);
    for (final routine in routines) {
      var changed = false;
      final updatedExercises = routine.exercises.map((current) {
        final catalogItem =
            byId[current.id] ?? byName[current.name.trim().toLowerCase()];
        if (catalogItem == null ||
            catalogItem.muscleGroup == 'Otros' ||
            (current.muscleGroup != 'Otros' &&
                current.muscleGroup.trim().isNotEmpty)) {
          return current;
        }
        changed = true;
        return _copyExercise(current, muscleGroup: catalogItem.muscleGroup);
      }).toList();
      if (changed) {
        await _workouts.updateWorkout(
          uid,
          _copyWorkout(routine, updatedExercises),
        );
      }
    }
  }

  Future<void> saveExercise(String uid, ExerciseModel exercise) async {
    final catalogDocument = _collection(uid).doc(exercise.id);
    final catalogSnapshot = await catalogDocument.get();
    final previous = catalogSnapshot.exists
        ? ExerciseModel.fromMap(catalogSnapshot.data()!)
        : null;
    await catalogDocument.set(exercise.toMap());

    final routines = await _workouts.getAllWorkouts(uid);
    for (final routine in routines) {
      var changed = false;
      final updatedExercises = routine.exercises.map((current) {
        final matches =
            current.id == exercise.id ||
            current.name.trim().toLowerCase() ==
                (previous?.name ?? exercise.name).trim().toLowerCase();
        if (!matches) return current;
        changed = true;
        return ExerciseModel(
          id: current.id,
          name: previous == null || previous.name != exercise.name
              ? exercise.name
              : current.name,
          muscleGroup:
              previous == null || previous.muscleGroup != exercise.muscleGroup
              ? exercise.muscleGroup
              : current.muscleGroup,
          order: current.order,
          sets: previous == null || previous.sets != exercise.sets
              ? exercise.sets
              : current.sets,
          minReps: previous == null || previous.minReps != exercise.minReps
              ? exercise.minReps
              : current.minReps,
          maxReps: previous == null || previous.maxReps != exercise.maxReps
              ? exercise.maxReps
              : current.maxReps,
          restSeconds:
              previous == null || previous.restSeconds != exercise.restSeconds
              ? exercise.restSeconds
              : current.restSeconds,
          progressionIncrementKg:
              previous == null ||
                  previous.progressionIncrementKg !=
                      exercise.progressionIncrementKg
              ? exercise.progressionIncrementKg
              : current.progressionIncrementKg,
          type: previous == null || previous.type != exercise.type
              ? exercise.type
              : current.type,
          notes: previous == null || previous.notes != exercise.notes
              ? exercise.notes
              : current.notes,
          isTimed: previous == null || previous.isTimed != exercise.isTimed
              ? exercise.isTimed
              : current.isTimed,
          durationSeconds:
              previous == null ||
                  previous.durationSeconds != exercise.durationSeconds
              ? exercise.durationSeconds
              : current.durationSeconds,
        );
      }).toList();
      if (changed) {
        await _workouts.updateWorkout(
          uid,
          _copyWorkout(routine, updatedExercises),
        );
      }
    }
  }

  WorkoutModel _copyWorkout(
    WorkoutModel workout,
    List<ExerciseModel> exercises,
  ) {
    return WorkoutModel(
      id: workout.id,
      name: workout.name,
      dayOfWeek: workout.dayOfWeek,
      exercises: exercises,
      cardioMinutes: workout.cardioMinutes,
      targetDurationMinutes: workout.targetDurationMinutes,
      isRestDay: workout.isRestDay,
      circuitRounds: workout.circuitRounds,
    );
  }

  ExerciseModel _copyExercise(
    ExerciseModel exercise, {
    required String muscleGroup,
  }) {
    return ExerciseModel(
      id: exercise.id,
      name: exercise.name,
      muscleGroup: muscleGroup,
      order: exercise.order,
      sets: exercise.sets,
      minReps: exercise.minReps,
      maxReps: exercise.maxReps,
      restSeconds: exercise.restSeconds,
      progressionIncrementKg: exercise.progressionIncrementKg,
      type: exercise.type,
      notes: exercise.notes,
      isTimed: exercise.isTimed,
      durationSeconds: exercise.durationSeconds,
    );
  }

  Future<void> deleteExercise(String uid, String exerciseId) {
    return _collection(uid).doc(exerciseId).delete();
  }

  String _guessGroup(String name) {
    final value = name.toLowerCase();
    if (value.contains('muñeca') || value.contains('antebrazo')) {
      return 'Antebrazo';
    }
    if (value.contains('pierna') ||
        value.contains('prensa') ||
        value.contains('cuádriceps') ||
        value.contains('cuadriceps') ||
        value.contains('femoral') ||
        value.contains('gemelo') ||
        value.contains('abductores') ||
        value.contains('hip thrust') ||
        value.contains('glúteo') ||
        value.contains('gluteo')) {
      return 'Pierna';
    }
    if (value.contains('tríceps') ||
        value.contains('triceps') ||
        value.contains('francés') ||
        value.contains('frances')) {
      return 'Tríceps';
    }
    if (value.contains('hombro') ||
        value.contains('militar') ||
        value.contains('laterales')) {
      return 'Hombros';
    }
    if (value.contains('pecho') ||
        value.contains('banca') ||
        value.contains('press') ||
        value.contains('fondos') ||
        value.contains('aperturas') ||
        value.contains('cruces')) {
      return 'Pecho';
    }
    if (value.contains('bíceps') ||
        value.contains('biceps') ||
        value.contains('curl')) {
      return 'Bíceps';
    }
    if (value.contains('espalda') ||
        value.contains('remo') ||
        value.contains('jalón') ||
        value.contains('jalon') ||
        value.contains('dominadas') ||
        value.contains('face pull') ||
        value.contains('pullover') ||
        value.contains('trapecio')) {
      return 'Espalda';
    }
    if (value.contains('plancha') ||
        value.contains('abdominal') ||
        value.contains('crunch') ||
        value.contains('oblicuos') ||
        value.contains('ab wheel') ||
        value.contains('elevación piernas')) {
      return 'Core';
    }
    return 'Otros';
  }

  double _defaultIncrementForGroup(String group) =>
      ['Hombros', 'Bíceps', 'Tríceps'].contains(group) ? 1 : 2.5;
}
