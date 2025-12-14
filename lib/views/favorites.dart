// lib/views/favorites.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home.dart'; // Import to access Quote class and HomePageState

class FavoritesPage extends StatefulWidget {
  final HomePageState homeState;

  const FavoritesPage({super.key, required this.homeState});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  // Local list to hold and display favorites
  List<Quote> _favorites = [];

  @override
  void initState() {
    super.initState();
    // Initialize local list from main state
    _favorites = List.from(widget.homeState.favorites);
  }

  void _removeFavorite(Quote quote) async {
    // 1. Update the main Home State (which updates shared_prefs and triggers Home page rebuild if necessary)
    await widget.homeState.removeFavorite(quote.id);
    
    // 2. Update local state for UI refresh
    setState(() {
      _favorites.removeWhere((q) => q.id == quote.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Refresh local list just in case it was modified on the home screen
    _favorites = List.from(widget.homeState.favorites); 

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
                            'Favorite Quotes',
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
                        child: _favorites.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.favorite_border_rounded,
                                      size: 64,
                                      color: colorScheme.primary.withOpacity(0.6),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No favorites yet',
                                      style: textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap the heart icon on a quote to save it here.',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _favorites.length,
                                itemBuilder: (context, index) {
                                  final quote = _favorites[index];
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
                                        onPressed: () => _removeFavorite(quote),
                                        tooltip: 'Remove from favorites',
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