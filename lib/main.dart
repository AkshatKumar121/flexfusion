import 'package:flutter/material.dart';
import 'data/local/app_database.dart';
import 'app/theme/app_theme.dart';
import 'app/app_shell.dart';
import 'app/auto_refresh_on_return.dart';
import 'shared/widgets/keyboard_dismiss_on_tap.dart';

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
      navigatorObservers: [flexFusionRouteObserver],
      builder: (context, child) => KeyboardDismissOnTap(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppShell(),
    );
  }
}