import 'package:flutter/material.dart';
import 'data/local/app_database.dart';
import 'app/theme/app_theme.dart';
import 'app/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  runApp(const FlexFusionApp());
}

class FlexFusionApp extends StatelessWidget {
  const FlexFusionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FlexFusion',
      theme: AppTheme.darkTheme,
      home: const AppShell(),
    );
  }
}