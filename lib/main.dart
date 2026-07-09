import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'screens/app_startup_screen.dart';
import 'theme.dart';

void main() {
  runApp(const PtolemyApp());
}

/// Flutter's default scroll behavior only recognizes touch/stylus as drag
/// devices, so on web a desktop mouse can't click-and-drag to page through a
/// PageView or TabBarView (e.g. the onboarding swiper) -- it would otherwise
/// require a scrollbar or keyboard to move at all. Adding mouse + trackpad
/// here makes swipe gestures work with a mouse too, across the whole app.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

class PtolemyApp extends StatelessWidget {
  const PtolemyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ptolemy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      scrollBehavior: AppScrollBehavior(),
      home: const AppStartupScreen(),
    );
  }
}
