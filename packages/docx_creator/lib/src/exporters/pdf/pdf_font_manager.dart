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

  /// Average character width as fraction of font size (approximate for Helvetica)
  static const double avgCharWidth = 0.5;

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

  /// Measures the width of text in points.
  double measureText(String text, double fontSize) {
    // Simple approximation: each character is avgCharWidth * fontSize
    // More accurate would use actual glyph metrics
    return text.length * fontSize * avgCharWidth;
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
