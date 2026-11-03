import 'package:cloud_firestore/cloud_firestore.dart';

import 'exercise_service.dart';
import 'workout_service.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final WorkoutService _workoutService = WorkoutService();

  Future<String> getThemeMode(String uid) async {
    final snapshot = await _db.collection('usuarios').doc(uid).get();
    return snapshot.data()?['themeMode'] == 'light' ? 'light' : 'dark';
  }

  Future<void> saveThemeMode(String uid, String themeMode) {
    return _db.collection('usuarios').doc(uid).set({
      'themeMode': themeMode,
    }, SetOptions(merge: true));
  }

  Future<bool> getAutomaticTrainingEnabled(String uid) async {
    final snapshot = await _db.collection('usuarios').doc(uid).get();
    return snapshot.data()?['automaticTrainingEnabled'] == true;
  }

  Future<void> saveAutomaticTrainingEnabled(String uid, bool enabled) {
    return _db.collection('usuarios').doc(uid).set({
      'automaticTrainingEnabled': enabled,
    }, SetOptions(merge: true));
  }

  /// Crea el perfil y carga la rutina inicial si todavía no existe.
  Future<void> initializeUser({
    required String uid,
    required String? email,
  }) async {
    final userDocument = _db.collection('usuarios').doc(uid);

    final snapshot = await userDocument.get();

    if (!snapshot.exists) {
      await userDocument.set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Solo crea los entrenamientos que todavía no existen.
    await _workoutService.initializeDefaultRoutine(uid);
    await ExerciseService().getCatalog(uid);
  }
}
