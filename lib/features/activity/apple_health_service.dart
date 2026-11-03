import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

class AppleHealthReadResult {
  final Map<String, Object?>? data;
  final String statusMessage;

  const AppleHealthReadResult({
    required this.data,
    required this.statusMessage,
  });

  bool get isSuccess => data != null;
}

class AppleHealthService {
  final Health _health = Health();

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.EXERCISE_TIME,
  ];

  Future<AppleHealthReadResult> readDailySummary(DateTime date) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return const AppleHealthReadResult(
        data: null,
        statusMessage: 'Apple Health sync is available on iOS only.',
      );
    }

    try {
      await _health.configure();
      final hasReadAccess = await _health.hasPermissions(_types) ?? false;
      if (!hasReadAccess && !await _health.requestAuthorization(_types)) {
        debugPrint(
          '[AppleHealth] Read permission was not granted. '
          'Manual activity tracking remains available.',
        );
        return const AppleHealthReadResult(
          data: null,
          statusMessage:
              'Apple Health permission not granted. Manual tracking is available.',
        );
      }

      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      final steps = await _health.getTotalStepsInInterval(start, end);
      final points = _health.removeDuplicates(
        await _health.getHealthDataFromTypes(
          types: _types.where((t) => t != HealthDataType.STEPS).toList(),
          startTime: start,
          endTime: end,
        ),
      );

      double total(HealthDataType type) => points
          .where((p) => p.type == type)
          .fold<double>(
            0,
            (sum, p) => sum +
                (p.value is NumericHealthValue
                    ? (p.value as NumericHealthValue).numericValue
                    : 0),
          );

      return AppleHealthReadResult(
        data: {
          'steps': steps,
          'distance_km':
              total(HealthDataType.DISTANCE_WALKING_RUNNING) / 1000,
          'active_calories': total(HealthDataType.ACTIVE_ENERGY_BURNED),
          'exercise_minutes': total(HealthDataType.EXERCISE_TIME),
        },
        statusMessage: 'Apple Health · synced',
      );
    } catch (error, stackTrace) {
      debugPrint('[AppleHealth] Daily summary sync failed: $error');
      debugPrintStack(
        label: '[AppleHealth] Stack trace',
        stackTrace: stackTrace,
      );
      return const AppleHealthReadResult(
        data: null,
        statusMessage:
            'Apple Health sync failed. Check Health permissions and try again.',
      );
    }
  }
}
