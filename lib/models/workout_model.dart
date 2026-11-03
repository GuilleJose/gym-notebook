
import 'exercise_model.dart';

class WorkoutModel {
  final String id;
  final String name;
  final int dayOfWeek;
  final List<ExerciseModel> exercises;
  final int cardioMinutes;
  final int? targetDurationMinutes;
  final bool isRestDay;
  final int? circuitRounds;

  const WorkoutModel({
    required this.id,
    required this.name,
    required this.dayOfWeek,
    required this.exercises,
    this.cardioMinutes = 0,
    this.targetDurationMinutes,
    this.isRestDay = false,
    this.circuitRounds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dayOfWeek': dayOfWeek,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'cardioMinutes': cardioMinutes,
      'targetDurationMinutes': targetDurationMinutes,
      'isRestDay': isRestDay,
      'circuitRounds': circuitRounds,
    };
  }

  factory WorkoutModel.fromMap(Map<String, dynamic> map) {
    return WorkoutModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      dayOfWeek: map['dayOfWeek'] ?? 1,
      exercises: (map['exercises'] as List<dynamic>? ?? [])
          .map((e) => ExerciseModel.fromMap(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
      cardioMinutes: map['cardioMinutes'] ?? 0,
      targetDurationMinutes: map['targetDurationMinutes'],
      isRestDay: map['isRestDay'] ?? false,
      circuitRounds: map['circuitRounds'],
    );
  }
}
