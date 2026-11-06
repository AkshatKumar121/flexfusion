import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppleHealthReadResult {
  final Map<String, Object?>? data;
  final String statusMessage;

  const AppleHealthReadResult({
    required this.data,
    required this.statusMessage,
  });
}

class AppleHealthService {
  final Health _health = Health();

  static const MethodChannel _syncChannel =
      MethodChannel('com.flexfusion/apple_health_sync');
  static const EventChannel _eventChannel =
      EventChannel('com.flexfusion/apple_health_events');

  Stream<String> get healthDataChanges =>
      _eventChannel.receiveBroadcastStream().map((event) => event.toString());

  Future<void> startObserving() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _syncChannel.invokeMethod<void>('startObservers');
    } on PlatformException catch (error) {
      debugPrint('[AppleHealth] Could not start HealthKit observers: $error');
    } on MissingPluginException {
      debugPrint('[AppleHealth] Native HealthKit observer bridge is unavailable.');
    }
  }

  static const _authorizationRequestedKey =
      'apple_health_authorization_requested';
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
      final preferences = await SharedPreferences.getInstance();
      final authorizationWasRequested =
          preferences.getBool(_authorizationRequestedKey) ?? false;

      if (!authorizationWasRequested) {
        final granted = await _health.requestAuthorization(_types);
        await preferences.setBool(_authorizationRequestedKey, true);
        if (!granted) {
          debugPrint(
            '[AppleHealth] Authorization was not granted. '
            'User can manage access in the Apple Health app.',
          );
          return const AppleHealthReadResult(
            data: null,
            statusMessage:
                'Apple Health access is unavailable. Open Health → Profile → Apps and Services → FlexFusion to review access. Manual tracking is available.',
          );
        }
      }

      // Register native observer queries after the initial authorization flow.
      // iOS may also deliver background updates when HealthKit permits it.
      await startObserving();

      // HealthKit intentionally does not reveal read-denial state to apps.
      // Continue reading after the first authorization attempt; an empty
      // result can mean either no recorded data or unavailable read access.
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

      final data = <String, Object?>{
        'steps': steps,
        'distance_km':
            total(HealthDataType.DISTANCE_WALKING_RUNNING) / 1000,
        'active_calories': total(HealthDataType.ACTIVE_ENERGY_BURNED),
        'exercise_minutes': total(HealthDataType.EXERCISE_TIME),
      };
      final hasAnyData = (steps ?? 0) > 0 ||
          (data['distance_km'] as double) > 0 ||
          (data['active_calories'] as double) > 0 ||
          (data['exercise_minutes'] as double) > 0;

      return AppleHealthReadResult(
        data: data,
        statusMessage: hasAnyData
            ? 'Apple Health · synced'
            : 'No Health data returned. If you expected values, review FlexFusion access in the Health app. Manual tracking is available.',
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
            'Apple Health sync failed. Review Health access and try again.',
      );
    }
  }
}
