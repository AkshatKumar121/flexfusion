import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import 'apple_health_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override State<ActivityScreen> createState() => _ActivityScreenState();
}
class _ActivityScreenState extends State<ActivityScreen> {
  final _health=AppleHealthService();
  static const _types=['Walking','Running','Cycling','Swimming','Hiking','Yoga & Mobility','Badminton','Football','Cricket','Basketball','Other'];
  DateTime _date=DateTime.now();
  List<Map<String,Object?>> _logs=[];
  Map<String,Object?>? _healthDay;
  bool _loading=true,_syncing=false;
  int _refreshGeneration=0;
  int _syncGeneration=0;
  String _key(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  @override void initState(){super.initState();_refresh();}
  Future<void> _refresh() async {
    final refreshGeneration = ++_refreshGeneration;
    final requestedDate = DateTime(_date.year, _date.month, _date.day);
    final requestedKey = _key(requestedDate);
    if (mounted) {
      setState(() => _loading = true);
    }
    final logs=await AppDatabase.instance.getActivityLogs(requestedKey);
    final saved=await AppDatabase.instance.getHealthActivitySummary(requestedKey);
    if(!mounted ||
        refreshGeneration != _refreshGeneration ||
        _key(_date) != requestedKey) return;
    setState((){_logs=logs;_healthDay=saved;_loading=false;});
    await _syncHealth(requestedDate);
  }
  Future<void> _syncHealth([DateTime? date]) async {
    final requestedDate = DateTime(
      (date ?? _date).year,
      (date ?? _date).month,
      (date ?? _date).day,
    );
    final requestedKey = _key(requestedDate);
    final syncGeneration = ++_syncGeneration;
    if (mounted) {
      setState(() => _syncing = true);
    }
    try {
      final data=await _health.readDailySummary(requestedDate);
      if (data != null) {
        await AppDatabase.instance.saveHealthActivitySummary(
          date: requestedKey,
          steps: data['steps'] as int?,
          distanceKm: (data['distance_km'] as num?)?.toDouble(),
          activeCalories: (data['active_calories'] as num?)?.toDouble(),
          exerciseMinutes: (data['exercise_minutes'] as num?)?.toDouble(),
        );
      }
      final saved=await AppDatabase.instance.getHealthActivitySummary(requestedKey);
      if(!mounted ||
          syncGeneration != _syncGeneration ||
          _key(_date) != requestedKey) return;
      setState(()=>_healthDay=saved);
    } finally {
      if(mounted && syncGeneration == _syncGeneration) {
        setState(()=>_syncing=false);
      }
    }
  }
  int get _steps=>_healthDay?['steps'] is num&&(_healthDay!['steps'] as num)>0?(_healthDay!['steps'] as num).round():_logs.fold<int>(0,(s,r)=>s+((r['steps'] as num?)?.toInt()??0));
  double get _km=>_healthDay?['distance_km'] is num&&(_healthDay!['distance_km'] as num)>0?(_healthDay!['distance_km'] as num).toDouble():_logs.fold<double>(0,(s,r)=>s+((r['distance_km'] as num?)?.toDouble()??0));
  double get _kcal=>_healthDay?['active_calories'] is num&&(_healthDay!['active_calories'] as num)>0?(_healthDay!['active_calories'] as num).toDouble():_logs.fold<double>(0,(s,r)=>s+((r['active_calories'] as num?)?.toDouble()??0));
  int get _minutes=>_healthDay?['exercise_minutes'] is num&&(_healthDay!['exercise_minutes'] as num)>0?(_healthDay!['exercise_minutes'] as num).round():_logs.fold<int>(0,(s,r)=>s+((r['duration_minutes'] as num?)?.toInt()??0));
  Future<void> _pickDate() async {
    final picked=await showDatePicker(context:context,initialDate:_date,firstDate:DateTime(2020),lastDate:DateTime.now());
    if(picked!=null){setState(()=>_date=picked);await _refresh();}
  }
  Future<void> _openForm({Map<String,Object?>? row}) async {
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,backgroundColor:AppColors.card,
      builder:(_)=>_ActivityForm(types:_types,date:_date,row:row,onSave:(v)async{
        await AppDatabase.instance.saveActivityLog(id:row?['id'] as int?,activityType:v['type'] as String,
          activityDate:_key(_date),startedAt:v['started'] as String,durationMinutes:v['duration'] as int,
          distanceKm:v['distance'] as double?,steps:v['steps'] as int?,activeCalories:v['calories'] as double?,notes:v['notes'] as String?);
        await _refresh();
      }));
  }
  Future<void> _delete(Map<String,Object?> row) async {
    final yes=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      backgroundColor:AppColors.card,title:const Text('Delete activity?',style:TextStyle(color:Colors.white)),
      content:const Text('This entry will be removed from this device.',style:TextStyle(color:AppColors.grey)),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('CANCEL')),
        TextButton(onPressed:()=>Navigator.pop(context,true),child:const Text('DELETE',style:TextStyle(color:AppColors.red)))]));
    if(yes==true){await AppDatabase.instance.deleteActivityLog(row['id'] as int);await _refresh();}
  }
  Widget _panel(Widget child)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppColors.card,borderRadius:BorderRadius.circular(12),border:Border.all(color:AppColors.border)),child:child);
  Widget _heading(String s)=>Text(s,style:GoogleFonts.inter(color:Colors.white,fontSize:12,fontWeight:FontWeight.w800,letterSpacing:1));
  Widget _metric(IconData i,String v,String l)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Icon(i,color:AppColors.green,size:15),const SizedBox(width:6),Text(l,style:const TextStyle(color:AppColors.grey,fontSize:9,fontWeight:FontWeight.w700))]),
    const SizedBox(height:5),Text(v,style:GoogleFonts.inter(color:Colors.white,fontSize:22,fontWeight:FontWeight.w800))]);
  @override Widget build(BuildContext context){
    final today=_key(_date)==_key(DateTime.now());
    return Scaffold(backgroundColor:AppColors.background,appBar:AppBar(backgroundColor:AppColors.background,title:_heading('ACTIVITY'),actions:[
      IconButton(onPressed:_pickDate,icon:const Icon(Icons.calendar_month,color:AppColors.green)),
      IconButton(onPressed:_syncing?null:_syncHealth,tooltip:'Sync Apple Health',icon:_syncing?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.sync,color:AppColors.green))]),
      body:_loading?const Center(child:CircularProgressIndicator(color:AppColors.green)):RefreshIndicator(onRefresh:_refresh,color:AppColors.green,child:ListView(padding:const EdgeInsets.fromLTRB(18,8,18,28),children:[
        _panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[_heading('DAILY MOVEMENT'),Text(today?'TODAY':_key(_date),style:const TextStyle(color:AppColors.green,fontSize:10,fontWeight:FontWeight.w700))]),
          const SizedBox(height:18),Row(children:[Expanded(child:_metric(Icons.directions_walk,'$_steps','STEPS')),Expanded(child:_metric(Icons.timer_outlined,'$_minutes','ACTIVE MIN'))]),
          const SizedBox(height:18),Row(children:[Expanded(child:_metric(Icons.route,_km.toStringAsFixed(2),'KM')),Expanded(child:_metric(Icons.local_fire_department,_kcal.round().toString(),'ACTIVE KCAL'))]),
          const SizedBox(height:12),Text(_healthDay!=null?'Apple Health · read-only sync':'Manual tracking · Apple Health unavailable or not authorised',style:const TextStyle(color:AppColors.grey,fontSize:10))])),
        const SizedBox(height:14),SizedBox(height:48,child:ElevatedButton.icon(onPressed:()=>_openForm(),icon:const Icon(Icons.add),label:const Text('LOG AN ACTIVITY',style:TextStyle(fontWeight:FontWeight.w800,letterSpacing:1)),style:ElevatedButton.styleFrom(backgroundColor:AppColors.green,foregroundColor:Colors.black))),
        const SizedBox(height:22),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[_heading('ACTIVITY ENTRIES'),Text('${_logs.length} LOGGED',style:const TextStyle(color:AppColors.grey,fontSize:10,fontWeight:FontWeight.w700))]),const SizedBox(height:10),
        if(_logs.isEmpty)_panel(const Padding(padding:EdgeInsets.symmetric(vertical:18),child:Center(child:Text('No manual activities logged for this day.',style:TextStyle(color:AppColors.grey,fontSize:12)))))
        else ..._logs.map((row){
          final mins=(row['duration_minutes'] as num?)?.toInt()??0;final km=(row['distance_km'] as num?)?.toDouble();final steps=(row['steps'] as num?)?.toInt();
          final detail=[if(mins>0)'$mins min',if(km!=null)'${km.toStringAsFixed(2)} km',if(steps!=null)'$steps steps'].join(' · ');
          return Padding(padding:const EdgeInsets.only(bottom:8),child:_panel(Row(children:[
            const Icon(Icons.directions_run,color:AppColors.green,size:22),const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(row['activity_type'] as String,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:13)),
              Text(detail.isEmpty?'Activity logged':detail,style:const TextStyle(color:AppColors.grey,fontSize:10)),
              if((row['notes'] as String?)?.isNotEmpty==true)Text(row['notes'] as String,style:const TextStyle(color:AppColors.grey,fontSize:10))])),
            IconButton(onPressed:()=>_openForm(row:row),icon:const Icon(Icons.edit_outlined,color:AppColors.grey,size:19)),
            IconButton(onPressed:()=>_delete(row),icon:const Icon(Icons.delete_outline,color:AppColors.red,size:19))])));
        }),
        const SizedBox(height:22),_heading('LAST 7 DAYS'),const SizedBox(height:10),
        FutureBuilder<List<Map<String,Object?>>>(future:AppDatabase.instance.getActivityHistory(days:7),builder:(context,snapshot){
          final rows=snapshot.data??[];final mins=rows.fold<int>(0,(s,r)=>s+((r['duration_minutes'] as num?)?.toInt()??0));
          return _panel(Row(children:[Expanded(child:_metric(Icons.event_note,'${rows.length}','ENTRIES')),Expanded(child:_metric(Icons.schedule,'$mins','MANUAL MINUTES'))]));}),
      ])));
  }
}

class _ActivityForm extends StatefulWidget {
  final List<String> types;final DateTime date;final Map<String,Object?>? row;final Future<void> Function(Map<String,Object?>) onSave;
  const _ActivityForm({required this.types,required this.date,required this.row,required this.onSave});
  @override State<_ActivityForm> createState()=>_ActivityFormState();
}
class _ActivityFormState extends State<_ActivityForm>{
  late String _type;late final TextEditingController _duration,_distance,_steps,_calories,_notes;TimeOfDay _time=TimeOfDay.now();bool _saving=false;
  @override void initState(){super.initState();final r=widget.row;_type=r?['activity_type'] as String? ?? widget.types.first;
    _duration=TextEditingController(text:r?['duration_minutes']?.toString()??'');_distance=TextEditingController(text:r?['distance_km']?.toString()??'');
    _steps=TextEditingController(text:r?['steps']?.toString()??'');_calories=TextEditingController(text:r?['active_calories']?.toString()??'');
    _notes=TextEditingController(text:r?['notes'] as String? ?? '');final dt=DateTime.tryParse(r?['started_at'] as String? ?? '');if(dt!=null)_time=TimeOfDay.fromDateTime(dt);}
  @override void dispose(){_duration.dispose();_distance.dispose();_steps.dispose();_calories.dispose();_notes.dispose();super.dispose();}
  InputDecoration _dec(String s)=>InputDecoration(labelText:s,labelStyle:const TextStyle(color:AppColors.grey),filled:true,fillColor:AppColors.background,border:OutlineInputBorder(borderRadius:BorderRadius.circular(9)));
  Widget _field(TextEditingController c,String label,{bool numeric=false,int lines=1})=>TextField(controller:c,maxLines:lines,keyboardType:numeric?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,style:const TextStyle(color:Colors.white),decoration:_dec(label));
  Future<void> _save()async{
    final duration=int.tryParse(_duration.text.trim())??0;final distance=double.tryParse(_distance.text.trim());final steps=int.tryParse(_steps.text.trim());final calories=double.tryParse(_calories.text.trim());
    if(duration<0||(distance!=null&&distance<0)||(steps!=null&&steps<0)||(calories!=null&&calories<0)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Values cannot be negative.')));return;}
    if(duration==0&&(distance??0)==0&&(steps??0)==0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter duration, distance, or steps.')));return;}
    setState(()=>_saving=true);final started=DateTime(widget.date.year,widget.date.month,widget.date.day,_time.hour,_time.minute).toIso8601String();
    await widget.onSave({'type':_type,'started':started,'duration':duration,'distance':distance,'steps':steps,'calories':calories,'notes':_notes.text.trim()});
    if(mounted)Navigator.pop(context);
  }
  @override Widget build(BuildContext context)=>SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(18,18,18,MediaQuery.of(context).viewInsets.bottom+18),child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(widget.row==null?'LOG ACTIVITY':'EDIT ACTIVITY',style:GoogleFonts.inter(color:Colors.white,fontSize:15,fontWeight:FontWeight.w800,letterSpacing:1)),const SizedBox(height:16),
    DropdownButtonFormField<String>(initialValue:_type,dropdownColor:AppColors.card,decoration:_dec('Activity type'),items:widget.types.map((t)=>DropdownMenuItem(value:t,child:Text(t,style:const TextStyle(color:Colors.white)))).toList(),onChanged:(v)=>setState(()=>_type=v??_type)),
    const SizedBox(height:12),Row(children:[Expanded(child:_field(_duration,'Duration (minutes)',numeric:true)),const SizedBox(width:10),Expanded(child:OutlinedButton.icon(onPressed:()async{final t=await showTimePicker(context:context,initialTime:_time);if(t!=null)setState(()=>_time=t);},icon:const Icon(Icons.access_time),label:Text(_time.format(context)),style:OutlinedButton.styleFrom(foregroundColor:AppColors.green)))]),
    const SizedBox(height:12),Row(children:[Expanded(child:_field(_distance,'Distance (km)',numeric:true)),const SizedBox(width:10),Expanded(child:_field(_steps,'Steps (optional)',numeric:true))]),
    const SizedBox(height:12),_field(_calories,'Active calories (optional)',numeric:true),const SizedBox(height:12),_field(_notes,'Notes (optional)',lines:2),
    const SizedBox(height:18),SizedBox(width:double.infinity,height:46,child:ElevatedButton(onPressed:_saving?null:_save,style:ElevatedButton.styleFrom(backgroundColor:AppColors.green,foregroundColor:Colors.black),child:Text(_saving?'SAVING...':'SAVE ACTIVITY',style:const TextStyle(fontWeight:FontWeight.w800)))),
  ]))));
}
