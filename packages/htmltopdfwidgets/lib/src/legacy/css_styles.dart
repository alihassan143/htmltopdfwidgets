import 'package:htmltopdfwidgets/htmltopdfwidgets.dart';

/// Data class to hold parsed CSS properties
class CssStyles {
  // Layout properties
  final double? width;
  final double? height;
  final String? display;

  // Spacing properties
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  // Text properties
  final double? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final String? fontFamily;
  final PdfColor? color;
  final TextAlign? textAlign;
  final TextDecoration? textDecoration;
  final String? textTransform;
  final double? lineHeight;
  final double? letterSpacing;

  // Background properties
  final PdfColor? backgroundColor;
  final BoxDecoration? background;

  // Border properties
  final BorderInfo? border;
  final BorderInfo? borderTop;
  final BorderInfo? borderRight;
  final BorderInfo? borderBottom;
  final BorderInfo? borderLeft;
  final String? borderCollapse;
  final double? borderSpacing;

  // Table properties
  final String? verticalAlign;
  final int? colspan;
  final int? rowspan;

  // List properties
  final String? listStyleType;

  const CssStyles({
    this.width,
    this.height,
    this.display,
    this.margin,
    this.padding,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.fontFamily,
    this.color,
    this.textAlign,
    this.textDecoration,
    this.textTransform,
    this.lineHeight,
    this.letterSpacing,
    this.backgroundColor,
    this.background,
    this.border,
    this.borderTop,
    this.borderRight,
    this.borderBottom,
    this.borderLeft,
    this.borderCollapse,
    this.borderSpacing,
    this.verticalAlign,
    this.colspan,
    this.rowspan,
    this.listStyleType,
  });

  /// Merge with another CssStyles, with the other taking precedence
  CssStyles merge(CssStyles? other) {
    if (other == null) return this;

    return CssStyles(
      width: other.width ?? width,
      height: other.height ?? height,
      display: other.display ?? display,
      margin: other.margin ?? margin,
      padding: other.padding ?? padding,
      fontSize: other.fontSize ?? fontSize,
      fontWeight: other.fontWeight ?? fontWeight,
      fontStyle: other.fontStyle ?? fontStyle,
      fontFamily: other.fontFamily ?? fontFamily,
      color: other.color ?? color,
      textAlign: other.textAlign ?? textAlign,
      textDecoration: other.textDecoration ?? textDecoration,
      textTransform: other.textTransform ?? textTransform,
      lineHeight: other.lineHeight ?? lineHeight,
      letterSpacing: other.letterSpacing ?? letterSpacing,
      backgroundColor: other.backgroundColor ?? backgroundColor,
      background: other.background ?? background,
      border: other.border ?? border,
      borderTop: other.borderTop ?? borderTop,
      borderRight: other.borderRight ?? borderRight,
      borderBottom: other.borderBottom ?? borderBottom,
      borderLeft: other.borderLeft ?? borderLeft,
      borderCollapse: other.borderCollapse ?? borderCollapse,
      borderSpacing: other.borderSpacing ?? borderSpacing,
      verticalAlign: other.verticalAlign ?? verticalAlign,
      colspan: other.colspan ?? colspan,
      rowspan: other.rowspan ?? rowspan,
      listStyleType: other.listStyleType ?? listStyleType,
    );
  }

  /// Check if this has any non-null values
  bool get isEmpty =>
      width == null &&
      height == null &&
      display == null &&
      margin == null &&
      padding == null &&
      fontSize == null &&
      fontWeight == null &&
      fontStyle == null &&
      fontFamily == null &&
      color == null &&
      textAlign == null &&
      textDecoration == null &&
      textTransform == null &&
      lineHeight == null &&
      letterSpacing == null &&
      backgroundColor == null &&
      background == null &&
      border == null &&
      borderTop == null &&
      borderRight == null &&
      borderBottom == null &&
      borderLeft == null &&
      borderCollapse == null &&
      borderSpacing == null &&
      verticalAlign == null &&
      colspan == null &&
      rowspan == null &&
      listStyleType == null;
}

/// Border information for CSS border properties
class BorderInfo {
  final double width;
  final PdfColor color;
  final BorderStyle style;

  const BorderInfo({
    required this.width,
    required this.color,
    this.style = BorderStyle.solid,
  });

  /// Create from CSS shorthand string (e.g., "1px solid black")
  static BorderInfo? fromString(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;

    double? width;
    PdfColor? color;
    BorderStyle style = BorderStyle.solid;

    for (final part in parts) {
      // Try to parse as width
      if (part.endsWith('px') || part.endsWith('pt')) {
        final numStr = part.substring(0, part.length - 2);
        width = double.tryParse(numStr);
      } else if (double.tryParse(part) != null) {
        width = double.tryParse(part);
      }
      // Try to parse as style
      else if (part == 'solid' ||
          part == 'dashed' ||
          part == 'dotted' ||
          part == 'none') {
        style = _parseBorderStyle(part);
      }
      // Try to parse as color
      else {
        try {
          color = _parseColor(part);
        } catch (e) {
          // Ignore color parsing errors
        }
      }
    }

    if (width != null || color != null) {
      return BorderInfo(
        width: width ?? 1.0,
        color: color ?? PdfColors.black,
        style: style,
      );
    }

    return null;
  }

  static BorderStyle _parseBorderStyle(String value) {
    switch (value.toLowerCase()) {
      case 'dashed':
        return BorderStyle.dashed;
      case 'dotted':
        return BorderStyle.dotted;
      case 'none':
        return BorderStyle.none;
      default:
        return BorderStyle.solid;
    }
  }

  static PdfColor? _parseColor(String value) {
    // This is a simplified color parser
    // You can expand this to support more color formats
    final colorMap = {
      'black': PdfColors.black,
      'white': PdfColors.white,
      'red': PdfColors.red,
      'green': PdfColors.green,
      'blue': PdfColors.blue,
      'gray': PdfColors.grey,
      'grey': PdfColors.grey,
    };

    final lower = value.toLowerCase();
    if (colorMap.containsKey(lower)) {
      return colorMap[lower];
    }

    // Try to parse hex color
    if (value.startsWith('#')) {
      try {
        final hex = value.substring(1);
        if (hex.length == 6) {
          final r = int.parse(hex.substring(0, 2), radix: 16);
          final g = int.parse(hex.substring(2, 4), radix: 16);
          final b = int.parse(hex.substring(4, 6), radix: 16);
          return PdfColor.fromInt(0xFF000000 | (r << 16) | (g << 8) | b);
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }

    return null;
  }
}
