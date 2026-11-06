import 'package:flutter/material.dart';
import '../../app/auto_refresh_on_return.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';

class WeeklyProgressScreen extends StatefulWidget {
  const WeeklyProgressScreen({super.key});

  @override
  State<WeeklyProgressScreen> createState() => _WeeklyProgressScreenState();
}

class _WeeklyProgressScreenState extends State<WeeklyProgressScreen> with AutoRefreshOnReturn<WeeklyProgressScreen> {
  @override
  Future<void> refreshAfterReturn() async {
    if (!mounted) return;
    setState(() => _summaryFuture = AppDatabase.instance.getWeeklyProgressDetails());
    await _loadWeightUnit();
    await _summaryFuture;
  }

  late Future<Map<String, Object?>> _summaryFuture;
  String _weightUnit = 'kg';

  @override
  void initState() {
    super.initState();
    _summaryFuture = AppDatabase.instance.getWeeklyProgressDetails();
    _loadWeightUnit();
  }

  Future<void> _loadWeightUnit() async {
    final unit = await AppDatabase.instance.getAppSetting(
      'weight_unit',
      defaultValue: 'kg',
    );
    if (mounted) setState(() => _weightUnit = unit);
  }

  String _dateLabel(String value) {
    final parts = value.split('-');
    return '${parts[2]}/${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: Text(
          'WEEKLY PROGRESS',
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, Object?>>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.green),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                'Unable to load weekly progress.',
                style: GoogleFonts.inter(color: AppColors.grey),
              ),
            );
          }
          final data = snapshot.data!;
          final daily = (data['daily'] as List).cast<Map<String, Object?>>();
          final period =
              '${_dateLabel(data['start_date'] as String)} – '
              '${_dateLabel(data['end_date'] as String)}';
          final weightFactor = _weightUnit == 'lb' ? 2.20462 : 1.0;
          final averageWeight = data['average_weight'] as double;
          final previousAverageWeight =
              data['previous_average_weight'] as double;
          final weightDays = data['weight_days'] as int;
          final previousWeightDays = data['previous_weight_days'] as int;
          final hasWeightComparison =
              weightDays > 0 && previousWeightDays > 0;
          final weightDelta =
              (averageWeight - previousAverageWeight) * weightFactor;
          final trackedDays = data['tracked_days'] as int;
          final previousTrackedDays = data['previous_tracked_days'] as int;
          final averageCalories = data['average_calories'] as double;
          final previousCalories =
              data['previous_average_calories'] as double;
          final averageProtein = data['average_protein'] as double;
          final previousProtein = data['previous_average_protein'] as double;
          final workouts = data['workouts'] as int;
          final previousWorkouts = data['previous_workouts'] as int;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR LAST 7 DAYS',
                  style: GoogleFonts.inter(
                    color: AppColors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  period,
                  style: GoogleFonts.inter(
                    color: AppColors.grey,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 18),
                _summaryCard(
                  title: 'WEEKLY AVERAGES',
                  children: [
                    _comparisonRow(
                      'Calories',
                      trackedDays == 0
                          ? '—'
                          : '${averageCalories.round()} kcal/day',
                      _difference(averageCalories, previousCalories,
                          trackedDays > 0 && previousTrackedDays > 0, 'kcal'),
                    ),
                    _comparisonRow(
                      'Protein',
                      trackedDays == 0
                          ? '—'
                          : '${averageProtein.round()} g/day',
                      _difference(averageProtein, previousProtein,
                          trackedDays > 0 && previousTrackedDays > 0, 'g'),
                    ),
                    _comparisonRow(
                      'Weight',
                      weightDays == 0
                          ? '—'
                          : '${(averageWeight * weightFactor).toStringAsFixed(1)} $_weightUnit',
                      !hasWeightComparison
                          ? 'Not enough data'
                          : '${weightDelta > 0 ? '+' : ''}${weightDelta.toStringAsFixed(1)} $_weightUnit vs previous week',
                    ),
                    _comparisonRow(
                      'Completed workouts',
                      '$workouts',
                      '${workouts - previousWorkouts >= 0 ? '+' : ''}${workouts - previousWorkouts} vs previous week',
                      last: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Food logged: $trackedDays/7 days  •  Weigh-ins: $weightDays/7 days',
                      style: GoogleFonts.inter(
                        color: AppColors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _chartCard(
                  title: 'DAILY CALORIE INTAKE',
                  subtitle: 'Average on days with food logged: '
                      '${trackedDays == 0 ? '—' : '${averageCalories.round()} kcal'}',
                  daily: daily,
                  valueKey: 'calories',
                  color: AppColors.green,
                  unit: 'kcal',
                  maxValue: _maxValue(daily, 'calories'),
                ),
                const SizedBox(height: 14),
                _chartCard(
                  title: 'DAILY PROTEIN INTAKE',
                  subtitle: 'Average on days with food logged: '
                      '${trackedDays == 0 ? '—' : '${averageProtein.round()} g'}',
                  daily: daily,
                  valueKey: 'protein',
                  color: AppColors.green,
                  unit: 'g',
                  maxValue: _maxValue(daily, 'protein'),
                ),
                const SizedBox(height: 14),
                _weightChartCard(daily, weightFactor),
                const SizedBox(height: 14),
                _summaryCard(
                  title: 'WORKOUT CONSISTENCY',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$workouts workouts',
                            style: GoogleFonts.inter(
                              color: AppColors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${workouts > previousWorkouts ? '+' : ''}${workouts - previousWorkouts} vs last week',
                          style: GoogleFonts.inter(
                            color: AppColors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: daily.map((day) {
                        final active = (day['workouts'] as int) > 0;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              children: [
                                Container(
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AppColors.red
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  day['day'] as String,
                                  style: GoogleFonts.inter(
                                    color: AppColors.grey,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Each highlighted day represents at least one completed workout.',
                      style: GoogleFonts.inter(
                        color: AppColors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _summaryCard(
                  title: 'WEEK-OVER-WEEK COMPARISON',
                  children: [
                    _comparisonRow(
                      'Average calories',
                      trackedDays == 0 ? '—' : '${averageCalories.round()} kcal',
                      previousTrackedDays == 0
                          ? 'No previous-week data'
                          : 'Previous: ${previousCalories.round()} kcal',
                    ),
                    _comparisonRow(
                      'Average protein',
                      trackedDays == 0 ? '—' : '${averageProtein.round()} g',
                      previousTrackedDays == 0
                          ? 'No previous-week data'
                          : 'Previous: ${previousProtein.round()} g',
                    ),
                    _comparisonRow(
                      'Average weight',
                      weightDays == 0
                          ? '—'
                          : '${(averageWeight * weightFactor).toStringAsFixed(1)} $_weightUnit',
                      previousWeightDays == 0
                          ? 'No previous-week data'
                          : 'Previous: ${(previousAverageWeight * weightFactor).toStringAsFixed(1)} $_weightUnit',
                    ),
                    _comparisonRow(
                      'Workouts',
                      '$workouts',
                      'Previous: $previousWorkouts',
                      last: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Averages use only days with entries. Missing logs are not counted as zero.',
                  style: GoogleFonts.inter(
                    color: AppColors.grey,
                    fontSize: 10,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _maxValue(List<Map<String, Object?>> daily, String key) {
    final values = daily.map((row) => (row[key] as num).toDouble());
    final max = values.fold<double>(0, (a, b) => a > b ? a : b);
    return max <= 0 ? 1 : max * 1.15;
  }

  String _difference(double current, double previous, bool available, String unit) {
    if (!available) return 'No previous-week data';
    final delta = current - previous;
    return '${delta > 0 ? '+' : ''}${delta.round()} $unit vs previous week';
  }

  Widget _summaryCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _comparisonRow(String label, String value, String note, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.inter(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Flexible(
            child: Text(
              note,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartCard({
    required String title,
    required String subtitle,
    required List<Map<String, Object?>> daily,
    required String valueKey,
    required Color color,
    required String unit,
    required double maxValue,
  }) {
    final hasEntries = daily.any((row) => (row[valueKey] as num) > 0);
    return _summaryCard(
      title: title,
      children: [
        Text(subtitle, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
        const SizedBox(height: 16),
        if (!hasEntries)
          SizedBox(
            height: 130,
            child: Center(
              child: Text('Log your meals to see this chart.', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
            ),
          )
        else
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _WeeklyBarPainter(
                values: daily.map((row) => (row[valueKey] as num).toDouble()).toList(),
                maxValue: maxValue,
                color: color,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        const SizedBox(height: 8),
        _dayLabels(daily),
      ],
    );
  }

  Widget _weightChartCard(List<Map<String, Object?>> daily, double factor) {
    final entries = daily.where((row) => row['weight'] != null).toList();
    return _summaryCard(
      title: 'WEIGHT TREND',
      children: [
        Text(
          entries.isEmpty
              ? 'Log your weight to see your trend.'
              : 'Average: ${((entries.map((row) => row['weight'] as double).reduce((a, b) => a + b) / entries.length) * factor).toStringAsFixed(1)} $_weightUnit',
          style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 140,
          child: entries.isEmpty
              ? Center(child: Text('No weigh-ins this week.', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)))
              : CustomPaint(
                  painter: _WeeklyLinePainter(
                    values: daily.map((row) => row['weight'] == null ? null : (row['weight'] as double) * factor).toList(),
                    color: AppColors.red,
                  ),
                  child: const SizedBox.expand(),
                ),
        ),
        const SizedBox(height: 8),
        _dayLabels(daily),
      ],
    );
  }

  Widget _dayLabels(List<Map<String, Object?>> daily) {
    return Row(
      children: daily.map((day) => Expanded(
        child: Center(
          child: Text(day['day'] as String, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9)),
        ),
      )).toList(),
    );
  }
}

class _WeeklyBarPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  final Color color;

  const _WeeklyBarPainter({required this.values, required this.maxValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = AppColors.border..strokeWidth = 0.7;
    for (var i = 0; i < 4; i++) {
      final y = i * size.height / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final bar = Paint()..color = color;
    final slot = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final height = (values[i] / maxValue) * (size.height - 8);
      final rect = Rect.fromLTWH(
        i * slot + slot * 0.25,
        size.height - height,
        slot * 0.5,
        height,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), bar);
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyBarPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.maxValue != maxValue;
}

class _WeeklyLinePainter extends CustomPainter {
  final List<double?> values;
  final Color color;

  const _WeeklyLinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final present = values.whereType<double>().toList();
    if (present.isEmpty) return;
    final minValue = present.reduce((a, b) => a < b ? a : b);
    final maxValue = present.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.01 ? 1.0 : maxValue - minValue;
    final grid = Paint()..color = AppColors.border..strokeWidth = 0.7;
    for (var i = 0; i < 4; i++) {
      final y = i * size.height / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dot = Paint()..color = color;
    final points = <Offset?>[];
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        points.add(null);
      } else {
        final x = values.length == 1 ? size.width / 2 : i * size.width / (values.length - 1);
        final y = size.height - 10 - ((value - minValue) / range) * (size.height - 20);
        points.add(Offset(x, y));
      }
    }
    Path? path;
    for (final point in points) {
      if (point == null) {
        if (path != null) canvas.drawPath(path, line);
        path = null;
      } else if (path == null) {
        path = Path()..moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      if (point != null) canvas.drawCircle(point, 3, dot);
    }
    if (path != null) canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _WeeklyLinePainter oldDelegate) =>
      oldDelegate.values != values;
}
