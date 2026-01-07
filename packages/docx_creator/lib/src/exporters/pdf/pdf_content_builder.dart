import 'pdf_font_manager.dart';

/// Builds PDF content streams with drawing commands.
///
/// Provides a clean API for text, graphics, and state management.
class PdfContentBuilder {
  final StringBuffer _buffer = StringBuffer();
  final PdfFontManager _fontManager = PdfFontManager();

  String _currentFont = PdfFontManager.fontRegular;
  double _currentFontSize = 12;
  String _currentColor = '0 0 0';

  /// Gets the content stream.
  String get content => _buffer.toString();

  // --- Graphics State ---

  /// Saves the current graphics state.
  void saveState() => _buffer.writeln('q');

  /// Restores the previous graphics state.
  void restoreState() => _buffer.writeln('Q');

  // --- Color ---

  /// Sets the fill color from RGB values (0-1 range).
  void setFillColor(double r, double g, double b) {
    _currentColor =
        '${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)}';
    _buffer.writeln('$_currentColor rg');
  }

  /// Sets the fill color from hex string (e.g., "FF0000").
  void setFillColorHex(String hex) {
    if (hex.length != 6) return;
    final r = int.parse(hex.substring(0, 2), radix: 16) / 255;
    final g = int.parse(hex.substring(2, 4), radix: 16) / 255;
    final b = int.parse(hex.substring(4, 6), radix: 16) / 255;
    setFillColor(r, g, b);
  }

  /// Sets the stroke color from RGB values (0-1 range).
  void setStrokeColor(double r, double g, double b) {
    _buffer.writeln(
        '${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)} RG');
  }

  /// Sets the stroke color from hex string.
  void setStrokeColorHex(String hex) {
    if (hex.length != 6) return;
    final r = int.parse(hex.substring(0, 2), radix: 16) / 255;
    final g = int.parse(hex.substring(2, 4), radix: 16) / 255;
    final b = int.parse(hex.substring(4, 6), radix: 16) / 255;
    setStrokeColor(r, g, b);
  }

  // --- Rectangles ---

  /// Draws a filled rectangle.
  void fillRect(double x, double y, double width, double height) {
    _buffer.writeln('$x $y $width $height re f');
  }

  /// Draws a stroked rectangle.
  void strokeRect(double x, double y, double width, double height,
      {double lineWidth = 0.5}) {
    _buffer.writeln('$lineWidth w');
    _buffer.writeln('$x $y $width $height re S');
  }

  /// Draws a filled and stroked rectangle.
  void fillStrokeRect(double x, double y, double width, double height,
      {double lineWidth = 0.5}) {
    _buffer.writeln('$lineWidth w');
    _buffer.writeln('$x $y $width $height re B');
  }

  // --- Lines ---

  /// Draws a line.
  void drawLine(double x1, double y1, double x2, double y2,
      {double lineWidth = 0.5}) {
    _buffer.writeln('$lineWidth w');
    _buffer.writeln('$x1 $y1 m $x2 $y2 l S');
  }

  // --- Text ---

  /// Begins a text object.
  void beginText() => _buffer.writeln('BT');

  /// Ends a text object.
  void endText() => _buffer.writeln('ET');

  /// Sets the text position using transformation matrix.
  void setTextMatrix(double x, double y) {
    _buffer.writeln('1 0 0 1 $x $y Tm');
  }

  /// Moves text position relative to current.
  void moveText(double dx, double dy) {
    _buffer.writeln('$dx $dy Td');
  }

  /// Sets the font and size.
  void setFont(String fontRef, double size) {
    _currentFont = fontRef;
    _currentFontSize = size;
    _buffer.writeln('$fontRef $size Tf');
  }

  /// Sets word spacing (for justification).
  void setWordSpacing(double spacing) {
    _buffer.writeln('${spacing.toStringAsFixed(3)} Tw');
  }

  /// Shows text.
  void showText(String text) {
    final escaped = _fontManager.escapeText(text);
    _buffer.writeln('($escaped) Tj');
  }

  /// Shows text with current formatting.
  void drawText(
    String text,
    double x,
    double y, {
    String? fontRef,
    double? fontSize,
    String? colorHex,
  }) {
    beginText();
    setTextMatrix(x, y);

    if (fontRef != null || fontSize != null) {
      setFont(fontRef ?? _currentFont, fontSize ?? _currentFontSize);
    }

    if (colorHex != null) {
      setFillColorHex(colorHex);
    } else {
      _buffer.writeln('$_currentColor rg');
    }

    showText(text);
    endText();
  }

  // --- Images ---

  /// Draws an image XObject.
  void drawImage(String name, double x, double y, double width, double height) {
    saveState();
    _buffer.writeln('$width 0 0 $height $x $y cm');
    _buffer.writeln('$name Do');
    restoreState();
  }

  // --- Utilities ---

  /// Measures text width.
  double measureText(String text, double fontSize) {
    return _fontManager.measureText(text, fontSize);
  }

  /// Escapes text for PDF.
  String escapeText(String text) => _fontManager.escapeText(text);
}
