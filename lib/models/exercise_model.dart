class ExerciseModel {
  final String id;
  final String name;
  final String muscleGroup;
  final int order;
  final int sets;
  final int minReps;
  final int maxReps;
  final int restSeconds;
  final double progressionIncrementKg;
  final String type;
  final String? notes;
  final bool isTimed;
  final int? durationSeconds;

  const ExerciseModel({
    required this.id,
    required this.name,
    this.muscleGroup = 'Otros',
    required this.order,
    required this.sets,
    required this.minReps,
    required this.maxReps,
    required this.restSeconds,
    this.progressionIncrementKg = 2.5,
    this.type = 'normal',
    this.notes,
    this.isTimed = false,
    this.durationSeconds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'muscleGroup': muscleGroup,
      'order': order,
      'sets': sets,
      'minReps': minReps,
      'maxReps': maxReps,
      'restSeconds': restSeconds,
      'progressionIncrementKg': progressionIncrementKg,
      'type': type,
      'notes': notes,
      'isTimed': isTimed,
      'durationSeconds': durationSeconds,
    };
  }

  factory ExerciseModel.fromMap(Map<String, dynamic> map) {
    return ExerciseModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      muscleGroup: map['muscleGroup'] ?? 'Otros',
      order: map['order'] ?? 0,
      sets: map['sets'] ?? 0,
      minReps: map['minReps'] ?? 0,
      maxReps: map['maxReps'] ?? 0,
      restSeconds: map['restSeconds'] ?? 0,
      progressionIncrementKg:
          (map['progressionIncrementKg'] as num?)?.toDouble() ??
          (['Hombros', 'Bíceps', 'Tríceps'].contains(map['muscleGroup'])
              ? 1.0
              : 2.5),
      type: map['type'] ?? 'normal',
      notes: map['notes'],
      isTimed: map['isTimed'] ?? false,
      durationSeconds: map['durationSeconds'],
    );
  }
}
