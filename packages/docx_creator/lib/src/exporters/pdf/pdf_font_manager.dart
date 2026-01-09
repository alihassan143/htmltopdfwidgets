import 'dart:typed_data';

import 'ttf_parser.dart';

/// Represents an embedded TrueType font.
class EmbeddedFont {
  final String name;
  final Uint8List ttfData;
  final TtfParser metrics;
  final String fontRef;

  EmbeddedFont({
    required this.name,
    required this.ttfData,
    required this.metrics,
    required this.fontRef,
  });

  /// Gets width of a character in font units (scaled to 1000).
  int getCharWidth(int unicode) {
    return (metrics.getCharWidth(unicode) * 1000.0 / metrics.unitsPerEm)
        .round();
  }

  /// Measures text width in points.
  double measureText(String text, double fontSize) {
    var width = 0.0;
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      final charWidth = getCharWidth(code);
      width += charWidth * fontSize / 1000.0;
    }
    return width;
  }
}

/// Manages font resources and text encoding for PDF export.
///
/// Handles WinAnsi encoding, font selection, and embedded fonts.
class PdfFontManager {
  /// Standard PDF Type1 fonts
  static const String helvetica = 'Helvetica';
  static const String helveticaBold = 'Helvetica-Bold';
  static const String helveticaOblique = 'Helvetica-Oblique';
  static const String courier = 'Courier';

  /// Font references used in content streams
  static const String fontRegular = '/F1';
  static const String fontBold = '/F2';
  static const String fontItalic = '/F3';
  static const String fontMono = '/F4';

  /// Average character width as fraction of font size (fallback for unknown chars)
  static const double avgCharWidth = 0.5;

  /// Helvetica character widths as fraction of font size (1000 units = 1.0)
  /// Based on standard Helvetica font metrics
  static const Map<int, double> _charWidths = {
    // Space and punctuation
    32: 0.278, // space
    33: 0.278, // !
    34: 0.355, // "
    35: 0.556, // #
    36: 0.556, // $
    37: 0.889, // %
    38: 0.667, // &
    39: 0.191, // '
    40: 0.333, // (
    41: 0.333, // )
    42: 0.389, // *
    43: 0.584, // +
    44: 0.278, // ,
    45: 0.333, // -
    46: 0.278, // .
    47: 0.278, // /
    // Numbers
    48: 0.556, // 0
    49: 0.556, // 1
    50: 0.556, // 2
    51: 0.556, // 3
    52: 0.556, // 4
    53: 0.556, // 5
    54: 0.556, // 6
    55: 0.556, // 7
    56: 0.556, // 8
    57: 0.556, // 9
    // Punctuation continued
    58: 0.278, // :
    59: 0.278, // ;
    60: 0.584, // <
    61: 0.584, // =
    62: 0.584, // >
    63: 0.556, // ?
    64: 1.015, // @
    // Uppercase letters
    65: 0.667, // A
    66: 0.667, // B
    67: 0.722, // C
    68: 0.722, // D
    69: 0.667, // E
    70: 0.611, // F
    71: 0.778, // G
    72: 0.722, // H
    73: 0.278, // I
    74: 0.500, // J
    75: 0.667, // K
    76: 0.556, // L
    77: 0.833, // M
    78: 0.722, // N
    79: 0.778, // O
    80: 0.667, // P
    81: 0.778, // Q
    82: 0.722, // R
    83: 0.667, // S
    84: 0.611, // T
    85: 0.722, // U
    86: 0.667, // V
    87: 0.944, // W
    88: 0.667, // X
    89: 0.667, // Y
    90: 0.611, // Z
    // Brackets and symbols
    91: 0.278, // [
    92: 0.278, // \
    93: 0.278, // ]
    94: 0.469, // ^
    95: 0.556, // _
    96: 0.333, // `
    // Lowercase letters
    97: 0.556, // a
    98: 0.556, // b
    99: 0.500, // c
    100: 0.556, // d
    101: 0.556, // e
    102: 0.278, // f
    103: 0.556, // g
    104: 0.556, // h
    105: 0.222, // i
    106: 0.222, // j
    107: 0.500, // k
    108: 0.222, // l
    109: 0.833, // m
    110: 0.556, // n
    111: 0.556, // o
    112: 0.556, // p
    113: 0.556, // q
    114: 0.333, // r
    115: 0.500, // s
    116: 0.278, // t
    117: 0.556, // u
    118: 0.500, // v
    119: 0.722, // w
    120: 0.500, // x
    121: 0.500, // y
    122: 0.500, // z
    123: 0.334, // {
    124: 0.260, // |
    125: 0.334, // }
    126: 0.584, // ~
  };

  /// Helvetica-Bold character widths as fraction of font size (1000 units = 1.0)
  /// These are noticeably wider than regular Helvetica
  static const Map<int, double> _charWidthsBold = {
    // Space and punctuation
    32: 0.278, // space
    33: 0.333, // !
    34: 0.474, // "
    35: 0.556, // #
    36: 0.556, // $
    37: 0.889, // %
    38: 0.722, // &
    39: 0.238, // '
    40: 0.333, // (
    41: 0.333, // )
    42: 0.389, // *
    43: 0.584, // +
    44: 0.278, // ,
    45: 0.333, // -
    46: 0.278, // .
    47: 0.278, // /
    // Numbers
    48: 0.556, // 0
    49: 0.556, // 1
    50: 0.556, // 2
    51: 0.556, // 3
    52: 0.556, // 4
    53: 0.556, // 5
    54: 0.556, // 6
    55: 0.556, // 7
    56: 0.556, // 8
    57: 0.556, // 9
    // Punctuation continued
    58: 0.333, // :
    59: 0.333, // ;
    60: 0.584, // <
    61: 0.584, // =
    62: 0.584, // >
    63: 0.611, // ?
    64: 0.975, // @
    // Uppercase letters - significantly wider in bold
    65: 0.722, // A
    66: 0.722, // B
    67: 0.722, // C
    68: 0.722, // D
    69: 0.667, // E
    70: 0.611, // F
    71: 0.778, // G
    72: 0.722, // H
    73: 0.278, // I
    74: 0.556, // J
    75: 0.722, // K
    76: 0.611, // L
    77: 0.833, // M
    78: 0.722, // N
    79: 0.778, // O
    80: 0.667, // P
    81: 0.778, // Q
    82: 0.722, // R
    83: 0.667, // S
    84: 0.611, // T
    85: 0.722, // U
    86: 0.667, // V
    87: 0.944, // W
    88: 0.667, // X
    89: 0.667, // Y
    90: 0.611, // Z
    // Brackets and symbols
    91: 0.333, // [
    92: 0.278, // \
    93: 0.333, // ]
    94: 0.584, // ^
    95: 0.556, // _
    96: 0.333, // `
    // Lowercase letters - also wider in bold
    97: 0.556, // a
    98: 0.611, // b
    99: 0.556, // c
    100: 0.611, // d
    101: 0.556, // e
    102: 0.333, // f
    103: 0.611, // g
    104: 0.611, // h
    105: 0.278, // i
    106: 0.278, // j
    107: 0.556, // k
    108: 0.278, // l
    109: 0.889, // m
    110: 0.611, // n
    111: 0.611, // o
    112: 0.611, // p
    113: 0.611, // q
    114: 0.389, // r
    115: 0.556, // s
    116: 0.333, // t
    117: 0.611, // u
    118: 0.556, // v
    119: 0.778, // w
    120: 0.556, // x
    121: 0.556, // y
    122: 0.500, // z
    123: 0.389, // {
    124: 0.280, // |
    125: 0.389, // }
    126: 0.584, // ~
  };

  /// Bold font width scaling factor - no longer needed with separate table
  @Deprecated('Use _charWidthsBold instead')
  static const double boldWidthFactor = 1.05;

  /// Embedded fonts
  final List<EmbeddedFont> _embeddedFonts = [];

  /// Gets the list of embedded fonts.
  List<EmbeddedFont> get embeddedFonts => List.unmodifiable(_embeddedFonts);

  /// Embeds a TrueType font and returns its font reference.
  String embedFont(String name, Uint8List ttfData) {
    // Check if already embedded
    for (final font in _embeddedFonts) {
      if (font.name == name) return font.fontRef;
    }

    final parser = TtfParser(ttfData)..parse();
    final fontRef = '/F${5 + _embeddedFonts.length}';
    _embeddedFonts.add(EmbeddedFont(
      name: name,
      ttfData: ttfData,
      metrics: parser,
      fontRef: fontRef,
    ));
    return fontRef;
  }

  /// Gets an embedded font by its reference.
  EmbeddedFont? getEmbeddedFont(String fontRef) {
    for (final font in _embeddedFonts) {
      if (font.fontRef == fontRef) return font;
    }
    return null;
  }

  /// Selects the appropriate font reference based on text properties.
  String selectFont({
    bool isBold = false,
    bool isItalic = false,
    bool isMono = false,
    String? fontFamily,
  }) {
    // Check for embedded font by family name
    if (fontFamily != null) {
      for (final font in _embeddedFonts) {
        if (font.name == fontFamily) return font.fontRef;
      }
    }

    if (isMono) return fontMono;
    if (isBold && isItalic) return fontBold; // No bold-italic in standard set
    if (isBold) return fontBold;
    if (isItalic) return fontItalic;
    return fontRegular;
  }

  /// Measures the width of text in points using per-character widths.
  /// [isBold] uses Helvetica-Bold width table for accurate measurement.
  /// [fontRef] uses embedded font metrics if available.
  double measureText(String text, double fontSize,
      {bool isBold = false, String? fontRef}) {
    // Use embedded font metrics if available
    if (fontRef != null) {
      final embedded = getEmbeddedFont(fontRef);
      if (embedded != null) {
        return embedded.measureText(text, fontSize);
      }
    }

    // Select appropriate width table
    final widths = isBold ? _charWidthsBold : _charWidths;

    var width = 0.0;
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      // Use character-specific width or fallback to average
      final charWidth = widths[code] ?? avgCharWidth;
      width += charWidth * fontSize;
    }
    return width;
  }

  /// Escapes text for PDF string literals using WinAnsi encoding.
  ///
  /// Handles special characters and converts Unicode where possible.
  String escapeText(String text) {
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      final code = char.codeUnitAt(0);

      // Handle special PDF characters
      switch (char) {
        case '\\':
          buffer.write('\\\\');
          break;
        case '(':
          buffer.write('\\(');
          break;
        case ')':
          buffer.write('\\)');
          break;
        default:
          // Check for common Unicode -> WinAnsi mappings
          final winAnsi = _unicodeToWinAnsi(code);
          if (winAnsi != null) {
            buffer.write('\\${winAnsi.toRadixString(8).padLeft(3, '0')}');
          } else if (code >= 32 && code <= 126) {
            // Standard ASCII printable
            buffer.write(char);
          } else if (code >= 128 && code <= 255) {
            // Extended ASCII (WinAnsi range)
            buffer.write('\\${code.toRadixString(8).padLeft(3, '0')}');
          } else {
            // Skip unsupported characters silently
          }
      }
    }

    return buffer.toString();
  }

  /// Escapes text as hex string for embedded fonts (UTF-16BE).
  String escapeTextHex(String text) {
    final sb = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      sb.write(code.toRadixString(16).padLeft(4, '0').toUpperCase());
    }
    return sb.toString();
  }

  /// Maps common Unicode code points to WinAnsi octal codes.
  int? _unicodeToWinAnsi(int unicode) {
    const mapping = <int, int>{
      0x2022: 0x95, // • Bullet
      0x2013: 0x96, // – En dash
      0x2014: 0x97, // — Em dash
      0x2018: 0x91, // ' Left single quote
      0x2019: 0x92, // ' Right single quote
      0x201C: 0x93, // " Left double quote
      0x201D: 0x94, // " Right double quote
      0x2026: 0x85, // … Ellipsis
      0x20AC: 0x80, // € Euro
      0x2122: 0x99, // ™ Trademark
      0x00A9: 0xA9, // © Copyright
      0x00AE: 0xAE, // ® Registered
    };
    return mapping[unicode];
  }
}
