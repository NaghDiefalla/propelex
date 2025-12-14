// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
// 🎯 ADD FIREBASE IMPORTS
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/auth_controller.dart'; // 🎯 Import the new controller

import 'themes/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  Get.put(AuthController(), permanent: true);

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.red.shade50,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Something went wrong. Please restart the app.\n\n${details.exceptionAsString()}',
            style: const TextStyle(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };

  final prefs = await SharedPreferences.getInstance();
  final themeModeString = prefs.getString('theme_mode') ?? 'system';

  ThemeMode initialThemeMode;
  switch (themeModeString) {
    case 'light':
      initialThemeMode = ThemeMode.light;
      break;
    case 'dark':
      initialThemeMode = ThemeMode.dark;
      break;
    default:
      initialThemeMode = ThemeMode.system;
  }

  runZonedGuarded(() {
    runApp(GetMaterialApp(
      home: const Scaffold(body: Center(child: CircularProgressIndicator())), 
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: initialThemeMode,
    ));
  }, (error, stack) {
    // FIX: Use debugPrint instead of print to avoid dart:avoid_print warning
    // debugPrint is typically disabled in release builds.
    debugPrint('Uncaught error: $error\nStack trace: $stack');
  });
}