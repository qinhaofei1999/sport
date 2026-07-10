import 'package:flutter/material.dart';
import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SportPoseApp());
}

class SportPoseApp extends StatelessWidget {
  const SportPoseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SportPose',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF00BCD4),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
