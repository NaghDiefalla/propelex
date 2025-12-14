import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../views/home.dart';

class HomeController extends GetxController {
  Rx<Quote> currentQuote = Quote(id: '0', content: 'Tap to fetch', author: 'Propelex').obs;
  RxBool isFetching = false.obs;
  RxList<Quote> quoteHistory = <Quote>[].obs;
  RxMap<String, int> quoteRatings = <String, int>{}.obs;

  RxBool notificationsEnabled = false.obs;
  RxInt notificationInterval = 360.obs;
  Rx<QuoteApiSource> apiSource = QuoteApiSource.zenquotes.obs;
  Rx<QuoteImageTheme> imageTheme = QuoteImageTheme.modern.obs;

  @override
  void onInit() {
    loadSettings();
    _getSavedData();
    super.onInit();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    notificationsEnabled.value = prefs.getBool('notifications_enabled') ?? false;
    notificationInterval.value = prefs.getInt('notification_interval') ?? 360;
    
    final sourceString = prefs.getString('api_source') ?? QuoteApiSource.zenquotes.name;
    try {
      apiSource.value = QuoteApiSource.values.firstWhere((e) => e.name == sourceString);
    } catch (_) {
      apiSource.value = QuoteApiSource.zenquotes;
    }
    
    final themeString = prefs.getString('image_theme') ?? QuoteImageTheme.modern.name;
    try {
      imageTheme.value = QuoteImageTheme.values.firstWhere((e) => e.name == themeString);
    } catch (_) {
      imageTheme.value = QuoteImageTheme.modern;
    }
  }

  Future<void> setImageTheme(QuoteImageTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('image_theme', theme.name);
    imageTheme.value = theme;
  }

  Future<void> _getSavedData() async {
    await _loadHistory();
    await _loadRatings();
    if (quoteHistory.isNotEmpty) {
      currentQuote.value = quoteHistory.first;
    }
  }

  Future<void> _loadHistory() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _loadRatings() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> cancelAllNotifications() async {}

  Future<void> scheduleNotifications(int intervalMinutes) async {}

  Future<void> reloadUserData() async {
    await _getSavedData();
  }
}