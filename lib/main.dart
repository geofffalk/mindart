import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MindArtApp());
}

class MindArtApp extends StatelessWidget {
  const MindArtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindArt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
