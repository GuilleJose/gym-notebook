
import 'package:health/health.dart';

class DailyActivity {
  final int steps;
  final double? calories;
  final double? distanceMeters;

  const DailyActivity({
    required this.steps,
    this.calories,
    this.distanceMeters,
  });
}

class StepsService {
  final Health _health = Health();

  Future<void> configure() async {
    await _health.configure();
  }

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
  ];

  static const List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  Future<bool> requestPermissions() async {
    await configure();

    return _health.requestAuthorization(
      _types,
      permissions: _permissions,
    );
  }

  Future<bool> hasPermissions() async {
    await configure();

    final result = await _health.hasPermissions(
      _types,
      permissions: _permissions,
    );

    return result ?? false;
  }

  Future<DailyActivity> getTodayActivity() async {
    await configure();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final steps = await _health.getTotalStepsInInterval(
      startOfDay,
      now,
    );

    final points = await _health.getHealthIntervalDataFromTypes(
      types: [
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ],
      startDate: startOfDay,
      endDate: now,
      interval: 86400,
    );

    double? calories;
    double? distanceMeters;

    for (final point in points) {
      final value = (point.value as NumericHealthValue).numericValue;

      if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
        calories = (calories ?? 0) + value;
      }

      if (point.type == HealthDataType.DISTANCE_DELTA) {
        distanceMeters = (distanceMeters ?? 0) + value;
      }
    }

    return DailyActivity(
      steps: steps,
      calories: calories,
      distanceMeters: distanceMeters,
    );
  }
}
