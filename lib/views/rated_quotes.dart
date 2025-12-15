import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home.dart';

class RatedQuotesPage extends StatefulWidget {
  final HomePageState homeState;

  const RatedQuotesPage({super.key, required this.homeState});

  @override
  State<RatedQuotesPage> createState() => _RatedQuotesPageState();
}

class _RatedQuotesPageState extends State<RatedQuotesPage> {
  List<Quote> _ratedQuotes = [];

  @override
  void initState() {
    super.initState();
    _filterRatedQuotes();
  }

  void _filterRatedQuotes() {
    final ratings = widget.homeState.quoteRatings;
    _ratedQuotes = widget.homeState.quoteHistory
        .where((q) => ratings.containsKey(q.id) && ratings[q.id]! > 0)
        .toList()
        .reversed
        .toList();
  }

  void _unrateQuote(Quote quote) async {
    await widget.homeState.rateQuote(quote.id, 0); 
    
    setState(() {
      _filterRatedQuotes();
    });
  }
  
  Widget _buildRatingStars(int rating, Color color, ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded, 
          color: color, 
          size: 20
        ),
        const SizedBox(width: 4),
        Text(
          '$rating', 
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    _filterRatedQuotes();

    return Scaffold(
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
                  padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () => Get.back(),
                            tooltip: 'Back',
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Rated Quotes',
                            style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onBackground,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Expanded(
                        child: _ratedQuotes.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.star_border_rounded,
                                      size: 64,
                                      color: colorScheme.primary.withOpacity(0.6),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No quotes rated yet',
                                      style: textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Rate quotes on the home screen to see them here.',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _ratedQuotes.length,
                                itemBuilder: (context, index) {
                                  final quote = _ratedQuotes[index];
                                  final rating = widget.homeState.quoteRatings[quote.id] ?? 0;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      title: Text(quote.content, maxLines: 3, overflow: TextOverflow.ellipsis),
                                      subtitle: Text(quote.author, style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                                      leading: _buildRatingStars(rating, Colors.amber, colorScheme, textTheme),
                                      trailing: IconButton(
                                        icon: Icon(
                                          Icons.clear_rounded,
                                          color: colorScheme.error,
                                        ),
                                        onPressed: () => _unrateQuote(quote),
                                        tooltip: 'Remove rating',
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