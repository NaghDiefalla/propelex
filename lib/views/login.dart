// lib/views/login.dart

import 'package:get/get.dart';
import 'package:flutter/material.dart';
// 🎯 Import the Auth Controller
import '../controllers/auth_controller.dart'; 
import 'register.dart'; // Assuming you will create this file for the 'Create account' button
// import 'home.dart'; // No longer needed, navigation is handled by AuthController

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  // 🎯 Renamed to emailController for Firebase standards
  final TextEditingController emailController = TextEditingController(); 
  final TextEditingController passwordController = TextEditingController();
  final _formkey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  // 1. Get the AuthController instance
  // The AuthController must be injected in main.dart first: Get.put(AuthController())
  final AuthController authController = AuthController.instance;

  // 🎯 Removed SharedPreferences logic (_prefs, _isLightTheme, _getThemeStatus)
  // Theme logic should be managed globally in main.dart.

  Future<void> _attemptLogin() async {
    if (!_formkey.currentState!.validate()) return;

    final email = emailController.text.trim();
    final password = passwordController.text;

    // 2. Call the Firebase login method via the controller
    await authController.login(email, password);
    // Navigation is handled automatically by AuthController on success
  }

  @override
  void initState() {
    super.initState();
    // 🎯 Removed _getThemeStatus() from initState.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle background gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                      Theme.of(context).colorScheme.secondary.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Form(
                    key: _formkey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'Quote App',
                          style: Theme.of(context).textTheme.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          // 🎯 Updated text for email login
                          'Daily inspiration — sign in with your email',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        // 🎯 Email Field
                        TextFormField(
                            controller: emailController,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email.';
                              }
                              if (!GetUtils.isEmail(value)) {
                                return 'Please enter a valid email address.';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Email', // 🎯 Changed label
                              hintText: 'e.g., user@example.com',
                              prefixIcon: Icon(Icons.email_outlined), // 🎯 Changed icon
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Password Field
                          TextFormField(
                            controller: passwordController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password.';
                              }
                              return null;
                            },
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        // 🎯 Removed demo login hint
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: () {}, child: const Text('Forgot Password?')),
                        ),
                        const SizedBox(height: 8),
                        // 🎯 Use Obx to show loading state and disable button
                        Obx(
                          () => SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              // Disable button and show spinner while loading
                              onPressed: authController.isLoading.value ? null : _attemptLogin,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: authController.isLoading.value
                                  ? const SizedBox(
                                      height: 20, 
                                      width: 20, 
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                    )
                                  : const Text('Login', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 🎯 Navigate to the registration page
                        TextButton(
                          onPressed: () {
                            // Assuming RegistrationPage exists in views/register.dart
                            Get.to(() => const RegistrationPage()); 
                          }, 
                          child: const Text('Create account')
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}