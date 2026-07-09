import 'package:flutter/material.dart';

import 'screens/app_startup_screen.dart';
import 'theme.dart';

void main() {
  runApp(const PtolemyApp());
}

class PtolemyApp extends StatelessWidget {
  const PtolemyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ptolemy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const AppStartupScreen(),
    );
  }
}
