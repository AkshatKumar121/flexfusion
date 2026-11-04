import 'package:flutter_test/flutter_test.dart';
import 'package:flexfusion/features/home/workout_analysis_calculator.dart';

void main() {
  group('WorkoutAnalysisCalculator', () {
    test('uses an inclusive start and exclusive end for date windows', () {
      final start = DateTime(2026, 11, 1);
      final end = DateTime(2026, 11, 8);
      expect(WorkoutAnalysisCalculator.isInRange(start, start, end), isTrue);
      expect(WorkoutAnalysisCalculator.isInRange(end.subtract(const Duration(microseconds: 1)), start, end), isTrue);
      expect(WorkoutAnalysisCalculator.isInRange(end, start, end), isFalse);
      expect(WorkoutAnalysisCalculator.isInRange(start.subtract(const Duration(microseconds: 1)), start, end), isFalse);
      expect(WorkoutAnalysisCalculator.isInRange(null, start, end), isFalse);
    });

    test('converts pounds and leaves kilograms unchanged', () {
      expect(WorkoutAnalysisCalculator.toKilograms(100, 'lb'), closeTo(45.359237, 0.000001));
      expect(WorkoutAnalysisCalculator.toKilograms(100, 'lbs'), closeTo(45.359237, 0.000001));
      expect(WorkoutAnalysisCalculator.toKilograms(100, 'kg'), 100);
    });

    test('calculates Epley estimated one rep max', () {
      expect(WorkoutAnalysisCalculator.estimateOneRepMax(60, 10), closeTo(80, 0.000001));
      expect(WorkoutAnalysisCalculator.estimateOneRepMax(60, 0), 60);
    });

    test('calculates average load only across weighted completed sets', () {
      expect(WorkoutAnalysisCalculator.averageLoadPerWeightedSet(300, 3), 100);
      expect(WorkoutAnalysisCalculator.averageLoadPerWeightedSet(0, 0), 0);
      expect(WorkoutAnalysisCalculator.averageLoadPerWeightedSet(300, 0), 0);
    });

    test('classifies estimated strength progression, not volume change', () {
      WorkoutProgression classify(double current, double previous) =>
          WorkoutAnalysisCalculator.classifyProgression(
            currentEstimatedOneRepMaxKg: current,
            previousEstimatedOneRepMaxKg: previous,
            currentHasWeight: true,
            previousHasWeight: true,
          );

      expect(classify(82, 80), WorkoutProgression.progressing);
      expect(classify(78, 80), WorkoutProgression.declining);
      expect(classify(80, 80), WorkoutProgression.maintaining);
    });

    test('requires weighted current and previous data for a baseline', () {
      expect(
        WorkoutAnalysisCalculator.classifyProgression(
          currentEstimatedOneRepMaxKg: 80,
          previousEstimatedOneRepMaxKg: 80,
          currentHasWeight: false,
          previousHasWeight: true,
        ),
        WorkoutProgression.insufficientBaseline,
      );
      expect(
        WorkoutAnalysisCalculator.classifyProgression(
          currentEstimatedOneRepMaxKg: 80,
          previousEstimatedOneRepMaxKg: null,
          currentHasWeight: true,
          previousHasWeight: false,
        ),
        WorkoutProgression.insufficientBaseline,
      );
    });
  });
}
