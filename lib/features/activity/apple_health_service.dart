import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
class AppleHealthService {
 final Health _health=Health();
 static const List<HealthDataType> _types=[HealthDataType.STEPS,HealthDataType.DISTANCE_WALKING_RUNNING,HealthDataType.ACTIVE_ENERGY_BURNED,HealthDataType.EXERCISE_TIME];
 Future<Map<String,Object?>?> readDailySummary(DateTime date) async {
  if(kIsWeb||defaultTargetPlatform!=TargetPlatform.iOS)return null;
  try {
   await _health.configure();
   if(!await _health.requestAuthorization(_types))return null;
   final start=DateTime(date.year,date.month,date.day),end=DateTime(date.year,date.month,date.day).add(const Duration(days:1));
   final steps=await _health.getTotalStepsInInterval(start,end);
   final points=_health.removeDuplicates(await _health.getHealthDataFromTypes(types:_types.where((t)=>t!=HealthDataType.STEPS).toList(),startTime:start,endTime:end));
   double total(HealthDataType type)=>points.where((p)=>p.type==type).fold<double>(0,(sum,p)=>sum+(p.value is NumericHealthValue?(p.value as NumericHealthValue).numericValue:0));
   return {'steps':steps,'distance_km':total(HealthDataType.DISTANCE_WALKING_RUNNING)/1000,'active_calories':total(HealthDataType.ACTIVE_ENERGY_BURNED),'exercise_minutes':total(HealthDataType.EXERCISE_TIME)};
  } catch (_) { return null; }
 }
}
