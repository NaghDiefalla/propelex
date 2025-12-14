import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData _base(Color seed, Brightness brightness) {
    // Minimal shadcn-style color scheme: black, white, and grays
    final colorScheme = brightness == Brightness.dark
        ? const ColorScheme.dark(
            primary: Colors.white, // Pure white for accents
            onPrimary: Colors.black,
            primaryContainer:  Color(0xFF262626), // Neutral gray
            onPrimaryContainer: Colors.white,
            secondary:  Color(0xFF737373), // Medium gray
            onSecondary: Colors.white,
            secondaryContainer:  Color(0xFF404040),
            onSecondaryContainer: Colors.white,
            tertiary:  Color(0xFF525252), // Dark gray
            onTertiary: Colors.white,
            error:  Color(0xFFDC2626), // Red
            onError: Colors.white,
            errorContainer:  Color(0xFF7F1D1D),
            onErrorContainer:  Color(0xFFFEE2E2),
            surface: Colors.black, // Pure black
            onSurface: Colors.white, // Pure white text
            surfaceContainerHighest:  Color(0xFF171717), // Near black
            outline:  Color(0xFF404040), // Subtle border
            outlineVariant:  Color(0xFF262626),
            inverseSurface: Colors.white,
            onInverseSurface: Colors.black,
          )
        : const ColorScheme.light(
            primary: Colors.black, // Pure black for accents
            onPrimary: Colors.white,
            primaryContainer:  Color(0xFFFAFAFA), // Off-white
            onPrimaryContainer: Colors.black,
            secondary:  Color(0xFF737373), // Medium gray
            onSecondary: Colors.white,
            secondaryContainer:  Color(0xFFF5F5F5),
            onSecondaryContainer: Colors.black,
            tertiary:  Color(0xFFA3A3A3), // Light gray
            onTertiary: Colors.white,
            error:  Color(0xFFDC2626),
            onError: Colors.white,
            errorContainer:  Color(0xFFFEE2E2),
            onErrorContainer:  Color(0xFF991B1B),
            surface: Colors.white, // Pure white
            onSurface: Colors.black, // Pure black text
            surfaceContainerHighest:  Color(0xFFFAFAFA), // Off-white
            outline:  Color(0xFFE5E5E5), // Very light gray border
            outlineVariant:  Color(0xFFF5F5F5),
            inverseSurface: Colors.black,
            onInverseSurface: Colors.white,
          );

    // Enhanced typography with better hierarchy
    final textTheme = GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      displaySmall: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.3,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 18,
        height: 1.6,
        letterSpacing: 0.1,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 16,
        height: 1.6,
        letterSpacing: 0.1,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 14,
        height: 1.5,
        letterSpacing: 0.1,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.3,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: brightness == Brightness.dark 
          ? Colors.black // Pure black
          : Colors.white, // Pure white
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
        foregroundColor: colorScheme.onSurface,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(
          color: colorScheme.onSurface.withValues(alpha: 0.8),
          size: 22,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: brightness == Brightness.dark
                ? const Color(0xFF404040)
                : const Color(0xFFE5E5E5),
            width: 1,
          ),
        ),
        color: brightness == Brightness.dark
            ? const Color(0xFF171717)
            : Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? const Color(0xFF171717)
            : const Color(0xFFFAFAFA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: brightness == Brightness.dark
                ? const Color(0xFF404040)
                : const Color(0xFFE5E5E5),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: brightness == Brightness.dark
                ? const Color(0xFF404040)
                : const Color(0xFFE5E5E5),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF171717)
            : Colors.black,
        contentTextStyle: TextStyle(
          color: brightness == Brightness.dark
              ? Colors.white
              : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: brightness == Brightness.dark
                ? const Color(0xFF404040)
                : const Color(0xFF404040).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        elevation: 0,
      ),
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: 24,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brightness == Brightness.dark ? Colors.white : Colors.black,
        foregroundColor: brightness == Brightness.dark ? Colors.black : Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(
          color: colorScheme.onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        backgroundColor: colorScheme.secondaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: brightness == Brightness.dark
                ? const Color(0xFF404040)
                : const Color(0xFFE5E5E5),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dividerTheme: DividerThemeData(
        thickness: 1,
        color: brightness == Brightness.dark
            ? const Color(0xFF404040)
            : const Color(0xFFE5E5E5),
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        iconColor: colorScheme.onSurface.withValues(alpha: 0.8),
      ),
      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: brightness == Brightness.dark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          backgroundColor: brightness == Brightness.dark
              ? const Color(0xFF171717)
              : Colors.white,
          foregroundColor: colorScheme.onSurface,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: brightness == Brightness.dark ? Colors.white : Colors.black,
          foregroundColor: brightness == Brightness.dark ? Colors.black : Colors.white,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: BorderSide(
            color: brightness == Brightness.dark
                ? const Color(0xFF404040)
                : const Color(0xFFE5E5E5),
            width: 1,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  static ThemeData light = _base(Colors.black, Brightness.light);
  static ThemeData dark = _base(Colors.white, Brightness.dark);
}
