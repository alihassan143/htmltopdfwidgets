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

  /// Sets the line width.
  void setLineWidth(double width) {
    _buffer.writeln('$width w');
  }

  /// Moves current point to (x, y).
  void moveTo(double x, double y) {
    _buffer.writeln('$x $y m');
  }

  /// Appends a straight line segment from the current point to (x, y).
  void lineTo(double x, double y) {
    _buffer.writeln('$x $y l');
  }

  /// Strokes the path.
  void strokePath() {
    _buffer.writeln('S');
  }

  /// Fills the path (using non-zero winding rule).
  void fillPath() {
    _buffer.writeln('f');
  }

  /// Fills and strokes the path.
  void fillStrokePath() {
    _buffer.writeln('B');
  }

  /// Closes the current subpath.
  void closePath() {
    _buffer.writeln('h');
  }

  /// Closes, fills, and strokes the path.
  void closeFillStrokePath() {
    _buffer.writeln('b');
  }

  /// Appends a cubic Bezier curve from current point to (x3, y3).
  /// Uses (x1, y1) and (x2, y2) as control points.
  void curveTo(
      double x1, double y1, double x2, double y2, double x3, double y3) {
    _buffer.writeln('$x1 $y1 $x2 $y2 $x3 $y3 c');
  }

  /// Appends a cubic Bezier curve with the first control point at current point.
  void curveToV(double x2, double y2, double x3, double y3) {
    _buffer.writeln('$x2 $y2 $x3 $y3 v');
  }

  /// Appends a cubic Bezier curve with the last control point at end point.
  void curveToY(double x1, double y1, double x3, double y3) {
    _buffer.writeln('$x1 $y1 $x3 $y3 y');
  }

  /// Draws an ellipse approximated with Bezier curves.
  void drawEllipse(double cx, double cy, double rx, double ry,
      {bool stroke = true, bool fill = false}) {
    // Bezier approximation constant for circles
    const k = 0.5522847498;
    final kx = rx * k;
    final ky = ry * k;

    // Start at right side of ellipse
    moveTo(cx + rx, cy);

    // Draw 4 Bezier curves for each quadrant
    curveTo(cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry);
    curveTo(cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy);
    curveTo(cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry);
    curveTo(cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy);

    closePath();

    if (fill && stroke) {
      fillStrokePath();
    } else if (fill) {
      fillPath();
    } else if (stroke) {
      strokePath();
    }
  }

  /// Draws a circle.
  void drawCircle(double cx, double cy, double radius,
      {bool stroke = true, bool fill = false}) {
    drawEllipse(cx, cy, radius, radius, stroke: stroke, fill: fill);
  }

  /// Draws a rounded rectangle.
  void drawRoundedRect(
      double x, double y, double width, double height, double radius,
      {bool stroke = true, bool fill = false}) {
    final r = radius.clamp(0, (width / 2).clamp(0, height / 2));
    const k = 0.5522847498;
    final kr = r * k;

    moveTo(x + r, y);
    lineTo(x + width - r, y);
    curveTo(x + width - r + kr, y, x + width, y + r - kr, x + width, y + r);
    lineTo(x + width, y + height - r);
    curveTo(x + width, y + height - r + kr, x + width - r + kr, y + height,
        x + width - r, y + height);
    lineTo(x + r, y + height);
    curveTo(x + r - kr, y + height, x, y + height - r + kr, x, y + height - r);
    lineTo(x, y + r);
    curveTo(x, y + r - kr, x + r - kr, y, x + r, y);
    closePath();

    if (fill && stroke) {
      fillStrokePath();
    } else if (fill) {
      fillPath();
    } else if (stroke) {
      strokePath();
    }
  }

  /// Draws a polygon from a list of points.
  void drawPolygon(List<List<double>> points,
      {bool stroke = true, bool fill = false}) {
    if (points.isEmpty) return;

    moveTo(points[0][0], points[0][1]);
    for (var i = 1; i < points.length; i++) {
      lineTo(points[i][0], points[i][1]);
    }
    closePath();

    if (fill && stroke) {
      fillStrokePath();
    } else if (fill) {
      fillPath();
    } else if (stroke) {
      strokePath();
    }
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
  /// [isBold] applies a width scaling factor for bold fonts.
  double measureText(String text, double fontSize, {bool isBold = false}) {
    return _fontManager.measureText(text, fontSize, isBold: isBold);
  }

  /// Escapes text for PDF.
  String escapeText(String text) => _fontManager.escapeText(text);

  /// Decodes common HTML entities to their character equivalents.
  static String decodeHtmlEntities(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#39;', "'")
        .replaceAll('&#34;', '"')
        .replaceAll('&#60;', '<')
        .replaceAll('&#62;', '>');
  }
}
