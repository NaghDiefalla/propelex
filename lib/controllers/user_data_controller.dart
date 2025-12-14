// lib/controllers/user_data_controller.dart

import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async'; 
// Note: We assume 'home.dart' is local, as per your previous files.
// It contains Quote and QuoteImageTheme.
import '../views/home.dart'; 

// FIX: To resolve the 'Undefined class' and 'uri_does_not_exist' errors,
// you need to ensure these three Firebase packages are imported from 
// pubspec.yaml and pub get is run.

class UserDataController extends GetxController {
  // --- Reactive State Variables ---
  
  // Quote Data
  final RxList<Quote> quoteHistory = <Quote>[].obs;
  final RxList<Quote> favorites = <Quote>[].obs;
  final RxMap<String, int> quoteRatings = <String, int>{}.obs; // {quoteId: rating}

  // Settings
  final RxBool enableNotifications = true.obs;
  final RxString notificationTime = '08:00'.obs;
  final RxString apiSource = 'zenquotes'.obs; 
  final Rx<QuoteImageTheme> quoteImageTheme = QuoteImageTheme.modern.obs;
  
  // Metrics
  final RxInt streakCount = 0.obs;

  // --- Dependencies (Resolved by Imports) ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Stream subscription to manage auth state (for clean disposal)
  late StreamSubscription<User?> _authStateSubscription;

  // Computed property to get the current user's UID safely
  String? get _uid => _auth.currentUser?.uid;

  // Collection reference for the current user's data
  CollectionReference get _userCollection => _firestore.collection('users');

  // ----------------------------------------------------
  // --- Initialization and Authentication Handling ---
  // ----------------------------------------------------

  @override
  void onInit() {
    super.onInit();
    // FIX: Use listen() for Streams from Firebase, manage subscription
    _authStateSubscription = _auth.authStateChanges().listen(_handleAuthChanges);
  }

  @override
  void onClose() {
    _authStateSubscription.cancel(); // Dispose of the subscription
    super.onClose();
  }

  void _handleAuthChanges(User? user) {
    if (user != null) {
      _loadUserData();
    } else {
      _clearState();
    }
  }
  
  void _clearState() {
    quoteHistory.clear();
    favorites.clear();
    quoteRatings.clear();
    streakCount.value = 0;
    enableNotifications.value = true;
    notificationTime.value = '08:00';
    apiSource.value = 'zenquotes';
    quoteImageTheme.value = QuoteImageTheme.modern;
  }

  // ----------------------------------------------------
  // --- Loading/Saving Core Data ---
  // ----------------------------------------------------

  /// Fetches all user data from Firestore and initializes reactive variables.
  Future<void> _loadUserData() async {
    if (_uid == null) return;
    
    try {
      final doc = await _userCollection.doc(_uid).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        // 1. Quote Data (History, Favorites, Ratings)
        _loadQuoteData(data);

        // 2. Settings
        _loadSettings(data['settings'] as Map<String, dynamic>?);
        
        // 3. Metrics
        _calculateStreak();
        
      } else {
        // First time user, ensure initial data structure is created
        await saveAllData(); 
        _calculateStreak();
      }
    } catch (e) {
      if (kDebugMode) print('Error loading user data: $e');
      Get.snackbar('Data Load Error', 'Failed to load your personal data. Please restart the app.', snackPosition: SnackPosition.BOTTOM);
    }
  }
  
  void _loadQuoteData(Map<String, dynamic> data) {
    // History
    final List<dynamic> historyList = data['history'] ?? [];
    quoteHistory.value = historyList
        .map((e) => Quote.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    // Favorites
    final List<dynamic> favoritesList = data['favorites'] ?? [];
    favorites.value = favoritesList
        .map((e) => Quote.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    // Ratings
    final Map<String, dynamic> ratingsMap = data['ratings'] ?? {};
    quoteRatings.value = ratingsMap.map((k, v) => MapEntry(k, v as int));
  }
  
  void _loadSettings(Map<String, dynamic>? settings) {
    if (settings != null) {
      enableNotifications.value = settings['enableNotifications'] ?? true;
      notificationTime.value = settings['notificationTime'] ?? '08:00';
      apiSource.value = settings['apiSource'] ?? 'zenquotes';
      
      final themeString = settings['imageTheme'] as String? ?? QuoteImageTheme.modern.toString().split('.').last;
      try {
        quoteImageTheme.value = QuoteImageTheme.values.firstWhere(
          (e) => e.toString().split('.').last == themeString,
          orElse: () => QuoteImageTheme.modern,
        );
      } catch (_) {
        quoteImageTheme.value = QuoteImageTheme.modern;
      }
    }
  }

  /// Saves all current reactive state to Firestore.
  Future<void> saveAllData() async {
    if (_uid == null) return;
    
    final userData = {
      'history': quoteHistory.map((q) => q.toJson()).toList(),
      'favorites': favorites.map((q) => q.toJson()).toList(),
      // Use .value for RxMap access outside of subclasses (safe access)
      'ratings': quoteRatings.value,
      'settings': {
        'enableNotifications': enableNotifications.value,
        'notificationTime': notificationTime.value,
        'apiSource': apiSource.value,
        'imageTheme': quoteImageTheme.value.toString().split('.').last,
      },
      // Correctly use Timestamp from Firestore
      'lastQuoteDate': quoteHistory.isNotEmpty 
          ? Timestamp.fromDate(DateTime.now()) 
          : null,
      'streakCount': streakCount.value,
    };

    try {
      await _userCollection.doc(_uid).set(
        userData, 
        // Correctly use SetOptions from Firestore
        SetOptions(merge: true)
      );
    } catch (e) {
      if (kDebugMode) print('Error saving all user data: $e');
    }
  }

  // ----------------------------------------------------
  // --- History & Streak Logic ---
  // ----------------------------------------------------

  /// Adds a quote to history and updates the streak.
  void addQuoteToHistory(Quote newQuote) async {
    quoteHistory.removeWhere((q) => q.id == newQuote.id);
    quoteHistory.insert(0, newQuote);
    
    if (quoteHistory.length > 200) {
      quoteHistory.removeRange(200, quoteHistory.length);
    }
    
    _calculateStreak(wasNewQuoteFetched: true);
    await saveAllData();
  }

  /// Removes a quote from history and removes its rating.
  void removeHistoryItem(String quoteId) async {
    quoteHistory.removeWhere((q) => q.id == quoteId);
    
    if (quoteRatings.containsKey(quoteId)) {
      quoteRatings.remove(quoteId);
    }
    
    favorites.removeWhere((q) => q.id == quoteId);
    
    _calculateStreak(wasNewQuoteFetched: false); 

    await saveAllData();
  }
  
  /// Recalculates the daily streak based on the history.
  void _calculateStreak({bool wasNewQuoteFetched = false}) {
    if (quoteHistory.isEmpty) {
      streakCount.value = 0;
      return;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    // NOTE: For a robust streak, history items should contain their addition date. 
    // This logic relies on a proxy (`lastQuoteTime`) and the `wasNewQuoteFetched` flag.
    
    int currentStreak = 0; 

    final lastQuoteTime = quoteHistory.isNotEmpty ? DateTime.now() : null; 
    
    if (lastQuoteTime != null) {
      final daysSinceLastQuote = todayStart.difference(DateTime(lastQuoteTime.year, lastQuoteTime.month, lastQuoteTime.day)).inDays;
      
      final previousStreak = streakCount.value;

      if (daysSinceLastQuote == 0) {
        // Quote fetched today, streak continues
        currentStreak = previousStreak == 0 ? 1 : previousStreak;
      } else if (daysSinceLastQuote == 1) {
        // Quote fetched yesterday, streak continues if a new one was fetched today
        currentStreak = previousStreak + (wasNewQuoteFetched ? 1 : 0); 
      } else {
        // Gap in days, streak broken (reset to 1 if new one was fetched today, else 0)
        currentStreak = wasNewQuoteFetched ? 1 : 0;
      }
    } else {
       currentStreak = 0;
    }
    
    if (quoteHistory.isNotEmpty && currentStreak == 0 && wasNewQuoteFetched) {
      currentStreak = 1;
    }

    streakCount.value = currentStreak;
  }


  // ----------------------------------------------------
  // --- Favorites Logic ---
  // ----------------------------------------------------

  void addFavorite(Quote quote) async {
    if (!favorites.any((q) => q.id == quote.id)) {
      favorites.add(quote);
    }
    await saveAllData();
  }

  void removeFavorite(String quoteId) async {
    favorites.removeWhere((q) => q.id == quoteId);
    await saveAllData();
  }

  // ----------------------------------------------------
  // --- Ratings Logic ---
  // ----------------------------------------------------

  void rateQuote(String id, int rating) async {
    if (rating > 0) {
      quoteRatings[id] = rating;
    } else {
      if (quoteRatings.containsKey(id)) {
        quoteRatings.remove(id);
      }
    }
    quoteRatings.refresh(); 
    await saveAllData();
  }
  
  // ----------------------------------------------------
  // --- Settings Logic ---
  // ----------------------------------------------------

  void updateNotificationSettings(bool enable, String time) async {
    enableNotifications.value = enable;
    notificationTime.value = time;
    await saveAllData();
  }

  void updateApiSource(String sourceName) async {
    apiSource.value = sourceName;
    await saveAllData();
  }

  void updateImageTheme(QuoteImageTheme theme) async {
    quoteImageTheme.value = theme;
    await saveAllData();
  }
}