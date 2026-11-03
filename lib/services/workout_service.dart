import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/workout_model.dart';
import 'default_workout.dart';

class WorkoutService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _routineCollection(String uid) {
    return _db.collection('usuarios').doc(uid).collection('rutina_semanal');
  }

  /// Carga la rutina inicial sin sobrescribir documentos existentes.
  Future<void> initializeDefaultRoutine(String uid) async {
    final collection = _routineCollection(uid);
    final batch = _db.batch();

    for (final workout in DefaultWorkout.workouts) {
      final document = collection.doc(workout.id);
      final snapshot = await document.get();

      if (!snapshot.exists) {
        batch.set(document, {
          ...workout.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    final existingWorkouts = await collection.get();
    for (final document in existingWorkouts.docs) {
      final cardioMinutes =
          (document.data()['cardioMinutes'] as num?)?.toInt() ?? 0;
      if (cardioMinutes > 0) {
        batch.set(document.reference, {
          'cardioMinutes': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await batch.commit();
  }

  /// Recupera un entrenamiento concreto.
  Future<WorkoutModel?> getWorkout(String uid, int dayOfWeek) async {
    final snapshot = await _routineCollection(uid)
        .where('dayOfWeek', isEqualTo: dayOfWeek)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return WorkoutModel.fromMap(snapshot.docs.first.data());
  }

  /// Escucha los cambios de un entrenamiento.
  Stream<WorkoutModel?> watchWorkout(String uid, int dayOfWeek) {
    return _routineCollection(uid)
        .where('dayOfWeek', isEqualTo: dayOfWeek)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;

          return WorkoutModel.fromMap(snapshot.docs.first.data());
        });
  }

  /// Recupera toda la rutina semanal.
  Future<List<WorkoutModel>> getAllWorkouts(String uid) async {
    final snapshot = await _routineCollection(uid).orderBy('dayOfWeek').get();

    return snapshot.docs
        .map((doc) => WorkoutModel.fromMap(doc.data()))
        .toList();
  }

  /// Actualiza un entrenamiento sin modificar los demás.
  Future<void> updateWorkout(String uid, WorkoutModel workout) async {
    await _routineCollection(uid).doc(workout.id).set({
      ...workout.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Elimina un entrenamiento de la rutina semanal.
  Future<void> deleteWorkout(String uid, String workoutId) async {
    await _routineCollection(uid).doc(workoutId).delete();
  }
}
