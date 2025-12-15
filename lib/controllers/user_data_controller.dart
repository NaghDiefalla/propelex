import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async'; 
import '../views/home.dart'; 

class UserDataController extends GetxController {

  final RxList<Quote> quoteHistory = <Quote>[].obs;
  final RxList<Quote> favorites = <Quote>[].obs;
  final RxMap<String, int> quoteRatings = <String, int>{}.obs; // {quoteId: rating}

  final RxBool enableNotifications = true.obs;
  final RxString notificationTime = '08:00'.obs;
  final RxString apiSource = 'zenquotes'.obs; 
  final Rx<QuoteImageTheme> quoteImageTheme = QuoteImageTheme.modern.obs;
  
  final RxInt streakCount = 0.obs;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late StreamSubscription<User?> _authStateSubscription;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference get _userCollection => _firestore.collection('users');

  @override
  void onInit() {
    super.onInit();
    _authStateSubscription = _auth.authStateChanges().listen(_handleAuthChanges);
  }

  @override
  void onClose() {
    _authStateSubscription.cancel();
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

  Future<void> _loadUserData() async {
    if (_uid == null) return;
    
    try {
      final doc = await _userCollection.doc(_uid).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        _loadQuoteData(data);

        _loadSettings(data['settings'] as Map<String, dynamic>?);
        
        _calculateStreak();
        
      } else {
        await saveAllData(); 
        _calculateStreak();
      }
    } catch (e) {
      if (kDebugMode) print('Error loading user data: $e');
      Get.snackbar('Data Load Error', 'Failed to load your personal data. Please restart the app.', snackPosition: SnackPosition.BOTTOM);
    }
  }
  
  void _loadQuoteData(Map<String, dynamic> data) {
    final List<dynamic> historyList = data['history'] ?? [];
    quoteHistory.value = historyList
        .map((e) => Quote.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final List<dynamic> favoritesList = data['favorites'] ?? [];
    favorites.value = favoritesList
        .map((e) => Quote.fromJson(Map<String, dynamic>.from(e)))
        .toList();

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

  Future<void> saveAllData() async {
    if (_uid == null) return;
    
    final userData = {
      'history': quoteHistory.map((q) => q.toJson()).toList(),
      'favorites': favorites.map((q) => q.toJson()).toList(),
      'ratings': quoteRatings.value,
      'settings': {
        'enableNotifications': enableNotifications.value,
        'notificationTime': notificationTime.value,
        'apiSource': apiSource.value,
        'imageTheme': quoteImageTheme.value.toString().split('.').last,
      },
      'lastQuoteDate': quoteHistory.isNotEmpty 
          ? Timestamp.fromDate(DateTime.now()) 
          : null,
      'streakCount': streakCount.value,
    };

    try {
      await _userCollection.doc(_uid).set(
        userData, 
        SetOptions(merge: true)
      );
    } catch (e) {
      if (kDebugMode) print('Error saving all user data: $e');
    }
  }

  void addQuoteToHistory(Quote newQuote) async {
    quoteHistory.removeWhere((q) => q.id == newQuote.id);
    quoteHistory.insert(0, newQuote);
    
    if (quoteHistory.length > 200) {
      quoteHistory.removeRange(200, quoteHistory.length);
    }
    
    _calculateStreak(wasNewQuoteFetched: true);
    await saveAllData();
  }

  void removeHistoryItem(String quoteId) async {
    quoteHistory.removeWhere((q) => q.id == quoteId);
    
    if (quoteRatings.containsKey(quoteId)) {
      quoteRatings.remove(quoteId);
    }
    
    favorites.removeWhere((q) => q.id == quoteId);
    
    _calculateStreak(wasNewQuoteFetched: false); 

    await saveAllData();
  }
  
  void _calculateStreak({bool wasNewQuoteFetched = false}) {
    if (quoteHistory.isEmpty) {
      streakCount.value = 0;
      return;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    int currentStreak = 0; 

    final lastQuoteTime = quoteHistory.isNotEmpty ? DateTime.now() : null; 
    
    if (lastQuoteTime != null) {
      final daysSinceLastQuote = todayStart.difference(DateTime(lastQuoteTime.year, lastQuoteTime.month, lastQuoteTime.day)).inDays;
      
      final previousStreak = streakCount.value;

      if (daysSinceLastQuote == 0) {
        currentStreak = previousStreak == 0 ? 1 : previousStreak;
      } else if (daysSinceLastQuote == 1) {
        currentStreak = previousStreak + (wasNewQuoteFetched ? 1 : 0); 
      } else {
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