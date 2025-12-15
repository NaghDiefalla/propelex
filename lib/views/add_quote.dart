import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home.dart';

class AddQuotePage extends StatefulWidget {
  final HomePageState homeState;

  const AddQuotePage({super.key, required this.homeState});

  @override
  AddQuotePageState createState() => AddQuotePageState();
}

class AddQuotePageState extends State<AddQuotePage> {
  final TextEditingController quoteController = TextEditingController(); 
  final TextEditingController authorController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;

  Future<void> _attemptSaveQuote() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (mounted) setState(() => _isSaving = true);
    
    final newQuote = Quote(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: quoteController.text.trim(),
      author: authorController.text.trim().isEmpty 
          ? 'Anonymous' 
          : authorController.text.trim().replaceAll(RegExp(r'\s+'), ' '),
    );

    await widget.homeState.addCustomQuote(newQuote); 

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text('Custom quote added successfully!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                  child: Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 32,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Add Custom Quote',
                                  style: textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            TextFormField(
                              controller: quoteController,
                              decoration: InputDecoration(
                                labelText: 'Quote Content',
                                hintText: 'Enter the quote content',
                                prefixIcon: const Icon(Icons.format_quote_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                alignLabelWithHint: true,
                              ),
                              maxLines: 5,
                              minLines: 3,
                              keyboardType: TextInputType.multiline,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Quote content cannot be empty';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            TextFormField(
                              controller: authorController,
                              decoration: InputDecoration(
                                labelText: 'Author',
                                hintText: 'Enter the author name (optional)',
                                prefixIcon: const Icon(Icons.person_outline_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 40),

                            SizedBox(
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _attemptSaveQuote,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                      )
                                    : const Text('Save Quote', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Don't want to save?", style: textTheme.bodyMedium),
                                TextButton(
                                  onPressed: _isSaving ? null : () => Get.back(), 
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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