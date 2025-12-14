import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'login.dart';
import 'search.dart';
import 'settings.dart';

class Quote {
  final String id;
  final String content;
  final String author;

  Quote({required this.id, required this.content, required this.author});

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    id: json['_id'] as String? ?? DateTime.now().toIso8601String(),
    content: json['q'] as String? ?? 'No quote available',
    author: json['a'] as String? ?? 'Unknown',
  );

  Map<String, dynamic> toJson() => {'_id': id, 'q': content, 'a': author};
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  static const _quoteApiUrl = 'https://zenquotes.io/api/random';
  static const List<Map<String, String>> _fallbackQuotes = [
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

  Quote? _currentQuote;
  bool _isLoading = false;
  bool _isOffline = false;
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
  bool _showExportWidget = false;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool get enableNotifications => _enableNotifications;
  List<Quote> get quoteHistory => _quoteHistory;
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
      _updateStreak(),
    ]);
    final prefs = await SharedPreferences.getInstance();
    _notificationTime = prefs.getString('notification_time') ?? '08:00';
    // Always load a fresh quote on launch
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

  Future<void> _rateQuote(String id, int rating) async {
    final prefs = await SharedPreferences.getInstance();
    _quoteRatings[id] = rating;
    await prefs.setString('quote_ratings', jsonEncode(_quoteRatings));
    setState(() {});
  }

  Future<void> _getQuote({int retryCount = 0}) async {
    if (_isLoading) return;
    setState(() { _isLoading = true; _animationController.reset(); });
    try {
      final resp = await http.get(Uri.parse(_quoteApiUrl)).timeout(const Duration(seconds: 10), onTimeout: () => http.Response('timeout', 408));
      if (resp.statusCode != 200) {
        if (retryCount < _maxRetries) { await Future.delayed(_retryDelay); return _getQuote(retryCount: retryCount + 1); }
        final fb = (_fallbackQuotes..shuffle()).first;
        setState(() { _currentQuote = Quote.fromJson({'q': fb['q'], 'a': fb['a'], '_id': DateTime.now().toIso8601String()}); _animationController.forward(); });
        return;
      }
      dynamic data;
      try { data = jsonDecode(resp.body); } catch (_) {
        if (retryCount < _maxRetries) { await Future.delayed(_retryDelay); return _getQuote(retryCount: retryCount + 1); }
        final fb = (_fallbackQuotes..shuffle()).first;
        setState(() { _currentQuote = Quote.fromJson({'q': fb['q'], 'a': fb['a'], '_id': DateTime.now().toIso8601String()}); _animationController.forward(); });
        return;
      }
      if (data is! List || data.isEmpty || data.first is! Map) {
        if (retryCount < _maxRetries) { await Future.delayed(_retryDelay); return _getQuote(retryCount: retryCount + 1); }
        final fb = (_fallbackQuotes..shuffle()).first;
        setState(() { _currentQuote = Quote.fromJson({'q': fb['q'], 'a': fb['a'], '_id': DateTime.now().toIso8601String()}); _animationController.forward(); });
        return;
      }
      final newQuote = Quote.fromJson(data.first as Map<String, dynamic>);
      if (newQuote.content.isEmpty || newQuote.author.isEmpty) {
        if (retryCount < _maxRetries) { await Future.delayed(_retryDelay); return _getQuote(retryCount: retryCount + 1); }
        _showError('Invalid quote data');
        return;
      }
      setState(() { _currentQuote = newQuote; _animationController.forward(); });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('quote', jsonEncode(newQuote.toJson()));
      await prefs.setString('last_notification', DateTime.now().toIso8601String());
      if (!_quoteHistory.any((q) => q.id == newQuote.id)) {
        _quoteHistory.add(newQuote);
        if (_quoteHistory.length > 50) _quoteHistory.removeAt(0);
        await prefs.setString('quote_history', jsonEncode(_quoteHistory.map((q) => q.toJson()).toList()));
      }
      if (_enableNotifications) { await _scheduleNotification(newQuote.content, newQuote.author); }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _requestExactAlarmPermission() async => (await Permission.scheduleExactAlarm.request()).isGranted;

  Future<void> _scheduleNotification(String quote, String author) async {
    const androidDetails = AndroidNotificationDetails(_notificationChannelId, _notificationChannelName, importance: Importance.high, priority: Priority.high, styleInformation: BigTextStyleInformation(''), showWhen: true);
    const details = NotificationDetails(android: androidDetails);
    final scheduled = _nextInstanceOfTime(_notificationTime);
    try {
      final useExact = await _requestExactAlarmPermission();
      await _notificationsPlugin.zonedSchedule(_notificationId, 'Quote of the Day', '$quote\n- $author', scheduled, details, androidScheduleMode: useExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle, payload: 'daily_quote');
    } catch (_) { _showError('Failed to schedule daily notification'); }
  }

  tz.TZDateTime _nextInstanceOfTime(String hhmm) {
    final now = tz.TZDateTime.now(tz.local);
    final p = hhmm.split(':');
    final t = tz.TZDateTime(tz.local, now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
    return t.isBefore(now) ? t.add(const Duration(days: 1)) : t;
  }

  Future<void> rescheduleNotification() async {
    if (_currentQuote != null) {
      await _notificationsPlugin.cancel(_notificationId);
      await _scheduleNotification(_currentQuote!.content, _currentQuote!.author);
    }
  }


  Future<void> updateNotifications(bool value) async {
    setState(() => _enableNotifications = value);
    if (value) {
      try {
        final status = await Permission.notification.request();
        if (!status.isGranted) {
          if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification permission denied'))); }
          value = false;
          setState(() => _enableNotifications = false);
        }
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_notifications', value);
    if (!value) {
      await _notificationsPlugin.cancel(_notificationId);
    } else if (_currentQuote != null) {
      await _scheduleNotification(_currentQuote!.content, _currentQuote!.author);
    }
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

  Future<void> _addCustomQuote() async {
    final quoteController = TextEditingController();
    final authorController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text('Add Custom Quote'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create your own inspirational quote',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: quoteController,
                maxLines: 4,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a quote';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Quote',
                  hintText: 'Enter your inspirational quote...',
                  prefixIcon: Icon(
                    Icons.format_quote_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: authorController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Author (optional)',
                  hintText: 'Author name',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final q = quoteController.text.trim();
              final a = authorController.text.trim().isEmpty ? 'Unknown' : authorController.text.trim();
              final custom = Quote(id: DateTime.now().toIso8601String(), content: q, author: a);
              final prefs = await SharedPreferences.getInstance();
              setState(() {
                _currentQuote = custom;
                _quoteHistory.add(custom);
              });
              await prefs.setString('quote', jsonEncode(custom.toJson()));
              await prefs.setString('quote_history', jsonEncode(_quoteHistory.map((e) => e.toJson()).toList()));
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 12),
                        const Text('Custom quote added successfully'),
                      ],
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Quote'),
          ),
        ],
      ),
    );
  }

  void _shareQuote() {
    if (_currentQuote != null) {
      Share.share('${_currentQuote!.content}\n- ${_currentQuote!.author}', subject: 'Quote of the Day');
    } else {
      _showError('No quote available to share');
    }
  }

  Future<void> _onExportImage() async {
    if (_currentQuote == null) {
      _showError('No quote available');
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share image'),
              onTap: () async { Navigator.pop(ctx); await _shareQuoteAsImage(); },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Save image'),
              onTap: () async { Navigator.pop(ctx); await _saveQuoteImage(); },
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _captureExportPng({double pixelRatio = 3.0}) async {
    final ctx = _exportCardKey.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro is! RenderRepaintBoundary) return null;
    final image = await ro.toImage(pixelRatio: pixelRatio);
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd?.buffer.asUint8List();
  }

  Future<void> _shareQuoteAsImage() async {
    if (_currentQuote == null) { _showError('No quote available to share'); return; }
    try {
      final bytes = await _captureExportPng(pixelRatio: 3.0);
      if (bytes == null) { _showError('Failed to capture quote image'); return; }
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/quote.png').writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Quote of the Day');
    } catch (_) { _showError('Failed to share quote as image'); }
  }

  Future<void> _saveQuoteImage() async {
    try {
      final bytes = await _captureExportPng(pixelRatio: 3.0);
      if (bytes == null) { _showError('Failed to capture quote image'); return; }
      // Request permissions where needed (older Android / iOS Photos)
      try {
        if (Platform.isAndroid) {
          await Permission.storage.request();
        } else if (Platform.isIOS) {
          await Permission.photosAddOnly.request();
        }
      } catch (_) {}
      final name = 'quote_${DateTime.now().millisecondsSinceEpoch}.png';
      final result = await SaverGallery.saveImage(
        bytes,
        name: name,
        androidRelativePath: 'Pictures/Quotes',
        androidExistNotSave: false,
      );
      if (!mounted) return;
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Pictures/Quotes')));
      } else {
        _showError('Failed to save image');
      }
    } catch (_) {
      _showError('Failed to save image');
    }
  }

  Future<void> _quickSetNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('notification_time') ?? '08:00';
    final initial = TimeOfDay(
      hour: int.parse(saved.split(':')[0]),
      minute: int.parse(saved.split(':')[1]),
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final s = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await prefs.setString('notification_time', s);
      await rescheduleNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notification time set: $s')));
    }
  }

  void _copyQuote() {
    if (_currentQuote != null) {
      Clipboard.setData(ClipboardData(text: '${_currentQuote!.content}\n- ${_currentQuote!.author}'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Quote copied to clipboard',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
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

  void _showQuoteHistory() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Quote History',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_quoteHistory.length} quotes',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: _quoteHistory.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 64,
                      color: colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No history yet',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your quote history will appear here',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quoteHistory.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final quote = _quoteHistory[_quoteHistory.length - 1 - index];
                  final rating = _quoteRatings[quote.id];
                  final isRated = rating != null && rating > 0;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        quote.content,
                        style: textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '- ${quote.author}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            if (isRated)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$rating',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: Colors.amber.shade900,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: colorScheme.error,
                        ),
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          _quoteHistory.removeWhere((q) => q.id == quote.id);
                          await prefs.setString('quote_history', jsonEncode(_quoteHistory.map((e) => e.toJson()).toList()));
                          setState(() {});
                        },
                        tooltip: 'Remove from history',
                      ),
                      onTap: () {
                        setCurrentQuote(quote);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFavorites() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Favorites',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_favorites.length} quotes',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: _favorites.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 64,
                      color: colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No favorites yet',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the heart icon to save quotes',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _favorites.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final quote = _favorites[_favorites.length - 1 - index];
                  final rating = _quoteRatings[quote.id];
                  final isRated = rating != null && rating > 0;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Icon(
                        Icons.favorite_rounded,
                        color: Colors.red,
                        size: 24,
                      ),
                      title: Text(
                        quote.content,
                        style: textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '- ${quote.author}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            if (isRated)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$rating',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: Colors.amber.shade900,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: colorScheme.error,
                        ),
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          _favorites.removeWhere((q) => q.id == quote.id);
                          await prefs.setString('favorites', jsonEncode(_favorites.map((e) => e.toJson()).toList()));
                          setState(() {});
                        },
                        tooltip: 'Remove from favorites',
                      ),
                      onTap: () {
                        setCurrentQuote(quote);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRatedQuotes() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ratedQuotes = _quoteHistory.where((q) => _quoteRatings.containsKey(q.id)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: Colors.amber.shade600,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Rated Quotes',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${ratedQuotes.length} quotes',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: ratedQuotes.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_border_rounded,
                      size: 64,
                      color: colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No rated quotes yet',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rate quotes to see them here',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: ratedQuotes.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final quote = ratedQuotes[ratedQuotes.length - 1 - index];
                  final rating = _quoteRatings[quote.id]!;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$rating',
                              style: textTheme.labelSmall?.copyWith(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      title: Text(
                        quote.content,
                        style: textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '- ${quote.author}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      onTap: () {
                        setCurrentQuote(quote);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void setCurrentQuote(Quote quote) {
    setState(() { _currentQuote = quote; _animationController..reset()..forward(); });
  }

  @override
  void dispose() { _animationController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isFavorite = _currentQuote != null && _favorites.any((q) => q.id == _currentQuote!.id);
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
                    color: Theme.of(context).colorScheme.onInverseSurface,
                  ),
                  const SizedBox(width: 8),
                  const Text('Press back again to exit'),
                ],
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Quote of the Day'),
              if (_streakCount > 0) ...[
                const SizedBox(width: 12),
                Text(
                  '$_streakCount',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Add custom quote',
              icon: const Icon(Icons.add_rounded, size: 20),
              onPressed: _addCustomQuote,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
                onSelected: (v) async {
                  if (v == 'refresh') {
                    _getQuote();
                  }else if (v == 'settings') {
                  Get.to(() => SettingsPage(homeState: this));
                } else if (v == 'favorites') {
                  _showFavorites();
                } else if (v == 'history') {
                  _showQuoteHistory();
                } else if (v == 'search') {
                  Get.to(() => SearchPage(homeState: this));
                } else if (v == 'rated') {
                  _showRatedQuotes();
                } else if (v == 'about') {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Quote of the Day',
                    applicationVersion: '1.0.0',
                    applicationIcon: Icon(
                      Icons.format_quote_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                } else if (v == 'logout') {
                  await _logout();
                }
              },
              itemBuilder: (c) => [
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Refresh'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'favorites',
                  child: Row(
                    children: [
                      Icon(Icons.favorite_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Favorites'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'history',
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('History'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'search',
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Search Quotes'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'rated',
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Rated Quotes'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Settings'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'about',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('About'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 20, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 12),
                      Text('Logout', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
              ),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: MediaQuery.of(context).padding.top + 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: RepaintBoundary(
                      key: _quoteCardKey,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF404040)
                                : const Color(0xFFE5E5E5),
                            width: 1,
                          ),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF171717)
                              : Colors.white,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Builder(
                              builder: (ctx) {
                                final content = _currentQuote?.content ?? '';
                                double size = 26;
                                if (content.length > 240) {
                                  size = 16;
                                } else if (content.length > 180) {
                                  size = 18;
                                } else if (content.length > 140) {
                                  size = 20;
                                } else if (content.length > 100) {
                                  size = 22;
                                }
                                return _currentQuote != null
                                    ? Semantics(
                                  label: 'Quote text',
                                  child: Text(
                                    content,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontSize: size,
                                      height: 1.5,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                )
                                    : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.format_quote_rounded,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No quote available',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap the refresh button to get your daily inspiration',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            if (_currentQuote != null)
                              Semantics(
                                label: 'Quote author',
                                child: Text(
                                  _currentQuote!.author,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            if (_isOffline) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Offline',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                            if (_currentQuote != null) ...[
                              const SizedBox(height: 32),
                              // Minimal action buttons - icon only
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _MinimalIconButton(
                                    icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                                    isActive: isFavorite,
                                    onPressed: _toggleFavorite,
                                  ),
                                  const SizedBox(width: 16),
                                  _MinimalIconButton(
                                    icon: Icons.copy_rounded,
                                    tooltip: 'Copy quote',
                                    onPressed: _copyQuote,
                                  ),
                                  const SizedBox(width: 16),
                                  _MinimalIconButton(
                                    icon: Icons.share_rounded,
                                    tooltip: 'Share quote',
                                    onPressed: _shareQuote,
                                  ),
                                  const SizedBox(width: 16),
                                  _MinimalIconButton(
                                    icon: Icons.image_rounded,
                                    tooltip: 'Share as image',
                                    onPressed: _shareQuoteAsImage,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Minimal rating - smaller stars, no container
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  5,
                                      (i) => GestureDetector(
                                    onTap: () => _rateQuote(_currentQuote!.id, i + 1),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      child: Icon(
                                        i < (_quoteRatings[_currentQuote!.id] ?? 0)
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        size: 20,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white.withValues(alpha: i < (_quoteRatings[_currentQuote!.id] ?? 0) ? 1.0 : 0.3)
                                            : Colors.black.withValues(alpha: i < (_quoteRatings[_currentQuote!.id] ?? 0) ? 1.0 : 0.3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.8),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ),
              ),
            // export widget for high-DPI branded image capture
            Offstage(
              offstage: true, // مخفية لكن مرسومة
              child: RepaintBoundary(
                key: _exportCardKey,
                child: Material(
                  color: Colors.transparent,
                  child: _buildExportCard(context),
                ),
              ),
            ),
          ],
        ),

        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  // Branded export widget (offstage) for crisp image export with accent strip and watermark
  Widget _buildExportCard(BuildContext context) {
    final quote = _currentQuote;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.all(32),
      color: cs.surface.withValues(alpha: 0.02),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary.withValues(alpha: 0.18), cs.secondary.withValues(alpha: 0.18)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            // Acrylic overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                  ),
                ),
              ),
            ),
            // Accent bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 6, decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(6))),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.format_quote_rounded, size: 36, color: cs.primary),
                  const SizedBox(height: 12),
                  if (quote != null) ...[
                    Text(
                      quote.content,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(height: 1.3, color: cs.onSurface),
                    ),
                    const SizedBox(height: 16),
                    Text('- ${quote.author}', style: textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ] else ...[
                    Text('No quote available', style: textTheme.titleMedium),
                  ],
                  const SizedBox(height: 24),
                  // Watermark
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.auto_awesome, size: 18, color: cs.onSurface.withValues(alpha: 0.6)),
                        const SizedBox(width: 6),
                        Text('Quote of the Day', style: textTheme.labelMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                  : color.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}