// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'home.dart';
import 'login.dart';

// --- API Definitions ---
enum QuoteApiSource { zenquotes, quotegarden, apininjas, typefitLocal }

class ApiSource {
  final QuoteApiSource id;
  final String name;
  final String url;
  final String description;

  const ApiSource(this.id, this.name, this.url, this.description);
}

const List<ApiSource> availableApis = [
  ApiSource(
    QuoteApiSource.zenquotes,
    'ZenQuotes.io (Default)',
    'https://zenquotes.io/api/random',
    'Simple, widely used. May experience occasional outages/rate limits.',
  ),
  ApiSource(
    QuoteApiSource.quotegarden,
    'QuoteGarden',
    'https://quote-garden.herokuapp.com/api/v3/quotes/random',
    'Clean JSON format. Reliable secondary source.',
  ),
  ApiSource(
    QuoteApiSource.typefitLocal,
    'Local Quotes (Static File)',
    'LOCAL_TYPEFIT', // Flag for local processing in home.dart
    'Uses a large local JSON file (Type.fit) for fast, reliable, and offline quotes.',
  ),
];
// --- End API Definitions ---

class SettingsPage extends StatelessWidget {
  final HomePageState homeState;

  const SettingsPage({super.key, required this.homeState});

  Future<void> _setNotificationTime(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final savedTime = prefs.getString('notification_time') ?? '08:00';
    final initialTime = TimeOfDay(
      hour: int.parse(savedTime.split(':')[0]),
      minute: int.parse(savedTime.split(':')[1]),
    );
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (selectedTime != null) {
      final timeString = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      await prefs.setString('notification_time', timeString);
      debugPrint('Notification time set: $timeString');
      if (homeState.enableNotifications && homeState.currentQuote != null) {
        await homeState.rescheduleNotification();
      }
      if (context.mounted) {
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
                Text('Notification time set to $timeString'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatTime(BuildContext context, String hhmm) {
    try {
      final parts = hhmm.split(':');
      if (parts.length != 2) return hhmm;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return hhmm;
      final time = TimeOfDay(hour: hour, minute: minute);
      return time.format(context); 
    } catch (_) {
      return hhmm;
    }
}

Future<String> _getFormattedNotificationTime(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final timeString = prefs.getString('notification_time') ?? '08:00';
  
  // Use the existing _formatTime helper (which you need to ensure is present 
  // in SettingsPage, as provided in the last response)
  return _formatTime(context, timeString);
}

  // Future<void> _testNotification(BuildContext context) async {
  //   try {
  //     const androidDetails = AndroidNotificationDetails(
  //       'quote_channel',
  //       'Quote of the Day',
  //       importance: Importance.high,
  //       priority: Priority.high,
  //       styleInformation: BigTextStyleInformation(''),
  //       showWhen: true,
  //     );
  //     const platformDetails = NotificationDetails(android: androidDetails);

  //     final now = tz.TZDateTime.now(tz.local);
  //     final scheduledTime = now.add(const Duration(seconds: 10));
  //     final quote = homeState.currentQuote;
  //     final notificationText = quote != null
  //         ? '${quote.content}\n- ${quote.author}'
  //         : 'Test notification: No quote available';

  //     final status = await Permission.scheduleExactAlarm.request();
  //     debugPrint('Exact alarm permission status: $status');
  //     if (status.isPermanentlyDenied) {
  //       if (context.mounted) {
  //         await showDialog(
  //           context: context,
  //           builder: (context) => AlertDialog(
  //             title: const Text('Permission Required'),
  //             content: const Text('Please enable exact alarm permission in system settings to allow precise notifications.'),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.pop(context),
  //                 child: const Text('Cancel'),
  //               ),
  //               TextButton(
  //                 onPressed: () async {
  //                   Navigator.pop(context);
  //                   await openAppSettings();
  //                 },
  //                 child: const Text('Open Settings'),
  //               ),
  //             ],
  //           ),
  //         );
  //       }
  //       return;
  //     }

  //     bool useExact = status.isGranted;
  //     await FlutterLocalNotificationsPlugin().zonedSchedule(
  //       999,
  //       'Test Notification',
  //       notificationText,
  //       scheduledTime,
  //       platformDetails,
  //       androidScheduleMode: useExact
  //           ? AndroidScheduleMode.exactAllowWhileIdle
  //           : AndroidScheduleMode.inexactAllowWhileIdle,
  //       payload: 'test_notification',
  //     );

  //     if (context.mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Test notification scheduled (check in 10 seconds, ${useExact ? 'exact' : 'inexact'} timing)'),
  //         ),
  //       );
  //     }
  //     debugPrint('Test notification scheduled for: $scheduledTime (exact: $useExact)');
  //   } catch (e) {
  //     debugPrint('Error scheduling test notification: $e');
  //     if (context.mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Failed to schedule test notification')),
  //       );
  //     }
  //   }
  // }

  Future<void> _selectApiSource(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    // Default to 'zenquotes' if not set
    final currentApiName = prefs.getString('api_source_name') ?? QuoteApiSource.zenquotes.name;

    final selectedApi = await showDialog<ApiSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Quote API Source'),
        children: availableApis.map((api) {
          return RadioListTile<QuoteApiSource>(
            title: Text(api.name),
            subtitle: Text(api.description),
            value: api.id,
            groupValue: availableApis
                .firstWhere((e) => e.id.name == currentApiName)
                .id,
            onChanged: (v) => Navigator.pop(ctx, api),
          );
        }).toList(),
      ),
    );

    if (selectedApi != null) {
      // Call the method in HomePageState to update the API, save prefs, and fetch a new quote
      await homeState.updateApiSource(selectedApi.id.name, selectedApi.url);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 20, color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Text('API source set to ${selectedApi.name}'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    if (context.mounted) {
      Get.offAll(() => const LoginPage());
    }
  }

  Future<void> _selectThemeMode(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('theme_mode') ?? 'system';
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Theme Mode'),
        children: [
          RadioListTile<String>(
            title: const Text('System'),
            value: 'system',
            groupValue: current,
            onChanged: (v) => Navigator.pop(ctx, v),
          ),
          RadioListTile<String>(
            title: const Text('Light'),
            value: 'light',
            groupValue: current,
            onChanged: (v) => Navigator.pop(ctx, v),
          ),
          RadioListTile<String>(
            title: const Text('Dark'),
            value: 'dark',
            groupValue: current,
            onChanged: (v) => Navigator.pop(ctx, v),
          ),
        ],
      ),
    );
    if (selected == null) return;
    await prefs.setString('theme_mode', selected);
    if (selected == 'light') {
      Get.changeThemeMode(ThemeMode.light);
    } else if (selected == 'dark') {
      Get.changeThemeMode(ThemeMode.dark);
    } else {
      Get.changeThemeMode(ThemeMode.system);
    }
  }

  Future<void> _exportData(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'quote': prefs.getString('quote'),
      'quote_history': prefs.getString('quote_history'),
      'favorites': prefs.getString('favorites'),
      'quote_ratings': prefs.getString('quote_ratings'),
      'enable_notifications': prefs.getBool('enable_notifications'),
      'notification_time': prefs.getString('notification_time'),
      'streak_count': prefs.getInt('streak_count'),
      'last_opened': prefs.getString('last_opened'),
      'theme_mode': prefs.getString('theme_mode'),
      'is_logged_in': prefs.getBool('is_logged_in'),
      'username': prefs.getString('username'),
      'api_source_name': prefs.getString('api_source_name'), // Export new API setting
      'api_source_url': prefs.getString('api_source_url'),   // Export new API setting
    };
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/quotes_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    await Share.shareXFiles([XFile(file.path)], text: 'Quote App backup');
  }

  Future<void> _importData(BuildContext context) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.single.path;
    if (path == null) return;
    try {
      final text = await File(path).readAsString();
      final map = jsonDecode(text) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      for (final entry in map.entries) {
        final k = entry.key;
        final v = entry.value;
        if (v == null) {
          await prefs.remove(k);
        } else if (v is String) {
          await prefs.setString(k, v);
        } else if (v is bool) {
          await prefs.setBool(k, v);
        } else if (v is int) {
          await prefs.setInt(k, v);
        } else {
          await prefs.setString(k, jsonEncode(v));
        }
      }
      if (context.mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                const Text('Data imported successfully. Restart app to apply changes.'),
              ],
            ),
            backgroundColor: colorScheme.primaryContainer,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 20,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                const Text('Failed to import data. Please check the file format.'),
              ],
            ),
            backgroundColor: colorScheme.errorContainer,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _clearUserData(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        icon: Icon(
          Icons.warning_amber_rounded,
          size: 48,
          color: colorScheme.error,
        ),
        title: const Text('Clear All Data?'),
        content: const Text(
          'This action cannot be undone. All your quotes history, favorites, ratings, and cached data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('quote');
    await prefs.remove('quote_history');
    await prefs.remove('favorites');
    await prefs.remove('quote_ratings');
    await prefs.remove('streak_count');
    await prefs.remove('last_opened');
    await prefs.remove('api_source_name');
    await prefs.remove('api_source_url');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 20,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              const Text('All data cleared successfully'),
            ],
          ),
          backgroundColor: colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // --- New: API Source Section ---
          _SettingsSection(
            title: 'Quote Source',
            icon: Icons.cloud_queue_rounded,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: .1),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.api_rounded,
                      color: colorScheme.onTertiaryContainer,
                      size: 20,
                    ),
                  ),
                  title: const Text('Select Quote API'),
                  subtitle: FutureBuilder<String>(
                    future: SharedPreferences.getInstance().then(
                      // Default to zenquotes name
                      (prefs) => prefs.getString('api_source_name') ?? QuoteApiSource.zenquotes.name,
                    ),
                    builder: (context, snapshot) {
                      final currentId = snapshot.data ?? QuoteApiSource.zenquotes.name;
                      final currentApi = availableApis.firstWhere(
                            (api) => api.id.name == currentId,
                        orElse: () => availableApis.first,
                      );
                      return Text(
                        'Currently using ${currentApi.name}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: .6),
                        ),
                      );
                    },
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurface.withValues(alpha: .4),
                  ),
                  onTap: () => _selectApiSource(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // --- End API Source Section ---

          // Notifications Section
          _SettingsSection(
            title: 'Notifications',
            icon: Icons.notifications_outlined,
            children: [
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: .1),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.access_time_rounded,
                      color: colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  title: const Text('Notification Time'), // More descriptive title
                  subtitle: FutureBuilder<String>(
                    // Use the clean, dedicated function
                    future: _getFormattedNotificationTime(context), 
                    builder: (context, snapshot) {
                      // Show loading indicator or default value while waiting
                      final timeText = snapshot.data ?? 'Loading...'; 
                      
                      return Text(
                        // Use the formatted string directly
                        'Quote scheduled for $timeText',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: .6),
                        ),
                      );
                    },
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurface.withValues(alpha: .4),
                  ),
                  onTap: () => _setNotificationTime(context),
                ),
              ),
              const SizedBox(height: 12),
              // Card(
              //   elevation: 0,
              //   shape: RoundedRectangleBorder(
              //     borderRadius: BorderRadius.circular(16),
              //     side: BorderSide(
              //       color: colorScheme.outline.withValues(alpha: .1),
              //     ),
              //   ),
              //   child: ListTile(
              //     leading: Container(
              //       padding: const EdgeInsets.all(8),
              //       decoration: BoxDecoration(
              //         color: colorScheme.secondaryContainer,
              //         borderRadius: BorderRadius.circular(10),
              //       ),
              //       child: Icon(
              //         Icons.notifications_active_rounded,
              //         color: colorScheme.onSecondaryContainer,
              //         size: 20,
              //       ),
              //     ),
              //     title: const Text('Test Notification'),
              //     subtitle: Text(
              //       'Send a test notification in 10 seconds',
              //       style: textTheme.bodySmall?.copyWith(
              //         color: colorScheme.onSurface.withValues(alpha: .6),
              //       ),
              //     ),
              //     trailing: Icon(
              //       Icons.chevron_right_rounded,
              //       color: colorScheme.onSurface.withValues(alpha: .4),
              //     ),
              //     onTap: () => _testNotification(context),
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 32),
          // Appearance Section
          _SettingsSection(
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: .1),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.brightness_6_rounded,
                      color: colorScheme.onTertiaryContainer,
                      size: 20,
                    ),
                  ),
                  title: const Text('Theme Mode'),
                  subtitle: FutureBuilder<String>(
                    future: SharedPreferences.getInstance().then(
                      (prefs) => prefs.getString('theme_mode') ?? 'system',
                    ),
                    builder: (context, snapshot) {
                      final mode = snapshot.data ?? 'system';
                      final modeText = mode == 'system'
                          ? 'Follow system'
                          : mode == 'light'
                              ? 'Light mode'
                              : 'Dark mode';
                      return Text(
                        modeText,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: .6),
                        ),
                      );
                    },
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurface.withValues(alpha: .4),
                  ),
                  onTap: () => _selectThemeMode(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Data Management Section
          _SettingsSection(
            title: 'Data Management',
            icon: Icons.storage_outlined,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: .1),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.backup_rounded,
                      color: colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  title: const Text('Export Data'),
                  subtitle: Text(
                    'Backup all quotes, favorites, and settings',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: .6),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurface.withValues(alpha: .4),
                  ),
                  onTap: () => _exportData(context),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: .1),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.restore_rounded,
                      color: colorScheme.onSecondaryContainer,
                      size: 20,
                    ),
                  ),
                  title: const Text('Import Data'),
                  subtitle: Text(
                    'Restore from a backup JSON file',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: .6),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurface.withValues(alpha: .4),
                  ),
                  onTap: () => _importData(context),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.error.withValues(alpha: .3),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: colorScheme.onErrorContainer,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Clear All Data',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Remove history, favorites, ratings, and cache',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: .6),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.error,
                  ),
                  onTap: () => _clearUserData(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Account Section
          _SettingsSection(
            title: 'Account',
            icon: Icons.person_outline_rounded,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.error.withValues(alpha: .3),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: colorScheme.onErrorContainer,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Sign Out',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Log out of your account',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: .7),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.error,
                  ),
                  onTap: () => _logout(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // App Info
          Center(
            child: Text(
              'Propelex v1.0.0',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: .7),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}


class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}