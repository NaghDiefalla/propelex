import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:gal/gal.dart';

import 'login.dart';
import 'search.dart';
import 'settings.dart';
import 'favorites.dart';
import 'history.dart';
import 'rated_quotes.dart';
import 'add_quote.dart';

enum QuoteImageTheme {
  modern,
  elegant,
  bold,
  cinematic, 
}

extension QuoteImageThemeExtension on QuoteImageTheme {
  String get name {
    switch (this) {
      case QuoteImageTheme.modern:
        return 'Modern';
      case QuoteImageTheme.elegant:
        return 'Elegant';
      case QuoteImageTheme.bold:
        return 'Bold & Clean';
      case QuoteImageTheme.cinematic:
        return 'Cinematic';
    }
  }
}

class Quote {
  final String id;
  final String content;
  final String author;

  Quote({required this.id, required this.content, required this.author});

  factory Quote.fromJson(Map<String, dynamic> json, {String source = 'zenquotes'}) {
    String? content;
    String? author;

    if (source == QuoteApiSource.zenquotes.name) {
      // ZenQuotes format: [{"q": "content", "a": "author"}]
      content = json['q'] as String?;
      author = json['a'] as String?;
    } else if (source == QuoteApiSource.quotegarden.name) {
      // QuoteGarden format (inner object of the data array): {"quoteText": "content", "quoteAuthor": "author"}
      content = json['quoteText'] as String?;
      author = json['quoteAuthor'] as String?;
    } else if (source == QuoteApiSource.typefitLocal.name) {
      // Type.fit format: {"text": "content", "author": "author"}
      content = json['text'] as String?;
      author = json['author'] as String?;
    }

    content ??= 'No quote available';
    author ??= 'Unknown';

    final idValue = json['_id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString();

    return Quote(
      id: idValue,
      content: content.trim(),
      author: author.replaceAll(', type.fit', '').trim().replaceAll(RegExp(r'\s+'), ' '), // Clean up Type.fit author
    );
  }

  Map<String, dynamic> toJson() => {'_id': id, 'q': content, 'a': author};
}

enum QuoteApiSource { zenquotes, quotegarden, typefitLocal } 

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  static const _defaultApiSource = QuoteApiSource.zenquotes;
  static const _zenQuotesUrl = 'https://zenquotes.io/api/random';
  static const List<Map<String, String>> _fallbackQuotes = [
    // ... (Your fallback quotes remain here)
    {'q': 'The only limit to our realization of tomorrow is our doubts of today.', 'a': 'Franklin D. Roosevelt'},
    {'q': 'In the middle of difficulty lies opportunity.', 'a': 'Albert Einstein'},
    {'q': 'What you get by achieving your goals is not as important as what you become by achieving your goals.', 'a': 'Zig Ziglar'},
    {'q': 'The best way to predict the future is to invent it.', 'a': 'Alan Kay'},
    {'q': 'Do what you can, with what you have, where you are.', 'a': 'Theodore Roosevelt'},
    {'q': 'Success is not final, failure is not fatal: it is the courage to continue that counts.', 'a': 'Winston Churchill'},
    {'q': 'It always seems impossible until it’s done.', 'a': 'Nelson Mandela'},
    {'q': 'Your time is limited, so don’t waste it living someone else’s life.', 'a': 'Steve Jobs'},
    {'q': 'Whether you think you can or you think you can’t, you’re right.', 'a': 'Henry Ford'},
    {'q': 'Happiness depends upon ourselves.', 'a': 'Aristotle'},
  ];
  static const _maxRetries = 3;
  static const _retryDelay = Duration(seconds: 2);
  static const _notificationId = 0;
  static const _notificationChannelId = 'quote_channel';
  static const _notificationChannelName = 'Quote of the Day';

  String _currentApiSourceName = _defaultApiSource.name;
  String _currentApiSourceUrl = _zenQuotesUrl;
  List<Quote>? _localTypefitQuotes;

  Quote? _currentQuote;
  bool _isLoading = false;
  final bool _isOffline = false;
  DateTime? _lastPressed;
  List<Quote> _quoteHistory = [];
  List<Quote> _favorites = [];
  Map<String, int> _quoteRatings = {};
  bool _enableNotifications = true;
  String _notificationTime = '08:00';
  int _streakCount = 0;
  DateTime? _lastOpened;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final GlobalKey _quoteCardKey = GlobalKey();
  final GlobalKey _exportCardKey = GlobalKey();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool get enableNotifications => _enableNotifications;
  List<Quote> get quoteHistory => _quoteHistory;
  List<Quote> get favorites => _favorites;
  Quote? get currentQuote => _currentQuote;
  Map<String, int> get quoteRatings => _quoteRatings;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.wait([
      _initializeNotifications(),
      _initializeTimeZone(),
      _getSavedData(),
      _loadRatings(),
      _loadApiSettings(),
      _updateStreak(),
    ]);
    final prefs = await SharedPreferences.getInstance();
    _notificationTime = prefs.getString('notification_time') ?? '08:00';
    await _getQuote();
  }

  Future<void> _initializeNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: android);
    await _notificationsPlugin.initialize(init, onDidReceiveNotificationResponse: (resp) async {
      if (resp.payload == 'daily_quote') await _getQuote();
    });
  }

  Future<void> _initializeTimeZone() async {
    tz.initializeTimeZones();
  }

  Future<void> _getSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedQuote = prefs.getString('quote');
    final savedHistory = prefs.getString('quote_history');
    final savedFavorites = prefs.getString('favorites');
    setState(() {
      if (savedQuote != null) {
        try { _currentQuote = Quote.fromJson(jsonDecode(savedQuote)); } catch (_) {}
      }
      if (savedHistory != null) {
        try { _quoteHistory = (jsonDecode(savedHistory) as List).map((e) => Quote.fromJson(e)).toList(); } catch (_) {}
      }
      if (savedFavorites != null) {
        try { _favorites = (jsonDecode(savedFavorites) as List).map((e) => Quote.fromJson(e)).toList(); } catch (_) {}
      }
      _enableNotifications = prefs.getBool('enable_notifications') ?? true;
    });
  }

  Future<void> _loadRatings() async {
    final prefs = await SharedPreferences.getInstance();
    final ratingsJson = prefs.getString('quote_ratings');
    if (ratingsJson != null) {
      try { _quoteRatings = Map<String, int>.from(jsonDecode(ratingsJson)); } catch (_) {}
    }
  }

  Future<void> _updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastOpenedStr = prefs.getString('last_opened');
    final today = DateTime(now.year, now.month, now.day);
    if (lastOpenedStr != null) {
      try {
        _lastOpened = DateTime.parse(lastOpenedStr);
        final lastDay = DateTime(_lastOpened!.year, _lastOpened!.month, _lastOpened!.day);
        final diff = today.difference(lastDay).inDays;
        if (diff == 1) { _streakCount = (prefs.getInt('streak_count') ?? 0) + 1; } else if (diff > 1) { _streakCount = 1; }
      } catch (_) { _streakCount = 1; }
    } else {
      _streakCount = 1;
    }
    await prefs.setString('last_opened', now.toIso8601String());
    await prefs.setInt('streak_count', _streakCount);
    setState(() {});
  }

  Future<void> rateQuote(String id, int rating) async {
    final prefs = await SharedPreferences.getInstance();
    if (rating == 0) {
      _quoteRatings.remove(id);
    } else {
      _quoteRatings[id] = rating;
    }
    await prefs.setString('quote_ratings', jsonEncode(_quoteRatings));
    setState(() {});
  }
  
  Future<void> _loadApiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentApiSourceName = prefs.getString('api_source_name') ?? _defaultApiSource.name;
      _currentApiSourceUrl = prefs.getString('api_source_url') ?? _zenQuotesUrl;
    });

    if (_currentApiSourceName == QuoteApiSource.typefitLocal.name) {
      await _loadLocalTypefitQuotes();
    }
  }

  Future<void> _loadLocalTypefitQuotes() async {
    try {
      final jsonString = await rootBundle.loadString('assets/quotes.json'); 
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _localTypefitQuotes = jsonList
          .map((e) => Quote.fromJson(e as Map<String, dynamic>, source: QuoteApiSource.typefitLocal.name))
          .toList();
      debugPrint('Loaded ${_localTypefitQuotes!.length} local quotes.');
    } catch (e) {
      debugPrint('Error loading local Type.fit quotes: $e');
      _localTypefitQuotes = [];
    }
  }

  Future<void> updateApiSource(String name, String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_source_name', name);
    await prefs.setString('api_source_url', url);

    setState(() {
      _currentApiSourceName = name;
      _currentApiSourceUrl = url;
      _localTypefitQuotes = null;
    });

    if (name == QuoteApiSource.typefitLocal.name) {
      await _loadLocalTypefitQuotes();
    }
    await _getQuote();
  }

  Future<void> _getQuote({int retryCount = 0}) async {
    if (_isLoading) return;
    setState(() { _isLoading = true; _animationController.reset(); });

    Quote? newQuote;
    try {
      final currentSource = _currentApiSourceName;
      final currentUrl = _currentApiSourceUrl;

      if (currentSource == QuoteApiSource.typefitLocal.name) {
        if (_localTypefitQuotes == null || _localTypefitQuotes!.isEmpty) {
          await _loadLocalTypefitQuotes();
        }
        if (_localTypefitQuotes!.isNotEmpty) {
          final random = Random();
          newQuote = _localTypefitQuotes![random.nextInt(_localTypefitQuotes!.length)];
        } else {
          _showError('Local quote file not found or empty.');
        }

      } else {
        final resp = await http.get(Uri.parse(currentUrl)).timeout(const Duration(seconds: 10), onTimeout: () => http.Response('timeout', 408));

        if (resp.statusCode != 200) {
          if (retryCount < _maxRetries) { await Future.delayed(_retryDelay); return _getQuote(retryCount: retryCount + 1); }
          final fb = (_fallbackQuotes..shuffle()).first;
          newQuote = Quote.fromJson({'q': fb['q'], 'a': fb['a'], '_id': DateTime.now().toIso8601String()});
        } else {
          dynamic data;
          try { data = jsonDecode(resp.body); } catch (_) {
            if (retryCount < _maxRetries) { await Future.delayed(_retryDelay); return _getQuote(retryCount: retryCount + 1); }
            _showError('Failed to parse quote response from $currentSource.');
            return;
          }

          Map<String, dynamic> quoteJson;

          if (currentSource == QuoteApiSource.zenquotes.name) {
            // ZenQuotes returns a list: [{"q":..., "a":...}]
            if (data is List && data.isNotEmpty && data.first is Map) {
              quoteJson = data.first as Map<String, dynamic>;
            } else {
              if (retryCount < _maxRetries) { await Future.delayed(_retryDelay); return _getQuote(retryCount: retryCount + 1); }
              _showError('Invalid ZenQuotes data structure.');
              return;
            }
          } else if (currentSource == QuoteApiSource.quotegarden.name) {
            // QuoteGarden returns: {"data": [{"quoteText":..., "quoteAuthor":...}, ...]}
            if (data is Map && data['data'] is List && (data['data'] as List).isNotEmpty && (data['data'] as List).first is Map) {
              quoteJson = (data['data'] as List).first as Map<String, dynamic>;
            } else {
              if (retryCount < _maxRetries) { await Future.delayed(_retryDelay); return _getQuote(retryCount: retryCount + 1); }
              _showError('Invalid QuoteGarden data structure.');
              return;
            }
          } else {
            // If API not recognized, use fallback after max retries
            if (retryCount < _maxRetries) { await Future.delayed(_retryDelay); return _getQuote(retryCount: retryCount + 1); }
            _showError('Unknown API source configuration.');
            return;
          }

          newQuote = Quote.fromJson(quoteJson, source: currentSource);
        }
      }

      if (newQuote != null && newQuote.content.isNotEmpty) {
        setState(() { _currentQuote = newQuote; _animationController.forward(); });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('quote', jsonEncode(newQuote.toJson()));
        await prefs.setString('last_notification', DateTime.now().toIso8601String());

        if (!_quoteHistory.any((q) => q.id == newQuote!.id)) {
          _quoteHistory.add(newQuote);
          if (_quoteHistory.length > 50) _quoteHistory.removeAt(0);
          await prefs.setString('quote_history', jsonEncode(_quoteHistory.map((q) => q.toJson()).toList()));
        }

        if (_enableNotifications) { await _scheduleNotification(newQuote.content, newQuote.author); }
      } else {
        if (retryCount < _maxRetries) { await Future.delayed(_retryDelay); return _getQuote(retryCount: retryCount + 1); }
        _showError('Could not fetch or parse any quote data.');
      }
    } catch (e) {
      debugPrint('General fetch error: $e');
      if (retryCount < _maxRetries) { await Future.delayed(_retryDelay); return _getQuote(retryCount: retryCount + 1); }
      final fb = (_fallbackQuotes..shuffle()).first;
      setState(() { _currentQuote = Quote.fromJson({'q': fb['q'], 'a': fb['a'], '_id': DateTime.now().toIso8601String()}); _animationController.forward(); });
      _showError('A network error occurred. Displaying a fallback quote.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> addCustomQuote(Quote newQuote) async {
    setState(() {
      _currentQuote = newQuote;
      _animationController..reset()..forward();
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quote', jsonEncode(newQuote.toJson()));
    
    if (!_quoteHistory.any((q) => q.id == newQuote.id)) {
      _quoteHistory.add(newQuote);
      if (_quoteHistory.length > 50) _quoteHistory.removeAt(0);
      await prefs.setString('quote_history', jsonEncode(_quoteHistory.map((q) => q.toJson()).toList()));
    }
  }

  Future<void> rescheduleNotification() async {
    if (_enableNotifications && _currentQuote != null) {
      await _scheduleNotification(_currentQuote!.content, _currentQuote!.author);
    }
  }
  
  Future<bool> _requestExactAlarmPermission() async => (await Permission.scheduleExactAlarm.request()).isGranted;

  Future<void> _scheduleNotification(String quote, String author) async {
    const androidDetails = AndroidNotificationDetails(_notificationChannelId, _notificationChannelName, importance: Importance.high, priority: Priority.high, styleInformation: BigTextStyleInformation(''), showWhen: true);
    const details = NotificationDetails(android: androidDetails);
    final scheduled = _nextInstanceOfTime(_notificationTime);
    try {
      final useExact = await _requestExactAlarmPermission();
      await _notificationsPlugin.zonedSchedule(
        _notificationId, 
        'Propelex', 
        '$quote...\n${author.isNotEmpty ? '- $author' : ''}', 
        scheduled, 
        details, 
        payload: 'daily_quote', 
        androidScheduleMode: useExact 
            ? AndroidScheduleMode.exactAllowWhileIdle 
            : AndroidScheduleMode.alarmClock,
      );
    } catch (e) {
      debugPrint('Notification scheduling error: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(String time) {
    final now = tz.TZDateTime.now(tz.local);
    final parts = time.split(':');
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
  
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Theme.of(context).colorScheme.onErrorContainer,
          onPressed: _getQuote,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    if (mounted) Get.offAll(() => const LoginPage());
  }

  Future<Uint8List?> _generateQuoteImageBytes(Quote quote, BuildContext context, QuoteImageTheme theme) async {
    final double width = 1080;
    final double height = 1080;
    final double innerPadding = 80;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    ui.Color backgroundStartColor;
    ui.Color backgroundEndColor;
    ui.Color cardColor;
    ui.Color primaryColor = ui.Color(cs.primary.value);
    ui.Color onSurfaceColor = ui.Color(cs.onSurface.value);

    TextStyle quoteStyle;
    TextStyle authorStyle;
    TextStyle brandingStyle;
    TextStyle ctaStyle;
    double quoteIconSize;
    double separatorWidth;
    double cardRadius;

    switch (theme) {
      case QuoteImageTheme.elegant:
        backgroundStartColor = isDark ? const ui.Color(0xFF0F0F0F) : const ui.Color(0xFFFBFBFB);
        backgroundEndColor = isDark ? const ui.Color(0xFF2E2E2E) : const ui.Color(0xFFFFFFFF);
        cardColor = isDark ? const ui.Color(0xFF1A1A1A) : const ui.Color(0xFFFFFFFF);
        primaryColor = ui.Color(isDark ? Colors.tealAccent.value : Colors.teal.shade700.value);
        
        quoteStyle = TextStyle(
          color: onSurfaceColor, fontSize: 36, height: 1.5,
          fontWeight: FontWeight.w300, fontStyle: FontStyle.italic,
        );
        authorStyle = TextStyle(
          color: primaryColor, fontSize: 28, fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        );
        brandingStyle = TextStyle(
          color: primaryColor, fontSize: 20, fontWeight: FontWeight.w700,
        );
        ctaStyle = TextStyle(
          color: onSurfaceColor.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.w400,
        );
        quoteIconSize = 100;
        separatorWidth = 100;
        cardRadius = 50;
        break;

      case QuoteImageTheme.bold:
        backgroundStartColor = isDark ? const ui.Color(0xFF000000) : const ui.Color(0xFFFFFFFF);
        backgroundEndColor = isDark ? const ui.Color(0xFF000000) : const ui.Color(0xFFFFFFFF);
        cardColor = isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.05);
        onSurfaceColor = ui.Color(isDark ? Colors.white.value : Colors.black.value);
        
        quoteStyle = TextStyle(
          color: onSurfaceColor, fontSize: 44, height: 1.2,
          fontWeight: FontWeight.w900,
        );
        authorStyle = TextStyle(
          color: primaryColor, fontSize: 24, fontWeight: FontWeight.w700,
        );
        brandingStyle = TextStyle(
          color: onSurfaceColor.withOpacity(0.7), fontSize: 18, fontWeight: FontWeight.w400,
        );
        ctaStyle = TextStyle(
          color: primaryColor, fontSize: 20, fontWeight: FontWeight.w700,
        );
        quoteIconSize = 0;
        separatorWidth = 0;
        cardRadius = 0;
        break;
        
      case QuoteImageTheme.cinematic:
        backgroundStartColor = const ui.Color(0xFF000000);
        backgroundEndColor = const ui.Color(0xFF151515);
        cardColor = const ui.Color(0x00000000);
        onSurfaceColor = const ui.Color(0xFFFFFFFF);
        primaryColor = ui.Color(isDark ? Colors.cyanAccent.value : Colors.teal.shade300.value);

        quoteStyle = TextStyle(
          color: onSurfaceColor, fontSize: 40, height: 1.6,
          fontWeight: FontWeight.w200,
          letterSpacing: 1.5,
        );
        authorStyle = TextStyle(
          color: onSurfaceColor.withOpacity(0.7), fontSize: 20, fontWeight: FontWeight.w400,
          fontStyle: FontStyle.italic,
        );
        brandingStyle = TextStyle(
          color: onSurfaceColor.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.w400,
        );
        ctaStyle = TextStyle(
          color: primaryColor.withOpacity(0.9), fontSize: 18, fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        );
        quoteIconSize = 0;
        separatorWidth = 0;
        cardRadius = 0;
        break;


      case QuoteImageTheme.modern:
        backgroundStartColor = isDark ? const ui.Color(0xFF0A0A0A) : const ui.Color(0xFFF0F0F0);
        backgroundEndColor = isDark ? const ui.Color(0xFF1E1E1E) : const ui.Color(0xFFFFFFFF);
        cardColor = isDark ? const ui.Color(0xFF282828) : const ui.Color(0xFFFFFFFF);
        
        quoteStyle = TextStyle(
          color: onSurfaceColor, fontSize: 38, height: 1.4,
          fontWeight: FontWeight.w700, fontStyle: FontStyle.italic,
        );
        authorStyle = TextStyle(
          color: onSurfaceColor.withOpacity(0.9), fontSize: 24, fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
        );
        brandingStyle = TextStyle(
          color: primaryColor, fontSize: 20, fontWeight: FontWeight.w700,
        );
        ctaStyle = TextStyle(
          color: onSurfaceColor.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.w400,
        );
        quoteIconSize = 72;
        separatorWidth = 80;
        cardRadius = 30;
        break;
    }
    
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    
    final center = Offset(width / 2, height / 2);
    final backgroundPaint = Paint()
      ..shader = ui.Gradient.radial(
        center, width * 0.7, [backgroundStartColor, backgroundEndColor], [0.0, 1.0], ui.TileMode.clamp,
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), backgroundPaint);
    
    final cardWidth = width * 0.85;
    final cardHeight = height * 0.85;
    final cardRect = Rect.fromLTWH((width - cardWidth) / 2, (height - cardHeight) / 2, cardWidth, cardHeight);
    final RRect cardRRect = RRect.fromRectAndRadius(cardRect, Radius.circular(cardRadius));
    
    if (theme != QuoteImageTheme.bold && theme != QuoteImageTheme.cinematic) {
      final shadowPaint = Paint()
        ..color = isDark ? const ui.Color(0x80000000) : const ui.Color(0x30808080)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20.0); 
      canvas.drawRRect(cardRRect.shift(const Offset(0, 15)), shadowPaint); 
    }
    
    if (theme != QuoteImageTheme.bold && theme != QuoteImageTheme.cinematic) {
        canvas.drawRRect(cardRRect, Paint()..color = cardColor);
    } else if (theme == QuoteImageTheme.bold) {
        canvas.drawRRect(cardRRect, Paint()
            ..color = primaryColor.withOpacity(0.2)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 3.0);
    }
    
    final contentWidth = cardWidth - 2 * innerPadding;
    
    final quotePainter = TextPainter(
      text: TextSpan(text: quote.content, style: quoteStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    quotePainter.layout(maxWidth: contentWidth);
    
    // Author Painter
    final authorText = theme == QuoteImageTheme.elegant ? quote.author.toUpperCase() : '— ${quote.author}';
    final authorPainter = TextPainter(
      text: TextSpan(text: authorText, style: authorStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    authorPainter.layout(maxWidth: contentWidth);

    final quoteIconPainter = TextPainter(
      text: TextSpan(
        text: theme == QuoteImageTheme.elegant ? 'I' : '“', 
        style: TextStyle(
          color: primaryColor.withOpacity(0.6),
          fontSize: quoteIconSize,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    if (quoteIconSize > 0) quoteIconPainter.layout();

    final ctaText = 'Get your daily inspiration: Propelex App';
    final ctaPainter = TextPainter(
      text: TextSpan(text: ctaText, style: ctaStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    ctaPainter.layout(maxWidth: contentWidth);
    
    double totalContentHeight = 0;
    
    if (quoteIconSize > 0) {
        totalContentHeight += quoteIconPainter.height;
        totalContentHeight -= (theme == QuoteImageTheme.elegant ? 40 : 20); 
    }
    
    totalContentHeight += quotePainter.height;
    
    totalContentHeight += 40; 
    
    if (separatorWidth > 0) {
        totalContentHeight += 4.0;
        totalContentHeight += 30;
    }
    
    totalContentHeight += authorPainter.height;
    
    totalContentHeight += 50; 
    
    totalContentHeight += ctaPainter.height;
    
    final cardCenterY = cardRect.top + cardHeight / 2;
    double currentY = cardCenterY - totalContentHeight / 2;
  
    if (quoteIconSize > 0) {
      final iconX = cardRect.left + cardWidth / 2 - quoteIconPainter.width / 2;
      quoteIconPainter.paint(canvas, Offset(iconX, currentY)); 
      currentY += quoteIconPainter.height - (theme == QuoteImageTheme.elegant ? 40 : 20);
    }

    final quoteX = cardRect.left + innerPadding + (contentWidth - quotePainter.width) / 2;
    quotePainter.paint(canvas, Offset(quoteX, currentY));
    currentY += quotePainter.height + 40;

    if (separatorWidth > 0) {
      final separatorHeight = 4.0;
      final separatorRect = Rect.fromLTWH(cardRect.left + cardWidth / 2 - separatorWidth / 2, currentY, separatorWidth, separatorHeight);
      canvas.drawRRect(RRect.fromRectAndRadius(separatorRect, const Radius.circular(2)), Paint()..color = primaryColor.withOpacity(0.8)); 
      currentY += separatorHeight + 30;
    }

    final authorX = cardRect.left + cardWidth / 2 - authorPainter.width / 2;
    authorPainter.paint(canvas, Offset(authorX, currentY));
    currentY += authorPainter.height + 50; 

    final ctaX = cardRect.left + cardWidth / 2 - ctaPainter.width / 2;
    ctaPainter.paint(canvas, Offset(ctaX, currentY));

    final iconSize = 20.0;
    final space = 10.0;
    
    final brandingPainter = TextPainter(
      text: TextSpan(text: 'Propelex', style: brandingStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    brandingPainter.layout();

    final brandingTotalWidth = iconSize + space + brandingPainter.width;
    final brandingStartX = width / 2 - brandingTotalWidth / 2;
    
    final marginAreaY = (height - cardRect.bottom);
    final brandingY = cardRect.bottom + (marginAreaY - brandingPainter.height) / 2;

    canvas.drawCircle(Offset(brandingStartX + iconSize / 2, brandingY + iconSize / 2), iconSize / 2, Paint()..color = primaryColor);

    brandingPainter.paint(canvas, Offset(brandingStartX + iconSize + space, brandingY));

    final ui.Image image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveImageToGallery() async {
    if (_currentQuote == null) {
      _showError('No quote available to save');
      return;
    }
    
    final selectedTheme = await _showImageOptions();
    if (selectedTheme == null) return;

    Uint8List? bytes;

    try {
      bytes = await _generateQuoteImageBytes(_currentQuote!, context, selectedTheme);

      if (bytes == null) {
        _showError('Failed to generate quote image');
        return;
      }

      await Gal.putImageBytes(
        bytes,
        album: 'Propelex',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text('Quote image saved to gallery!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on GalException catch (e) {
      debugPrint('Gal save failed: ${e.type}');
      if (!mounted) return;
      
      String errorMessage;
      if (e.type == GalExceptionType.accessDenied) {
        errorMessage = 'Storage permission is required to save images. Opening settings...';
        _showError(errorMessage); 
        openAppSettings(); 
      } else {
        errorMessage = 'Failed to save image: ${e.type.toString().split('.').last}';
        _showError(errorMessage);
      }
    } catch (e) {
      debugPrint('General error saving image: $e');
      _showError('An unexpected error occurred while saving the image.');
    }
  }

  Future<QuoteImageTheme?> _showImageOptions() async { 
    return await showModalBottomSheet<QuoteImageTheme>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Image Style',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              ...QuoteImageTheme.values.map((theme) {
                IconData leadingIcon;
                switch (theme) {
                  case QuoteImageTheme.modern:
                    leadingIcon = Icons.auto_awesome_rounded;
                    break;
                  case QuoteImageTheme.elegant:
                    leadingIcon = Icons.brush_rounded;
                    break;
                  case QuoteImageTheme.bold:
                    leadingIcon = Icons.flash_on_rounded;
                    break;
                  case QuoteImageTheme.cinematic:
                    leadingIcon = Icons.movie_filter_rounded;
                    break;
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(leadingIcon),
                    title: Text(theme.name),
                    onTap: () => Navigator.pop(context, theme),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _shareAsText() {
    if (_currentQuote != null) {
      Share.share('${_currentQuote!.content} — ${_currentQuote!.author}\n\n#PropelexQuotes');
    } else {
      _showError('No quote available to share');
    }
  }

  void _copyToClipboard() {
    if (_currentQuote != null) {
      Clipboard.setData(ClipboardData(text: '${_currentQuote!.content} — ${_currentQuote!.author}'));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.content_copy_rounded, color: Colors.blueGrey, size: 20),
              SizedBox(width: 8),
              Text('Quote copied to clipboard!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError('No quote available to copy');
    }
  }

  void _toggleFavorite() async {
    if (_currentQuote == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (_favorites.any((q) => q.id == _currentQuote!.id)) {
      _favorites.removeWhere((q) => q.id == _currentQuote!.id);
    } else {
      _favorites.add(_currentQuote!);
    }
    await prefs.setString('favorites', jsonEncode(_favorites.map((q) => q.toJson()).toList()));
    setState(() {});
  }
  
  Future<void> removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favorites.removeWhere((q) => q.id == id);
    });
    await prefs.setString('favorites', jsonEncode(_favorites.map((q) => q.toJson()).toList()));
  }

  Future<void> removeHistoryItem(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _quoteHistory.removeWhere((q) => q.id == id);
      _quoteRatings.removeWhere((key, value) => key == id);
    });
    await prefs.setString('quote_history', jsonEncode(_quoteHistory.map((e) => e.toJson()).toList()));
    await prefs.setString('quote_ratings', jsonEncode(_quoteRatings));
  }

  void _handleMenuItemSelection(String value) {
    switch (value) {
      case 'refresh':
        _getQuote();
        break;
      case 'favorites':
        Get.to(() => FavoritesPage(homeState: this));
        break;
      case 'history':
        Get.to(() => HistoryPage(homeState: this));
        break;
      case 'search':
        Get.to(() => SearchPage(homeState: this));
        break;
      case 'rated':
        Get.to(() => RatedQuotesPage(homeState: this));
        break;
      case 'add':
        Get.to(() => AddQuotePage(homeState: this)); 
        break;
      case 'settings':
        Get.to(() => SettingsPage(homeState: this));
        break;
      case 'logout':
        _logout();
        break;
    }
  }

  void setCurrentQuote(Quote quote) {
    setState(() {
      _currentQuote = quote;
      _animationController..reset()..forward();
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Widget _buildRatingWidget(BuildContext context, int rating, String id) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttons = List.generate(5, (index) {
      final starValue = index + 1;
      final isRated = starValue <= rating;
      return IconButton(
        icon: Icon(
          isRated ? Icons.star_rounded : Icons.star_border_rounded,
          color: isRated ? Colors.amber.shade700 : colorScheme.onSurface.withOpacity(0.4),
        ),
        iconSize: 24,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: () => rateQuote(id, starValue),
        tooltip: '$starValue Star${starValue > 1 ? 's' : ''}',
      );
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: buttons,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = _currentQuote != null && _favorites.any((q) => q.id == _currentQuote!.id);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastPressed == null || now.difference(_lastPressed!) > const Duration(seconds: 2)) {
          _lastPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.exit_to_app_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Press back again to exit',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                  ),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withOpacity(0.04),
                        colorScheme.secondary.withOpacity(0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Propelex',
                                  style: textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_streakCount > 0)
                                  Tooltip(
                                    message: 'Daily Quote Streak',
                                    child: Chip(
                                      backgroundColor: colorScheme.tertiaryContainer,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.local_fire_department_rounded, size: 16, color: colorScheme.onTertiaryContainer),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$_streakCount',
                                            style: textTheme.labelLarge?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: colorScheme.onTertiaryContainer,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            PopupMenuButton<String>(
                              onSelected: _handleMenuItemSelection,
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'refresh',
                                  child: Row(
                                    children: [
                                      Icon(Icons.refresh_rounded, size: 20, color: colorScheme.primary),
                                      const SizedBox(width: 12),
                                      const Text('Refresh'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'favorites',
                                  child: Row(
                                    children: [
                                      Icon(Icons.favorite_rounded, size: 20, color: colorScheme.primary),
                                      const SizedBox(width: 12),
                                      const Text('Favorites'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'history',
                                  child: Row(
                                    children: [
                                      Icon(Icons.history_rounded, size: 20, color: colorScheme.primary),
                                      const SizedBox(width: 12),
                                      const Text('History'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'search',
                                  child: Row(
                                    children: [
                                      Icon(Icons.search_rounded, size: 20, color: colorScheme.primary),
                                      const SizedBox(width: 12),
                                      const Text('Search Quotes'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'rated',
                                  child: Row(
                                    children: [
                                      Icon(Icons.star_rounded, size: 20, color: colorScheme.primary),
                                      const SizedBox(width: 12),
                                      const Text('Rated Quotes'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'add',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_circle_outline_rounded, size: 20, color: colorScheme.primary),
                                      const SizedBox(width: 12),
                                      const Text('Add Custom Quote'),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'settings',
                                  child: Row(
                                    children: [
                                      Icon(Icons.settings_rounded, size: 20, color: colorScheme.onSurface),
                                      const SizedBox(width: 12),
                                      const Text('Settings'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'logout',
                                  child: Row(
                                    children: [
                                      Icon(Icons.logout_rounded, size: 20, color: colorScheme.error),
                                      const SizedBox(width: 12),
                                      const Text('Logout'),
                                    ],
                                  ),
                                ),
                              ],
                              icon: Icon(Icons.more_vert_rounded, color: colorScheme.onBackground),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // --- Quote Card ---
                                  if (_currentQuote != null) 
                                    FadeTransition(
                                      opacity: _fadeAnimation,
                                      child: RepaintBoundary(
                                        key: _quoteCardKey,
                                        child: _QuoteCard(
                                          quote: _currentQuote!,
                                          isOffline: _isOffline,
                                          ratings: _quoteRatings,
                                          onRate: rateQuote,
                                        ),
                                      ),
                                    )
                                  else
                                    _buildLoadingOrPlaceholder(context),

                                  const SizedBox(height: 24),

                                  if (_currentQuote != null)
                                    FadeTransition(
                                      opacity: _fadeAnimation,
                                      child: _buildRatingWidget(
                                        context,
                                        _quoteRatings[_currentQuote!.id] ?? 0,
                                        _currentQuote!.id,
                                      ),
                                    ),
                                  
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        if (_currentQuote != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _MinimalIconButton(
                                icon: Icons.share_rounded,
                                tooltip: 'Share',
                                onPressed: _shareAsText,
                              ),
                              _MinimalIconButton(
                                icon: Icons.image_rounded,
                                tooltip: 'Save as Image',
                                onPressed: _saveImageToGallery,
                              ),
                              _MinimalIconButton(
                                icon: Icons.content_copy_rounded,
                                tooltip: 'Copy',
                                onPressed: _copyToClipboard,
                              ),
                              _MinimalIconButton(
                                icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                tooltip: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                                onPressed: _toggleFavorite,
                                isActive: isFavorite,
                              ),
                              _MinimalIconButton(
                                icon: Icons.navigate_next_rounded,
                                tooltip: 'Next Quote',
                                onPressed: _getQuote,
                                isActive: true,
                              ),
                            ],
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: ElevatedButton.icon(
                              onPressed: _getQuote,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Refresh'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Loading Overlay
              if (_isLoading)
                Container(
                  color: colorScheme.surface.withOpacity(0.4),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),

              Positioned(
                left: -1000,
                top: -1000,
                child: RepaintBoundary(
                  key: _exportCardKey,
                  child: SizedBox(
                    width: 800,
                    height: 800,
                    child: Center(
                      child: Text(_currentQuote?.content ?? 'Loading...', style: const TextStyle(fontSize: 40)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOrPlaceholder(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _isLoading
              ? CircularProgressIndicator(color: colorScheme.primary)
              : Icon(Icons.waving_hand_rounded, size: 48, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            _isLoading ? 'Fetching inspiration...' : 'Welcome to Propelex!',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the refresh button to get your daily inspiration',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Minimal icon button widget for clean UI
class _MinimalIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;

  const _MinimalIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = brightness == Brightness.dark ? Colors.white : Colors.black;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: isActive
                  ? color
                  : color.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final Quote quote;
  final bool isOffline;
  final Map<String, int> ratings;
  final Function(String, int) onRate;

  const _QuoteCard({
    required this.quote,
    required this.isOffline,
    required this.ratings,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(minHeight: 200),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quote Content
            Text(
              '“${quote.content}”',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Author
            Text(
              '- ${quote.author}',
              style: textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Optional: Offline indicator
            if (isOffline) 
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Offline Mode',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}