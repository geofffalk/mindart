enum AppVisualTheme {
  blueNeon,
  sketchbook,
  pencil,
  childlike;

  String get displayName {
    switch (this) {
      case AppVisualTheme.blueNeon:
        return 'Blue Neon';
      case AppVisualTheme.sketchbook:
        return 'Sketchbook';
      case AppVisualTheme.pencil:
        return 'Pencil';
      case AppVisualTheme.childlike:
        return 'Childlike';
    }
  }
}
