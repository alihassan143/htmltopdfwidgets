part of 'pdf_reader.dart';

/// Graphics state for PDF rendering.
class _GraphState {
  _PdfMatrix ctm = _PdfMatrix.identity();
  _PdfMatrix textMatrix = _PdfMatrix.identity();
  _PdfMatrix textLineMatrix = _PdfMatrix.identity();

  double fillColorR = 0;
  double fillColorG = 0;
  double fillColorB = 0;

  double strokeColorR = 0;
  double strokeColorG = 0;
  double strokeColorB = 0;

  double lineWidth = 1;
  String fontName = '/F1';
  double fontSize = 12;
  double textRise = 0;

  _GraphState clone() {
    return _GraphState()
      ..ctm = ctm.clone()
      ..textMatrix = textMatrix.clone()
      ..textLineMatrix = textLineMatrix.clone()
      ..fillColorR = fillColorR
      ..fillColorG = fillColorG
      ..fillColorB = fillColorB
      ..strokeColorR = strokeColorR
      ..strokeColorG = strokeColorG
      ..strokeColorB = strokeColorB
      ..lineWidth = lineWidth
      ..fontName = fontName
      ..fontSize = fontSize
      ..textRise = textRise;
  }
}

/// 2D Affine Transform Matrix.
class _PdfMatrix {
  final double a, b, c, d, e, f;

  const _PdfMatrix(this.a, this.b, this.c, this.d, this.e, this.f);

  factory _PdfMatrix.identity() => const _PdfMatrix(1, 0, 0, 1, 0, 0);

  _PdfMatrix multiply(_PdfMatrix other) {
    return _PdfMatrix(
      a * other.a + b * other.c,
      a * other.b + b * other.d,
      c * other.a + d * other.c,
      c * other.b + d * other.d,
      e * other.a + f * other.c + other.e,
      e * other.b + f * other.d + other.f,
    );
  }

  _PdfMatrix clone() => _PdfMatrix(a, b, c, d, e, f);

  // Transform point (x, y) -> (x', y')
  // x' = a*x + c*y + e
  // y' = b*x + d*y + f
  List<double> transform(double x, double y) {
    return [a * x + c * y + e, b * x + d * y + f];
  }

  // Transform vector (ignore translation)
  List<double> transformVec(double x, double y) {
    return [a * x + c * y, b * x + d * y];
  }
}

/// Path construction command.
class _PathCommand {
  final String type;
  final List<double> nums;

  const _PathCommand(this.type, this.nums);

  factory _PathCommand.moveTo(double x, double y) =>
      _PathCommand('move', [x, y]);
  factory _PathCommand.lineTo(double x, double y) =>
      _PathCommand('line', [x, y]);
  factory _PathCommand.cubic(
          double x1, double y1, double x2, double y2, double x3, double y3) =>
      _PathCommand('cubic', [x1, y1, x2, y2, x3, y3]);
  factory _PathCommand.rect(double x, double y, double w, double h) =>
      _PathCommand('rect', [x, y, w, h]);
  factory _PathCommand.close() => const _PathCommand('close', []);
}

/// Represents a graphic line segment (for tables/underlines).
class _GraphicLine {
  final double x1, y1, x2, y2;
  const _GraphicLine(this.x1, this.y1, this.x2, this.y2);

  bool get isHorizontal => (y1 - y2).abs() < 0.1;
  bool get isVertical => (x1 - x2).abs() < 0.1;
}

/// Abstract base item for page layout.
abstract class _PageItem {
  double x;
  double y;
  _PageItem(this.x, this.y);
}

/// Represents a simplified text line with position and style.
class _TextLine extends _PageItem {
  final String text;
  final String font;
  final double size;
  final double colorR;
  final double colorG;
  final double colorB;

  // Advanced features
  final double textRise;
  bool isUnderline = false; // Mutable for post-processing
  bool isStrikethrough = false; // Mutable for post-processing

  _TextLine({
    required this.text,
    required double x,
    required double y,
    required this.font,
    required this.size,
    required this.colorR,
    required this.colorG,
    required this.colorB,
    this.textRise = 0,
  }) : super(x, y);
}

/// Represents an image on the page.
class _ImageItem extends _PageItem {
  final Uint8List bytes;
  final double width;
  final double height;
  final String extension;

  _ImageItem({
    required this.bytes,
    required double x,
    required double y,
    required this.width,
    required this.height,
    required this.extension,
  }) : super(x, y);
}

/// Internal font info.
class _FontInfo {
  final String name;
  final String baseFont;
  final bool isBold;
  final bool isItalic;

  _FontInfo({
    required this.name,
    required this.baseFont,
    required this.isBold,
    required this.isItalic,
  });
}

/// Extracted image with metadata.
class PdfExtractedImage {
  final Uint8List bytes;
  final int width;
  final int height;
  final String format;

  PdfExtractedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
  });
}
