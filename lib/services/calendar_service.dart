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

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  String _sessionId(WorkoutModel workout, DateTime date) {
    final day = _day(date);
    final dateKey =
        '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    return '${dateKey}_${Uri.encodeComponent(workout.id)}';
  }

  Future<List<WorkoutModel>> getWeeklyRoutine(String uid) {
    return _workoutService.getAllWorkouts(uid);
  }

  /// Recupera la sesión de un entrenamiento en una fecha concreta.
  /// Las nuevas sesiones utilizan un identificador único por día y rutina.
  Future<CompletedWorkoutEntry?> getWorkoutSession({
    required String uid,
    required WorkoutModel workout,
    required DateTime date,
  }) async {
    final document = _historyCollection(uid).doc(_sessionId(workout, date));
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) return null;

    return CompletedWorkoutEntry.fromMap(snapshot.id, snapshot.data()!);
  }

  /// Guarda o actualiza una sesión. Puede estar en curso o completada.
  /// Siempre utiliza el mismo documento para ese entrenamiento y ese día.
  Future<void> saveWorkoutSession({
    required String uid,
    required WorkoutModel workout,
    required DateTime date,
    required String status,
    String notes = '',
    double? bodyWeight,
    List<Map<String, dynamic>> results = const [],
  }) async {
    if (status != 'inProgress' && status != 'completed') {
      throw ArgumentError.value(status, 'status', 'Estado no válido');
    }

    final document = _historyCollection(uid).doc(_sessionId(workout, date));
    final existing = await document.get();

    final data = <String, dynamic>{
      'workoutId': workout.id,
      'workoutName': workout.name,
      'date': Timestamp.fromDate(_day(date)),
      'exercises': workout.exercises.map((e) => e.toMap()).toList(),
      'results': results,
      'notes': notes,
      'bodyWeight': bodyWeight,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await document.set(data, SetOptions(merge: true));
  }

  /// Escucha los entrenamientos del mes.
  /// Los documentos antiguos sin status se consideran completados.
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
          return snapshot.docs
              .where((doc) => _isCompleted(doc.data()))
              .map(
                (doc) => CompletedWorkoutEntry.fromMap(doc.id, doc.data()),
              )
              .toList();
        });
  }

  /// Historial de entrenamientos completados.
  /// Excluye borradores para que no afecten a récords ni progresión.
  Stream<List<CompletedWorkoutEntry>> watchAllCompletedWorkouts(String uid) {
    return _historyCollection(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((doc) => _isCompleted(doc.data()))
              .map(
                (doc) => CompletedWorkoutEntry.fromMap(doc.id, doc.data()),
              )
              .toList(),
        );
  }

  bool _isCompleted(Map<String, dynamic> data) {
    // Compatibilidad con los entrenamientos guardados antes de añadir status.
    return data['status'] != 'inProgress';
  }

  /// Compatibilidad con el método anterior.
  /// Ahora actualiza la sesión del día en vez de crear un documento nuevo.
  Future<void> saveCompletedWorkout({
    required String uid,
    required WorkoutModel workout,
    required DateTime date,
    String notes = '',
    double? bodyWeight,
    List<Map<String, dynamic>> results = const [],
  }) {
    return saveWorkoutSession(
      uid: uid,
      workout: workout,
      date: date,
      status: 'completed',
      notes: notes,
      bodyWeight: bodyWeight,
      results: results,
    );
  }
}

class CompletedWorkoutEntry {
  final String id;
  final DateTime date;
  final String workoutName;
  final String workoutId;
  final List<Map<String, dynamic>> results;
  final double? bodyWeight;
  final String notes;
  final String status;

  const CompletedWorkoutEntry({
    required this.id,
    required this.date,
    required this.workoutName,
    required this.workoutId,
    this.results = const [],
    this.bodyWeight,
    this.notes = '',
    this.status = 'completed',
  });

  bool get isCompleted => status != 'inProgress';

  factory CompletedWorkoutEntry.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final dateValue = map['date'];
    final date = dateValue is Timestamp
        ? dateValue.toDate()
        : dateValue is DateTime
            ? dateValue
            : DateTime.now();

    return CompletedWorkoutEntry(
      id: id,
      date: date,
      workoutName: map['workoutName']?.toString() ?? '',
      workoutId: map['workoutId']?.toString() ?? '',
      results: (map['results'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      bodyWeight: (map['bodyWeight'] as num?)?.toDouble(),
      notes: map['notes']?.toString() ?? '',
      status: map['status']?.toString() ?? 'completed',
    );
  }
}