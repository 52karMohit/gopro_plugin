import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/gopro_controller.dart';
import 'ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF12141A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const GoProApp());
}

class GoProApp extends StatefulWidget {
  const GoProApp({super.key});

  @override
  State<GoProApp> createState() => _GoProAppState();
}

class _GoProAppState extends State<GoProApp> {
  late final GoProController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GoProController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoPro Open API Controller',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0F12),
        primaryColor: const Color(0xFF00A3E0),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00A3E0),
          secondary: Color(0xFFFF3B30),
          surface: Color(0xFF14171E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF12141A),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: HomePage(controller: _controller),
    );
  }
}
