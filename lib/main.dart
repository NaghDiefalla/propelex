import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'controllers/auth_controller.dart'; 
import 'controllers/home_controller.dart'; 
import 'views/home.dart';
import 'views/login.dart';
import 'themes/app_theme.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    // We can safely find the controller here because it was put() in main()
    final authController = Get.find<AuthController>();

    // Obx reacts to changes in authController.user
    return Obx(() {
      // NOTE: AuthController.onReady() handles navigation, but AppRoot ensures 
      // the correct screen is shown immediately upon app launch before 
      // the initial stream event fires Get.offAll().
      if (authController.user.value != null) {
        return const HomePage();
      } else {
        return const LoginPage();
      }
    });
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 1. Inject AuthController (Required for Firebase login/state)
  Get.put(AuthController(), permanent: true);
  // 2. 🎯 NEW: Inject HomeController (Required for quote logic/settings)
  Get.put(HomeController(), permanent: true);

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
      // 3. 🎯 NEW: Set the home to the AppRoot to handle initial routing
      home: const AppRoot(), 
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: initialThemeMode,
    ));
  }, (error, stack) {
    // Used debugPrint for better practice in production/release builds
    debugPrint('Uncaught error: $error\nStack trace: $stack');
  });
}