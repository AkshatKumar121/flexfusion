/// Pure calculation rules used by workout analysis. No Flutter or database dependencies.
enum WorkoutProgression {
  progressing,
  declining,
  maintaining,
  insufficientBaseline;

  String get label => switch (this) {
        WorkoutProgression.progressing => 'PROGRESSING',
        WorkoutProgression.declining => 'DECLINING',
        WorkoutProgression.maintaining => 'MAINTAINING',
        WorkoutProgression.insufficientBaseline => 'INSUFFICIENT BASELINE',
      };
}

class WorkoutAnalysisCalculator {
  static const double poundsToKilograms = 0.45359237;

  static bool isInRange(DateTime? value, DateTime startInclusive, DateTime endExclusive) {
    return value != null && !value.isBefore(startInclusive) && value.isBefore(endExclusive);
  }

  static double toKilograms(double weight, String unit) {
    final normalized = unit.toLowerCase();
    return normalized == 'lb' || normalized == 'lbs'
        ? weight * poundsToKilograms
        : weight;
  }

  /// Epley estimate: load × (1 + reps / 30). Not a tested 1RM.
  static double estimateOneRepMax(double weightKg, int reps) {
    return reps > 0 ? weightKg * (1 + reps / 30.0) : weightKg;
  }

  /// Mean recorded load across completed sets that have a load.
  /// This is a simple load-intensity proxy, not %1RM or effort/RIR.
  static double averageLoadPerWeightedSet(double totalLoadKg, int weightedSetCount) {
    return weightedSetCount <= 0 ? 0 : totalLoadKg / weightedSetCount;
  }

  static WorkoutProgression classifyProgression({
    required double currentEstimatedOneRepMaxKg,
    required double? previousEstimatedOneRepMaxKg,
    required bool currentHasWeight,
    required bool previousHasWeight,
  }) {
    if (!currentHasWeight ||
        !previousHasWeight ||
        previousEstimatedOneRepMaxKg == null ||
        previousEstimatedOneRepMaxKg <= 0) {
      return WorkoutProgression.insufficientBaseline;
    }
    if (currentEstimatedOneRepMaxKg > previousEstimatedOneRepMaxKg) {
      return WorkoutProgression.progressing;
    }
    if (currentEstimatedOneRepMaxKg < previousEstimatedOneRepMaxKg) {
      return WorkoutProgression.declining;
    }
    return WorkoutProgression.maintaining;
  }
}
