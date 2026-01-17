import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/visual_theme.dart';

/// MindArt 2026 Theme Configuration
/// Dark, calming, meditational aesthetic with proper contrast
class AppTheme {
  AppTheme._();

  // ============================================
  // 2026 Dark Palette - Calm, Readable
  // ============================================
  
  // ============================================
  // Themes Palettes
  // ============================================

  /// Returns the background color for a specific theme
  static Color getBackgroundColor(AppVisualTheme theme) {
    switch (theme) {
      case AppVisualTheme.blueNeon:
        return const Color(0xFF0F1419);
      case AppVisualTheme.sketchbook:
        return const Color(0xFFF7F1E3);
      case AppVisualTheme.pencil:
        return const Color(0xFFECF0F1);
      case AppVisualTheme.childlike:
        return Colors.white;
    }
  }

  /// Returns the surface color for a specific theme
  static Color getSurfaceColor(AppVisualTheme theme) {
    switch (theme) {
      case AppVisualTheme.blueNeon:
        return const Color(0xFF1A2332);
      case AppVisualTheme.sketchbook:
        return const Color(0xFFD1CCC0);
      case AppVisualTheme.pencil:
        return const Color(0xFFBDC3C7);
      case AppVisualTheme.childlike:
        return const Color(0xFFF1F5F9);
    }
  }

  /// Returns the primary color for a specific theme
  static Color getPrimaryColor(AppVisualTheme theme) {
    switch (theme) {
      case AppVisualTheme.blueNeon:
        return const Color(0xFF4FB3BF);
      case AppVisualTheme.sketchbook:
        return const Color(0xFF1E375A); // Darker Blue for "Sketchbook"
      case AppVisualTheme.pencil:
        return const Color(0xFF2C4C70); // Blue-ish Graphite for "Pencil"
      case AppVisualTheme.childlike:
        return const Color(0xFFFF4757);
    }
  }

  /// Returns the background gradient for a specific theme
  static LinearGradient getBackgroundGradient(AppVisualTheme theme) {
    switch (theme) {
      case AppVisualTheme.blueNeon:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2332), Color(0xFF0F1419)],
        );
      case AppVisualTheme.sketchbook:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFF7F1E3), const Color(0xFFE5DECF)],
        );
      case AppVisualTheme.pencil:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFECF0F1), Color(0xFFDCE1E2)],
        );
      case AppVisualTheme.childlike:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF5F6FA)],
        );
    }
  }

  // Base colors for default access (Blue Neon)
  static const Color background = Color(0xFF0F1419);
  static const Color surface = Color(0xFF1A2332);
  static const Color card = Color(0xFF1E293B);
  static const Color primary = Color(0xFF4FB3BF);
  static const Color primaryLight = Color(0xFF7DD3E0);
  static const Color primaryDark = Color(0xFF2D8A94);
  static const Color accent = Color(0xFFE8A598);
  static const Color accentLight = Color(0xFFFFC1A8);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFF0F1419);
  static const Color divider = Color(0xFF334155);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  
  // Legacy compatibility - RESTORED to fix build errors
  static const Color calmBlue = Color(0xFF4FB3BF);
  static const Color primaryMedium = Color(0xFF1E293B);
  static const Color highlight = Color(0xFFE94560);
  static const Color warmGold = Color(0xFFF7B731);
  static const Color softPurple = Color(0xFF9B59B6);

  // ============================================
  // Gradients
  // ============================================
  
  static const LinearGradient sunriseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D1B3D), Color(0xFF1E293B), Color(0xFF0F1419)],
  );
  
  static const LinearGradient sageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A3A3A), Color(0xFF1E3A5F), Color(0xFF0F1419)],
  );
  
  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A2332), Color(0xFF152638), Color(0xFF0F1419)],
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A2332), Color(0xFF0F1419)],
  );

  // ============================================
  // Theme Data
  // ============================================
  
  static ThemeData getThemeData(AppVisualTheme visualTheme) {
    final isDark = visualTheme == AppVisualTheme.blueNeon;
    final bgColor = getBackgroundColor(visualTheme);
    final surfaceColor = getSurfaceColor(visualTheme);
    final primaryColor = getPrimaryColor(visualTheme);
    final textColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF2D3436);
    final secondaryTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF636E72);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: bgColor,
      
      colorScheme: isDark 
        ? ColorScheme.dark(
            primary: primaryColor,
            surface: surfaceColor,
            onSurface: textColor,
          )
        : ColorScheme.light(
            primary: primaryColor,
            surface: surfaceColor,
            onSurface: textColor,
          ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      
      textTheme: _buildTextTheme(textColor, secondaryTextColor),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: isDark ? Colors.white : Colors.white,
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      
      cardTheme: CardThemeData(
        color: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // ============================================
  // Text Theme - Outfit for headers, Inter for body
  // ============================================
  
  static TextTheme _buildTextTheme(Color primaryText, Color secondaryText) {
    return TextTheme(
      displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: primaryText),
      displayMedium: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w600, color: primaryText),
      displaySmall: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: primaryText),
      headlineLarge: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: primaryText),
      headlineMedium: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w500, color: primaryText),
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: primaryText),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: secondaryText),
    );
  }

  // ============================================
  // Custom Styles
  // ============================================
  
  /// Handwritten style for paint screen
  static TextStyle get handwrittenStyle => GoogleFonts.caveat(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  /// Section header style
  static TextStyle get sectionHeader => GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  // ============================================
  // Shadows
  // ============================================
  
  /// Soft card shadow - 2026 style
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF000000).withAlpha(10),  // 4% black
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF000000).withAlpha(5),   // 2% black
      blurRadius: 40,
      offset: const Offset(0, 8),
    ),
  ];
  
  /// Elevated shadow for floating elements
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: const Color(0xFF000000).withAlpha(15),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];
  
  /// Subtle inset shadow
  static List<BoxShadow> get insetShadow => [
    BoxShadow(
      color: const Color(0xFF000000).withAlpha(5),
      blurRadius: 10,
      offset: const Offset(0, 2),
      spreadRadius: -2,
    ),
  ];

  // ============================================
  // Decorations
  // ============================================
  
  /// Standard card decoration with shadow
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(20),
    boxShadow: cardShadow,
  );
  
  /// Gradient card decoration
  static BoxDecoration get gradientCardDecoration => BoxDecoration(
    gradient: sageGradient,
    borderRadius: BorderRadius.circular(20),
    boxShadow: cardShadow,
  );
  
  /// Surface decoration (subtle background)
  static BoxDecoration get surfaceDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(16),
  );
  
  /// Toolbar/panel decoration
  static BoxDecoration get panelDecoration => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(16),
    boxShadow: elevatedShadow,
  );

  // ============================================
  // Animation Durations
  // ============================================
  
  static const Duration quickAnimation = Duration(milliseconds: 150);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  static const Duration breathAnimation = Duration(milliseconds: 4000);

  // ============================================
  // Spacing
  // ============================================
  
  static const double spacingXS = 4;
  static const double spacingS = 8;
  static const double spacingM = 16;
  static const double spacingL = 24;
  static const double spacingXL = 32;
  static const double spacingXXL = 48;

  // ============================================
  // Border Radius
  // ============================================
  
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusXL = 20;
  static const double radiusXXL = 24;
  static const double radiusFull = 999;
}
