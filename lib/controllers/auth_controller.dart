import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../views/home.dart';
import '../views/login.dart';

class AuthController extends GetxController {
  static AuthController get instance => Get.find();
  
  // NOTE: Your original file had both firebaseUser and _user, simplifying to just 'user'
  // for consistency with the last provided code structure.
  final Rx<User?> user = FirebaseAuth.instance.currentUser.obs; 
  final RxBool isLoading = false.obs;

  // The simplified getter for consistent access
  // User? get user => _user.value; 

  @override
  void onReady() {
    super.onReady();
    // Replaced the original firebaseUser variable with the simplified 'user'
    user.bindStream(FirebaseAuth.instance.userChanges());
    ever(user, _initialScreen);
  }

  // Handle navigation based on user state
  void _initialScreen(User? firebaseUser) { // Renamed parameter for clarity
    if (firebaseUser == null) {
      // User is NOT logged in
      Get.offAll(() => const LoginPage());
    } else {
      // User IS logged in
      Get.offAll(() => const HomePage());
    }
  }

  // --- Login Method --- (Retained from your previous code)
  Future<void> login(String email, String password) async {
    isLoading.value = true;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
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

  // --- Register Method --- (Retained from your previous code)
  Future<void> register(String email, String password) async {
    isLoading.value = true;
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
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

  // --- 🎯 NEW: Forget Password Method ---
  Future<void> resetPassword(String email) async {
    isLoading.value = true;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      Get.snackbar(
        'Success',
        'Password reset link sent to $email. Check your inbox.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      // Navigate the user back to the login page after success
      Get.off(() => const LoginPage()); 

    } on FirebaseAuthException catch (e) {
      String message = 'An unknown error occurred.';
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        message = 'No user found for that email or the email is invalid.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many requests. Try again later.';
      }
      Get.snackbar(
        'Error',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
  // --- Logout Method --- (Retained from your previous code)
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
}