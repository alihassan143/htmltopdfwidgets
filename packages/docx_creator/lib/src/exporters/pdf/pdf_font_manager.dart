/// Manages font resources and text encoding for PDF export.
///
/// Handles WinAnsi encoding and font selection.
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

  /// Bold font width scaling factor (Helvetica-Bold is ~5% wider than regular)
  static const double boldWidthFactor = 1.05;

  /// Selects the appropriate font reference based on text properties.
  String selectFont({
    bool isBold = false,
    bool isItalic = false,
    bool isMono = false,
  }) {
    if (isMono) return fontMono;
    if (isBold && isItalic) return fontBold; // No bold-italic in standard set
    if (isBold) return fontBold;
    if (isItalic) return fontItalic;
    return fontRegular;
  }

  /// Measures the width of text in points using per-character widths.
  /// [isBold] applies a width scaling factor for bold fonts.
  double measureText(String text, double fontSize, {bool isBold = false}) {
    var width = 0.0;
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      // Use character-specific width or fallback to average
      final charWidth = _charWidths[code] ?? avgCharWidth;
      width += charWidth * fontSize;
    }
    // Apply bold scaling if needed
    if (isBold) {
      width *= boldWidthFactor;
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
