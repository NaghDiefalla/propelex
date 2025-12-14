import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../views/home.dart';
import '../views/login.dart';

class AuthController extends GetxController {
  // Use Rx<User?> to observe the current Firebase user state
  final Rx<User?> _user = FirebaseAuth.instance.currentUser.obs;

  // RxBool for loading state during network calls
  final RxBool isLoading = false.obs;

  // Getter to access the stream of user changes
  User? get user => _user.value;

  @override
  void onReady() {
    super.onReady();
    // Binds the Firebase Auth state change stream to the _user variable.
    // This allows GetX to automatically route the user when they log in/out.
    _user.bindStream(FirebaseAuth.instance.authStateChanges());

    // Listener to handle navigation when the user state changes
    ever(_user, _initialScreen);
  }

  // Handle navigation based on user state
  void _initialScreen(User? user) {
    if (user == null) {
      // User is NOT logged in
      Get.offAll(() => const LoginPage());
    } else {
      // User IS logged in
      Get.offAll(() => const HomePage());
    }
  }

  // --- Login Method ---
  Future<void> login(String email, String password) async {
    isLoading.value = true;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Success is handled by the `authStateChanges` listener
    } on FirebaseAuthException catch (e) {
      String message = 'An unknown error occurred.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = 'Invalid email or password.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      }
      Get.snackbar(
        'Login Failed',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // --- Register Method ---
  Future<void> register(String email, String password) async {
    isLoading.value = true;
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Success is handled by the `authStateChanges` listener
      Get.snackbar(
        'Success',
        'Account created successfully! You are now logged in.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'An unknown error occurred.';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      }
      Get.snackbar(
        'Registration Failed',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // --- Logout Method ---
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
}