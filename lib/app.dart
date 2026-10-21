import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/projects/presentation/screens/projects_screen.dart';

class IDCardStudioApp extends StatelessWidget {
  const IDCardStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ID Card Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: ProjectsScreen(),
    );
  }
}
