import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// MindArt 2026 Theme Configuration
/// Dark, calming, meditational aesthetic with proper contrast
class AppTheme {
  AppTheme._();

  // ============================================
  // 2026 Dark Palette - Calm, Readable
  // ============================================
  
  // Backgrounds - Deep dark blues
  static const Color background = Color(0xFF0F1419);      // Deep dark
  static const Color surface = Color(0xFF1A2332);         // Dark surface
  static const Color card = Color(0xFF1E293B);            // Card dark
  
  // Primary - Teal/Cyan accent
  static const Color primary = Color(0xFF4FB3BF);
  static const Color primaryLight = Color(0xFF7DD3E0);
  static const Color primaryDark = Color(0xFF2D8A94);
  
  // Accent - Warm Coral
  static const Color accent = Color(0xFFE8A598);
  static const Color accentLight = Color(0xFFFFC1A8);
  
  // Text Colors - Light on dark for readability
  static const Color textPrimary = Color(0xFFF1F5F9);     // Bright white
  static const Color textSecondary = Color(0xFFCBD5E1);   // Light gray
  static const Color textTertiary = Color(0xFF94A3B8);    // Medium gray
  static const Color textOnPrimary = Color(0xFF0F1419);
  
  // Utility Colors
  static const Color divider = Color(0xFF334155);         // Subtle divider
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  
  // Legacy compatibility
  static const Color primaryMedium = Color(0xFF1E293B);
  static const Color highlight = Color(0xFFE94560);
  static const Color warmGold = Color(0xFFF7B731);
  static const Color calmBlue = Color(0xFF4FB3BF);
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
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      
      colorScheme: const ColorScheme.dark(
        primary: primary,
        primaryContainer: primaryDark,
        secondary: accent,
        secondaryContainer: accentLight,
        surface: surface,
        error: error,
        onPrimary: textOnPrimary,
        onSecondary: textOnPrimary,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      
      // AppBar - Transparent, clean
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      
      // Text Theme
      textTheme: _buildTextTheme(),
      
      // Elevated Buttons - Pill shape, sage green
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Outlined Buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primaryLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Text Buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Cards - White with soft shadow
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Icons
      iconTheme: const IconThemeData(
        color: textSecondary,
        size: 24,
      ),
      
      // FAB
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      
      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: primary,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      
      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: primaryLight.withAlpha(77),
        thumbColor: primary,
        overlayColor: primary.withAlpha(30),
        trackHeight: 4,
      ),
      
      // Divider
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      
      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      
      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: card,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      
      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================
  // Text Theme - Outfit for headers, Inter for body
  // ============================================
  
  static TextTheme _buildTextTheme() {
    return TextTheme(
      // Display - Large headlines
      displayLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.3,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      
      // Headlines
      headlineLarge: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      
      // Titles
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      
      // Body
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: textPrimary,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textSecondary,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textTertiary,
        height: 1.4,
      ),
      
      // Labels
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textTertiary,
        letterSpacing: 0.5,
      ),
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
