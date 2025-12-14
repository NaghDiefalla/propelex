// search.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home.dart';

class SearchPage extends StatefulWidget {
  final HomePageState homeState;

  const SearchPage({super.key, required this.homeState});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _searchQuery = '';
  int _minRating = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ratings = widget.homeState.quoteRatings;
    final filteredQuotes = widget.homeState.quoteHistory.where((quote) {
      final matchesText = quote.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          quote.author.toLowerCase().contains(_searchQuery.toLowerCase());
      final rating = ratings[quote.id] ?? 0;
      return matchesText && rating >= _minRating;
    }).toList();

    final hasResults = filteredQuotes.isNotEmpty;
    final hasQuery = _searchQuery.isNotEmpty;
    final hasFilter = _minRating > 0;

    return Scaffold(
      // ❌ AppBar Removed (Consistent Design)
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack( // Consistent Design
          children: [
            // Subtle background gradient (Identical Design)
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
            
            // Main Content: Search UI (Constrained)
            Center( // Consistent Design
              child: ConstrainedBox( // Consistent Design
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Search Bar and Filter Button (Replaces AppBar) ---
                      Row(
                        children: [
                          // Back Button
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () => Get.back(),
                            tooltip: 'Back',
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.shadow.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: 'Search quotes or authors...',
                                  hintStyle: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                  border: InputBorder.none,
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: colorScheme.primary,
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.clear_rounded,
                                            color: colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                          tooltip: 'Clear search',
                                          onPressed: () => setState(() => _searchQuery = ''),
                                        )
                                      : null,
                                ),
                                onChanged: (value) => setState(() => _searchQuery = value),
                                style: textTheme.bodyLarge,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // --- Filter Menu (Replaces AppBar.actions) ---
                          PopupMenuButton<int>(
                            icon: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.shadow.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                color: hasFilter ? colorScheme.primary : colorScheme.onSurface,
                              ),
                            ),
                            tooltip: 'Filter by rating',
                            onSelected: (value) => setState(() => _minRating = value),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 0,
                                child: Text('All Ratings'),
                              ),
                              for (var i = 1; i <= 5; i++)
                                PopupMenuItem(
                                  value: i,
                                  child: Text('$i Star${i > 1 ? 's' : ''} & Up'),
                                ),
                            ],
                          ),
                        ],
                      ),

                      // --- Filter Chip (Moved from AppBar.actions) ---
                      if (hasFilter)
                        Container(
                          margin: const EdgeInsets.only(top: 8, right: 8),
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text('$_minRating+'),
                              ],
                            ),
                            backgroundColor: colorScheme.secondaryContainer,
                            onDeleted: () => setState(() => _minRating = 0),
                            deleteIcon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 16),

                      // --- Results Count/Info ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${filteredQuotes.length} ${filteredQuotes.length == 1 ? 'quote' : 'quotes'} found',
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // --- Quotes List or Empty State ---
                      Expanded(
                        child: hasResults
                            ? ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: filteredQuotes.length,
                                separatorBuilder: (context, i) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final quote = filteredQuotes[filteredQuotes.length - 1 - index];
                                  final rating = ratings[quote.id];
                                  final isRated = rating != null && rating > 0;
                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: colorScheme.outline.withOpacity(.1),
                                      ),
                                    ),
                                    child: ListTile(
                                      title: Text(quote.content, maxLines: 3, overflow: TextOverflow.ellipsis),
                                      subtitle: Text(quote.author),
                                      trailing: isRated
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  rating.toString(),
                                                  style: textTheme.labelLarge?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: colorScheme.onSurface,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 20),
                                              ],
                                            )
                                          : null,
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 40),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        size: 64,
                                        color: colorScheme.onSurface.withOpacity(0.2),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        hasQuery || hasFilter
                                            ? 'No quotes found'
                                            : 'Search your quote history',
                                        style: textTheme.headlineSmall?.copyWith(
                                          color: colorScheme.onSurface.withOpacity(0.7),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        hasQuery || hasFilter
                                            ? 'Try adjusting your search query or rating filter'
                                            : 'Enter keywords to search through your saved quotes',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurface.withOpacity(0.5),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (hasFilter) ...[
                                        const SizedBox(height: 24),
                                        OutlinedButton.icon(
                                          onPressed: () => setState(() => _minRating = 0),
                                          icon: const Icon(Icons.clear_rounded),
                                          label: const Text('Clear rating filter'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
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