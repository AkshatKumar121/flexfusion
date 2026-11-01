import 'package:flutter/material.dart';
import 'app/theme/app_theme.dart';
import 'app/app_shell.dart';

void main() {
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