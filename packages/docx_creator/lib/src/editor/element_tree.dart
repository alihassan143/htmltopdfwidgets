/// Data models for the layered PDF editor.
///
/// Provides an abstraction layer between Flutter UI and PDF bytes.
library;

/// Base class for all PDF elements in the editor.
abstract class PdfElement {
  /// X position in points from left.
  double x;

  /// Y position in points from bottom.
  double y;

  /// Element width in points.
  double width;

  /// Element height in points.
  double height;

  /// Z-index for layering.
  int zIndex;

  /// Whether the element is selected.
  bool isSelected;

  /// Unique identifier for this element.
  final String id;

  PdfElement({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.zIndex = 0,
    this.isSelected = false,
    String? id,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  /// Creates a copy of this element with new position/size.
  PdfElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    int? zIndex,
    bool? isSelected,
  });

  /// Renders this element to a PDF content stream.
  /// Returns the PDF operators as a string.
  String render();
}

/// Text element in the PDF editor.
class TextElement extends PdfElement {
  /// Text content.
  String content;

  /// Font size in points.
  double fontSize;

  /// Font family name (e.g., 'Helvetica', 'Courier', or embedded font name).
  String fontFamily;

  /// Whether text is bold.
  bool isBold;

  /// Whether text is italic.
  bool isItalic;

  /// Whether text has underline decoration.
  bool isUnderline;

  /// Whether text has strikethrough decoration.
  bool isStrikethrough;

  /// Whether text is superscript.
  bool isSuperscript;

  /// Whether text is subscript.
  bool isSubscript;

  /// Whether text is all caps.
  bool isAllCaps;

  /// Whether text is small caps.
  bool isSmallCaps;

  /// Text color as hex (e.g., "000000").
  String colorHex;

  /// Background/highlight color (null for transparent).
  String? backgroundHex;

  /// Highlight color name (e.g., "yellow", "cyan").
  String? highlightColor;

  /// Character spacing in points (positive = wider, negative = tighter).
  double characterSpacing;

  /// Line height multiplier (1.0 = normal, 1.5 = 150%).
  double lineHeight;

  /// Text alignment for multi-line text.
  String textAlign;

  /// Embedded font reference (e.g., '/F5' for custom fonts).
  String? embeddedFontRef;

  /// Opacity (0.0 = transparent, 1.0 = fully opaque).
  double opacity;

  /// Rotation angle in degrees.
  double rotation;

  TextElement({
    required super.x,
    required super.y,
    required this.content,
    this.fontSize = 12,
    this.fontFamily = 'Helvetica',
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.isSuperscript = false,
    this.isSubscript = false,
    this.isAllCaps = false,
    this.isSmallCaps = false,
    this.colorHex = '000000',
    this.backgroundHex,
    this.highlightColor,
    this.characterSpacing = 0,
    this.lineHeight = 1.2,
    this.textAlign = 'left',
    this.embeddedFontRef,
    this.opacity = 1.0,
    this.rotation = 0,
    super.zIndex,
    super.isSelected,
    super.id,
  }) : super(
          width: content.length * fontSize * 0.5,
          height: fontSize * 1.2,
        );

  @override
  PdfElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    int? zIndex,
    bool? isSelected,
    String? content,
    double? fontSize,
    String? fontFamily,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    bool? isStrikethrough,
    String? colorHex,
    String? backgroundHex,
  }) {
    return TextElement(
      x: x ?? this.x,
      y: y ?? this.y,
      content: content ?? this.content,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      isStrikethrough: isStrikethrough ?? this.isStrikethrough,
      isSuperscript: isSuperscript,
      isSubscript: isSubscript,
      isAllCaps: isAllCaps,
      isSmallCaps: isSmallCaps,
      colorHex: colorHex ?? this.colorHex,
      backgroundHex: backgroundHex ?? this.backgroundHex,
      highlightColor: highlightColor,
      characterSpacing: characterSpacing,
      lineHeight: lineHeight,
      textAlign: textAlign,
      embeddedFontRef: embeddedFontRef,
      opacity: opacity,
      rotation: rotation,
      zIndex: zIndex ?? this.zIndex,
      isSelected: isSelected ?? this.isSelected,
      id: id,
    );
  }

  /// Gets the effective font size (adjusted for super/subscript).
  double get effectiveFontSize {
    if (isSuperscript || isSubscript) {
      return fontSize * 0.6;
    }
    return fontSize;
  }

  /// Gets the font reference for PDF.
  String get fontRef {
    if (embeddedFontRef != null) return embeddedFontRef!;

    // Standard fonts
    if (fontFamily == 'Courier') return '/F4';
    if (isBold && isItalic) return '/F2'; // Bold (no bold-italic in standard)
    if (isBold) return '/F2';
    if (isItalic) return '/F3';
    return '/F1';
  }

  @override
  String render() {
    final sb = StringBuffer();

    // Save graphics state
    sb.writeln('q');

    // Apply opacity if not fully opaque
    if (opacity < 1.0) {
      // Note: Opacity requires ExtGState in PDF resources
    }

    // Background/highlight if present
    final bgColor = backgroundHex ?? _highlightToHex(highlightColor);
    if (bgColor != null) {
      final rgb = _hexToRgbValues(bgColor);
      sb.writeln('${rgb[0]} ${rgb[1]} ${rgb[2]} rg');
      sb.writeln('$x $y $width ${fontSize * lineHeight} re f');
    }

    // Text rendering
    final rgb = _hexToRgbValues(colorHex);
    final effSize = effectiveFontSize;
    final displayText = isAllCaps ? content.toUpperCase() : content;

    sb.writeln('BT');
    sb.writeln('${rgb[0]} ${rgb[1]} ${rgb[2]} rg');
    sb.writeln('$fontRef $effSize Tf');

    // Character spacing
    if (characterSpacing != 0) {
      sb.writeln('${characterSpacing.toStringAsFixed(3)} Tc');
    }

    // Position - adjust for super/subscript
    var yPos = y;
    if (isSuperscript) {
      yPos += fontSize * 0.4;
    } else if (isSubscript) {
      yPos -= fontSize * 0.2;
    }

    // Apply rotation if needed
    if (rotation != 0) {
      final rad = rotation * 3.14159265 / 180;
      final cosR = _cos(rad);
      final sinR = _sin(rad);
      sb.writeln('$cosR $sinR ${-sinR} $cosR $x $yPos Tm');
    } else {
      sb.writeln('1 0 0 1 $x $yPos Tm');
    }

    sb.writeln('(${_escapeText(displayText)}) Tj');
    sb.writeln('ET');

    // Draw underline
    if (isUnderline) {
      final lineY = yPos - fontSize * 0.15;
      sb.writeln('${rgb[0]} ${rgb[1]} ${rgb[2]} RG');
      sb.writeln('0.5 w');
      sb.writeln('$x $lineY m ${x + width} $lineY l S');
    }

    // Draw strikethrough
    if (isStrikethrough) {
      final lineY = yPos + fontSize * 0.35;
      sb.writeln('${rgb[0]} ${rgb[1]} ${rgb[2]} RG');
      sb.writeln('0.5 w');
      sb.writeln('$x $lineY m ${x + width} $lineY l S');
    }

    // Restore graphics state
    sb.writeln('Q');

    return sb.toString();
  }

  /// Escapes text for PDF string.
  String _escapeText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }

  /// Converts hex color to RGB values (0-1 range).
  List<String> _hexToRgbValues(String hex) {
    final h = hex.replaceAll('#', '');
    if (h.length != 6) return ['0', '0', '0'];
    final r = int.parse(h.substring(0, 2), radix: 16) / 255;
    final g = int.parse(h.substring(2, 4), radix: 16) / 255;
    final b = int.parse(h.substring(4, 6), radix: 16) / 255;
    return [r.toStringAsFixed(3), g.toStringAsFixed(3), b.toStringAsFixed(3)];
  }

  /// Converts highlight color name to hex.
  String? _highlightToHex(String? name) {
    if (name == null) return null;
    const colors = {
      'yellow': 'FFFF00',
      'green': '00FF00',
      'cyan': '00FFFF',
      'magenta': 'FF00FF',
      'blue': '0000FF',
      'red': 'FF0000',
      'darkBlue': '00008B',
      'darkCyan': '008B8B',
      'darkGreen': '006400',
      'darkMagenta': '8B008B',
      'darkRed': '8B0000',
      'darkYellow': 'FFD700',
      'lightGray': 'D3D3D3',
      'black': '000000',
    };
    return colors[name];
  }

  /// Simple cosine calculation.
  double _cos(double rad) {
    // Taylor series approximation for small angles
    return 1 - (rad * rad / 2) + (rad * rad * rad * rad / 24);
  }

  /// Simple sine calculation.
  double _sin(double rad) {
    // Taylor series approximation for small angles
    return rad - (rad * rad * rad / 6) + (rad * rad * rad * rad * rad / 120);
  }
}

/// Image element in the PDF editor.
class ImageElement extends PdfElement {
  /// Image data as bytes.
  final List<int> bytes;

  /// Image format extension (e.g., "png").
  final String extension;

  /// XObject name (set by exporter).
  String? xObjectName;

  ImageElement({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.bytes,
    required this.extension,
    this.xObjectName,
    super.zIndex,
    super.isSelected,
    super.id,
  });

  @override
  PdfElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    int? zIndex,
    bool? isSelected,
  }) {
    return ImageElement(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      bytes: bytes,
      extension: extension,
      xObjectName: xObjectName,
      zIndex: zIndex ?? this.zIndex,
      isSelected: isSelected ?? this.isSelected,
      id: id,
    );
  }

  @override
  String render() {
    if (xObjectName == null) return '';
    final sb = StringBuffer();
    sb.writeln('q');
    sb.writeln('$width 0 0 $height $x $y cm');
    sb.writeln('$xObjectName Do');
    sb.writeln('Q');
    return sb.toString();
  }
}

/// Shape element in the PDF editor.
class ShapeElement extends PdfElement {
  /// Shape type preset name.
  final String preset;

  /// Fill color hex (null for no fill).
  String? fillHex;

  /// Stroke color hex (null for no stroke).
  String? strokeHex;

  /// Stroke width in points.
  double strokeWidth;

  /// Corner radius for rounded rectangles.
  double cornerRadius;

  ShapeElement({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    this.preset = 'rect',
    this.fillHex,
    this.strokeHex = '000000',
    this.strokeWidth = 1,
    this.cornerRadius = 0,
    super.zIndex,
    super.isSelected,
    super.id,
  });

  @override
  PdfElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    int? zIndex,
    bool? isSelected,
  }) {
    return ShapeElement(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      preset: preset,
      fillHex: fillHex,
      strokeHex: strokeHex,
      strokeWidth: strokeWidth,
      cornerRadius: cornerRadius,
      zIndex: zIndex ?? this.zIndex,
      isSelected: isSelected ?? this.isSelected,
      id: id,
    );
  }

  @override
  String render() {
    final sb = StringBuffer();
    sb.writeln('q');

    // Set colors
    if (fillHex != null) {
      final r = int.parse(fillHex!.substring(0, 2), radix: 16) / 255;
      final g = int.parse(fillHex!.substring(2, 4), radix: 16) / 255;
      final b = int.parse(fillHex!.substring(4, 6), radix: 16) / 255;
      sb.writeln(
          '${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)} rg');
    }
    if (strokeHex != null) {
      final r = int.parse(strokeHex!.substring(0, 2), radix: 16) / 255;
      final g = int.parse(strokeHex!.substring(2, 4), radix: 16) / 255;
      final b = int.parse(strokeHex!.substring(4, 6), radix: 16) / 255;
      sb.writeln(
          '${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)} RG');
      sb.writeln('$strokeWidth w');
    }

    // Draw shape based on preset
    switch (preset) {
      case 'rect':
        sb.writeln('$x $y $width $height re');
        break;
      case 'ellipse':
        _appendEllipsePath(
            sb, x + width / 2, y + height / 2, width / 2, height / 2);
        break;
      default:
        sb.writeln('$x $y $width $height re');
    }

    // Fill and/or stroke
    if (fillHex != null && strokeHex != null) {
      sb.writeln('B');
    } else if (fillHex != null) {
      sb.writeln('f');
    } else if (strokeHex != null) {
      sb.writeln('S');
    }

    sb.writeln('Q');
    return sb.toString();
  }

  void _appendEllipsePath(
      StringBuffer sb, double cx, double cy, double rx, double ry) {
    const k = 0.5522847498;
    final kx = rx * k;
    final ky = ry * k;

    sb.writeln('${cx + rx} $cy m');
    sb.writeln('${cx + rx} ${cy + ky} ${cx + kx} ${cy + ry} $cx ${cy + ry} c');
    sb.writeln('${cx - kx} ${cy + ry} ${cx - rx} ${cy + ky} ${cx - rx} $cy c');
    sb.writeln('${cx - rx} ${cy - ky} ${cx - kx} ${cy - ry} $cx ${cy - ry} c');
    sb.writeln('${cx + kx} ${cy - ry} ${cx + rx} ${cy - ky} ${cx + rx} $cy c');
    sb.writeln('h');
  }
}

/// Container for all elements in a PDF page being edited.
class ElementTree {
  /// All elements on this page.
  final List<PdfElement> elements = [];

  /// Page width in points.
  final double pageWidth;

  /// Page height in points.
  final double pageHeight;

  ElementTree({
    this.pageWidth = 612,
    this.pageHeight = 792,
  });

  /// Adds an element to the tree.
  void addElement(PdfElement element) {
    elements.add(element);
    _sortByZIndex();
  }

  /// Removes an element by ID.
  bool removeElement(String id) {
    final index = elements.indexWhere((e) => e.id == id);
    if (index >= 0) {
      elements.removeAt(index);
      return true;
    }
    return false;
  }

  /// Updates an element's position.
  void moveElement(String id, double dx, double dy) {
    final element = elements.firstWhere((e) => e.id == id,
        orElse: () => throw Exception('Element not found'));
    element.x += dx;
    element.y += dy;
  }

  /// Updates an element's size.
  void resizeElement(String id, double newWidth, double newHeight) {
    final element = elements.firstWhere((e) => e.id == id,
        orElse: () => throw Exception('Element not found'));
    element.width = newWidth;
    element.height = newHeight;
  }

  /// Gets the element at a given point (for hit testing).
  PdfElement? hitTest(double x, double y) {
    // Search from top (highest z-index) to bottom
    for (var i = elements.length - 1; i >= 0; i--) {
      final e = elements[i];
      if (x >= e.x && x <= e.x + e.width && y >= e.y && y <= e.y + e.height) {
        return e;
      }
    }
    return null;
  }

  /// Selects an element by ID.
  void selectElement(String? id) {
    for (final e in elements) {
      e.isSelected = (e.id == id);
    }
  }

  /// Gets the currently selected element.
  PdfElement? get selectedElement {
    try {
      return elements.firstWhere((e) => e.isSelected);
    } catch (_) {
      return null;
    }
  }

  /// Commits all elements to a PDF content stream.
  /// This is the "flatten" operation that converts UI state to PDF bytes.
  String commit() {
    final sb = StringBuffer();

    for (final element in elements) {
      sb.write(element.render());
    }

    return sb.toString();
  }

  void _sortByZIndex() {
    elements.sort((a, b) => a.zIndex.compareTo(b.zIndex));
  }
}
