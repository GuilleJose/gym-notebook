
class SetModel {
  final int setNumber;
  final double weight;
  final int reps;
  final double rm;
  final bool completed;

  const SetModel({
    required this.setNumber,
    this.weight = 0,
    this.reps = 0,
    this.rm = 0,
    this.completed = false,
  });

  static double calculateRM(double weight, int reps) {
    if (weight <= 0 || reps <= 0) return 0;

    return weight * (1 + reps / 30);
  }

  Map<String, dynamic> toMap() {
    return {
      'setNumber': setNumber,
      'weight': weight,
      'reps': reps,
      'rm': rm,
      'completed': completed,
    };
  }

  factory SetModel.fromMap(Map<String, dynamic> map) {
    return SetModel(
      setNumber: map['setNumber'] ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      reps: map['reps'] ?? 0,
      rm: (map['rm'] as num?)?.toDouble() ?? 0,
      completed: map['completed'] ?? false,
    );
  }
}
