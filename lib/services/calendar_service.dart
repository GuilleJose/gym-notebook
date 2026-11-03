import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/workout_model.dart';
import 'workout_service.dart';

class CalendarService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final WorkoutService _workoutService = WorkoutService();

  CollectionReference<Map<String, dynamic>> _historyCollection(String uid) {
    return _db
        .collection('usuarios')
        .doc(uid)
        .collection('entrenamientos_realizados');
  }

  /// Obtiene la rutina semanal configurada.
  Future<List<WorkoutModel>> getWeeklyRoutine(String uid) {
    return _workoutService.getAllWorkouts(uid);
  }

  /// Escucha los entrenamientos realizados de un mes.
  Stream<List<CompletedWorkoutEntry>> watchCompletedWorkouts(
    String uid,
    DateTime month,
  ) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    return _historyCollection(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return CompletedWorkoutEntry.fromMap(doc.id, doc.data());
          }).toList();
        });
  }

  Stream<List<CompletedWorkoutEntry>> watchAllCompletedWorkouts(String uid) {
    return _historyCollection(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CompletedWorkoutEntry.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Guarda un entrenamiento realizado.
  /// Lo conectaremos al botón de finalizar entrenamiento.
  Future<void> saveCompletedWorkout({
    required String uid,
    required WorkoutModel workout,
    required DateTime date,
    String notes = '',
    double? bodyWeight,
    List<Map<String, dynamic>> results = const [],
  }) async {
    final document = _historyCollection(uid).doc();

    await document.set({
      'workoutId': workout.id,
      'workoutName': workout.name,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'exercises': workout.exercises.map((e) => e.toMap()).toList(),
      'results': results,
      'notes': notes,
      'bodyWeight': bodyWeight,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class CompletedWorkoutEntry {
  final String id;
  final DateTime date;
  final String workoutName;
  final String workoutId;
  final List<Map<String, dynamic>> results;
  final double? bodyWeight;

  const CompletedWorkoutEntry({
    required this.id,
    required this.date,
    required this.workoutName,
    required this.workoutId,
    this.results = const [],
    this.bodyWeight,
  });

  factory CompletedWorkoutEntry.fromMap(String id, Map<String, dynamic> map) {
    final dateValue = map['date'];
    final date = dateValue is Timestamp ? dateValue.toDate() : DateTime.now();

    return CompletedWorkoutEntry(
      id: id,
      date: date,
      workoutName: map['workoutName'] ?? '',
      workoutId: map['workoutId'] ?? '',
      results: (map['results'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      bodyWeight: (map['bodyWeight'] as num?)?.toDouble(),
    );
  }
}
