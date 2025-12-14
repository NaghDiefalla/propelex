// lib/views/history.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home.dart'; // Import to access Quote class and HomePageState

class HistoryPage extends StatefulWidget {
  final HomePageState homeState;

  const HistoryPage({super.key, required this.homeState});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // Local list to hold and display history (reversed for newest first)
  List<Quote> _history = [];

  @override
  void initState() {
    super.initState();
    _history = List.from(widget.homeState.quoteHistory.reversed);
  }

  void _removeHistoryItem(Quote quote) async {
    // 1. Update the main Home State (which updates shared_prefs and removes rating)
    await widget.homeState.removeHistoryItem(quote.id);
    
    // 2. Update local state for UI refresh
    setState(() {
      _history.removeWhere((q) => q.id == quote.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Refresh local list just in case it was modified on the home screen
    _history = List.from(widget.homeState.quoteHistory.reversed);
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle background gradient (Consistent Design)
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
            
            // Main Content
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Header (Back button + Title) ---
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () => Get.back(),
                            tooltip: 'Back',
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Quote History',
                            style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onBackground,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // --- List View Content ---
                      Expanded(
                        child: _history.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.history_rounded,
                                      size: 64,
                                      color: colorScheme.primary.withOpacity(0.6),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Your history is empty',
                                      style: textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'New quotes you fetch will be added here.',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _history.length,
                                itemBuilder: (context, index) {
                                  final quote = _history[index];
                                  final rating = widget.homeState.quoteRatings[quote.id];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      title: Text(quote.content, maxLines: 3, overflow: TextOverflow.ellipsis),
                                      subtitle: Text(quote.author, style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                                      leading: rating != null 
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.star_rounded, 
                                                  color: Colors.amber, 
                                                  size: 20
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$rating', 
                                                  style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                                                ),
                                              ],
                                            )
                                          : null,
                                      trailing: IconButton(
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          color: colorScheme.error,
                                        ),
                                        onPressed: () => _removeHistoryItem(quote),
                                        tooltip: 'Remove from history',
                                      ),
                                      onTap: () {
                                        widget.homeState.setCurrentQuote(quote);
                                        Get.back();
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
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