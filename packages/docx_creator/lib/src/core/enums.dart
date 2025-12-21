/// Style and formatting enums/classes for `docx_ai_creator`.
library;

// ============================================================
// TEXT & PARAGRAPH ALIGNMENT
// ============================================================

/// Text alignment within a paragraph or table cell.
enum DocxAlign { left, center, right, justify }

// ============================================================
// COLOR (Flexible Class)
// ============================================================

/// A color value for text, backgrounds, and borders.
///
/// ## Predefined Colors
/// ```dart
/// DocxText('Red', color: DocxColor.red)
/// DocxText('Blue', color: DocxColor.blue)
/// ```
///
/// ## Custom Hex Colors
/// ```dart
/// DocxText('Brand', color: DocxColor('#4285F4'))
/// DocxText('Custom', color: DocxColor('FF5722'))
/// ```
class DocxColor {
  /// The hex color value (without #).
  final String hex;

  /// Private const constructor for predefined colors.
  const DocxColor._(this.hex);

  /// Creates a color from a hex string.
  ///
  /// Accepts formats: 'RRGGBB', '#RRGGBB', '0xRRGGBB'
  factory DocxColor(String value) {
    String hex = value.toUpperCase();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.startsWith('0X')) hex = hex.substring(2);
    return DocxColor._(hex);
  }

  /// Creates a color from a hex string, removing # or 0x prefix.
  factory DocxColor.fromHex(String value) => DocxColor(value);

  // Predefined colors
  static const black = DocxColor._('000000');
  static const white = DocxColor._('FFFFFF');
  static const red = DocxColor._('FF0000');
  static const blue = DocxColor._('0000FF');
  static const green = DocxColor._('00FF00');
  static const yellow = DocxColor._('FFFF00');
  static const orange = DocxColor._('FFA500');
  static const purple = DocxColor._('800080');
  static const gray = DocxColor._('808080');
  static const lightGray = DocxColor._('D3D3D3');
  static const darkGray = DocxColor._('404040');
  static const cyan = DocxColor._('00FFFF');
  static const magenta = DocxColor._('FF00FF');
  static const pink = DocxColor._('FFC0CB');
  static const brown = DocxColor._('8B4513');
  static const navy = DocxColor._('000080');
  static const teal = DocxColor._('008080');
  static const lime = DocxColor._('32CD32');
  static const gold = DocxColor._('FFD700');
  static const silver = DocxColor._('C0C0C0');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DocxColor && hex == other.hex;

  @override
  int get hashCode => hex.hashCode;

  @override
  String toString() => 'DocxColor($hex)';
}

// ============================================================
// BORDERS
// ============================================================

/// Border styles for tables, paragraphs, and sections.
enum DocxBorder { none, single, double, dashed, dotted, thick, triple }

extension DocxBorderExtension on DocxBorder {
  String get xmlValue {
    switch (this) {
      case DocxBorder.none:
        return 'nil';
      case DocxBorder.single:
        return 'single';
      case DocxBorder.double:
        return 'double';
      case DocxBorder.dashed:
        return 'dashed';
      case DocxBorder.dotted:
        return 'dotted';
      case DocxBorder.thick:
        return 'thick';
      case DocxBorder.triple:
        return 'triple';
    }
  }
}

// ============================================================
// FONT STYLING
// ============================================================

enum DocxFontWeight { normal, bold }

enum DocxFontStyle { normal, italic }

enum DocxTextDecoration { none, underline, strikethrough }

/// Highlight (background) colors for text.
enum DocxHighlight {
  none,
  yellow,
  green,
  cyan,
  magenta,
  blue,
  red,
  darkBlue,
  darkCyan,
  darkGreen,
  darkMagenta,
  darkRed,
  darkYellow,
  darkGray,
  lightGray,
  black,
}

// ============================================================
// PAGE & SECTION
// ============================================================

enum DocxPageOrientation { portrait, landscape }

enum DocxPageSize { letter, a4, legal, tabloid, custom }

enum DocxSectionBreak { continuous, nextPage, evenPage, oddPage }

// ============================================================
// TABLE-SPECIFIC
// ============================================================

enum DocxVerticalAlign { top, center, bottom }

enum DocxWidthType { auto, dxa, pct }

// ============================================================
// HEADING LEVELS
// ============================================================

enum DocxHeadingLevel { h1, h2, h3, h4, h5, h6 }

extension DocxHeadingLevelExtension on DocxHeadingLevel {
  String get styleId => 'Heading${index + 1}';

  double get defaultFontSize {
    switch (this) {
      case DocxHeadingLevel.h1:
        return 24;
      case DocxHeadingLevel.h2:
        return 20;
      case DocxHeadingLevel.h3:
        return 16;
      case DocxHeadingLevel.h4:
        return 14;
      case DocxHeadingLevel.h5:
        return 12;
      case DocxHeadingLevel.h6:
        return 11;
    }
  }
}
