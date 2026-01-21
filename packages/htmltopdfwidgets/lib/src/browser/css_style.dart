import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

enum Display { block, inline, none }

/// Image fit mode, similar to CSS object-fit
enum ObjectFit { contain, cover, fill, fitWidth, fitHeight, none, scaleDown }

/// Vertical alignment for table cells
enum VerticalAlign { top, middle, bottom, baseline }

/// Table layout algorithm
enum TableLayout { auto, fixed }

class CSSStyle {
  final PdfColor? color;
  final PdfColor? backgroundColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final TextDecoration? textDecoration;
  final Display? display;
  final double? width;
  final double? height;
  final double? lineHeight;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Border? border;
  final Border? borderTop;
  final Border? borderRight;
  final Border? borderBottom;
  final Border? borderLeft;
  final String? fontFamily;
  final TextAlign? textAlign;
  final ObjectFit? objectFit;
  final VerticalAlign? verticalAlign;
  final double? borderRadius;
  final bool? borderCollapse;
  final TextDirection? textDirection;
  final TableLayout? tableLayout;

  const CSSStyle({
    this.color,
    this.backgroundColor,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.textDecoration,
    this.display,
    this.width,
    this.height,
    this.lineHeight,
    this.padding,
    this.margin,
    this.border,
    this.borderTop,
    this.borderRight,
    this.borderBottom,
    this.borderLeft,
    this.fontFamily,
    this.textAlign,
    this.objectFit,
    this.verticalAlign,
    this.borderRadius,
    this.borderCollapse,
    this.textDirection,
    this.tableLayout,
  });

  /// Merges this style with another style. The other style takes precedence.
  CSSStyle merge(CSSStyle other) {
    return CSSStyle(
      color: other.color ?? color,
      backgroundColor: other.backgroundColor ?? backgroundColor,
      fontSize: other.fontSize ?? fontSize,
      fontWeight: other.fontWeight ?? fontWeight,
      fontStyle: other.fontStyle ?? fontStyle,
      textDecoration: other.textDecoration ?? textDecoration,
      display: other.display ?? display,
      width: other.width ?? width,
      height: other.height ?? height,
      lineHeight: other.lineHeight ?? lineHeight,
      padding: other.padding ?? padding,
      margin: other.margin ?? margin,
      border: other.border ?? border,
      borderTop: other.borderTop ?? borderTop,
      borderRight: other.borderRight ?? borderRight,
      borderBottom: other.borderBottom ?? borderBottom,
      borderLeft: other.borderLeft ?? borderLeft,
      fontFamily: other.fontFamily ?? fontFamily,
      textAlign: other.textAlign ?? textAlign,
      objectFit: other.objectFit ?? objectFit,
      verticalAlign: other.verticalAlign ?? verticalAlign,
      borderRadius: other.borderRadius ?? borderRadius,
      borderCollapse: other.borderCollapse ?? borderCollapse,
      textDirection: other.textDirection ?? textDirection,
      tableLayout: other.tableLayout ?? tableLayout,
    );
  }

  /// Inherits inheritable properties from a parent style.
  CSSStyle inheritFrom(CSSStyle parent) {
    return CSSStyle(
      color: color ?? parent.color,
      fontSize: fontSize ?? parent.fontSize,
      fontWeight: fontWeight ?? parent.fontWeight,
      fontStyle: fontStyle ?? parent.fontStyle,
      textDecoration: textDecoration ?? parent.textDecoration,
      fontFamily: fontFamily ?? parent.fontFamily,
      textAlign: textAlign ?? parent.textAlign,
      textDirection: textDirection ?? parent.textDirection,
      // Non-inherited properties
      backgroundColor: backgroundColor,
      display: display,
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      border: border,
      borderTop: borderTop,
      borderRight: borderRight,
      borderBottom: borderBottom,
      borderLeft: borderLeft,
      objectFit: objectFit,
      verticalAlign: verticalAlign,
      borderRadius: borderRadius,
      borderCollapse: borderCollapse,
      tableLayout: tableLayout,
    );
  }

  /// Parses a CSS string into a CSSStyle object.
  static CSSStyle parse(String cssString) {
    if (cssString.isEmpty) return const CSSStyle();

    PdfColor? color;
    PdfColor? backgroundColor;
    double? fontSize;
    FontWeight? fontWeight;
    FontStyle? fontStyle;
    TextDecoration? textDecoration;
    Display? display;
    double? width;
    double? height;
    double? lineHeight;
    EdgeInsets? padding;
    EdgeInsets? margin;
    Border? border;
    String? fontFamily;
    TextAlign? textAlign;
    ObjectFit? objectFit;
    VerticalAlign? verticalAlign;
    double? borderRadius;
    bool? borderCollapse;
    TextDirection? textDirection;
    TableLayout? tableLayout;

    final declarations = cssString.split(';');
    for (var declaration in declarations) {
      final parts = declaration.split(':');
      if (parts.length != 2) continue;

      final property = parts[0].trim().toLowerCase();
      final value = parts[1].trim();

      switch (property) {
        case 'color':
          color = _parseColor(value);
          break;
        case 'background-color':
          backgroundColor = _parseColor(value);
          break;
        case 'font-size':
          fontSize = _parseLength(value);
          break;
        case 'font-weight':
          fontWeight = _parseFontWeight(value);
          break;
        case 'font-style':
          fontStyle = _parseFontStyle(value);
          break;
        case 'text-decoration':
          textDecoration = _parseTextDecoration(value);
          break;
        case 'display':
          display = _parseDisplay(value);
          break;
        case 'width':
          width = _parseLength(value);
          break;
        case 'height':
          height = _parseLength(value);
          break;
        case 'line-height':
          lineHeight = _parseLength(value);
          break;
        case 'padding':
          padding = _parseEdgeInsets(value);
          break;
        case 'margin':
          margin = _parseEdgeInsets(value);
          break;
        case 'border':
          border = _parseBorder(value);
          break;
        case 'font-family':
          fontFamily = value.replaceAll(RegExp(r"['\u0022]"), '');
          break;
        case 'text-align':
          textAlign = _parseTextAlign(value);
          break;
        case 'object-fit':
          objectFit = _parseObjectFit(value);
          break;
        case 'vertical-align':
          verticalAlign = _parseVerticalAlign(value);
          break;
        case 'border-radius':
          borderRadius = _parseLength(value);
          break;
        case 'border-collapse':
          if (value == 'collapse') borderCollapse = true;
          if (value == 'separate') borderCollapse = false;
          break;
        case 'direction':
          if (value == 'rtl') textDirection = TextDirection.rtl;
          if (value == 'ltr') textDirection = TextDirection.ltr;
          break;
        case 'table-layout':
          if (value == 'fixed') tableLayout = TableLayout.fixed;
          if (value == 'auto') tableLayout = TableLayout.auto;
          break;
      }
    }

    return CSSStyle(
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      textDecoration: textDecoration,
      display: display,
      width: width,
      height: height,
      lineHeight: lineHeight,
      padding: padding,
      margin: margin,
      border: border,
      fontFamily: fontFamily,
      textAlign: textAlign,
      objectFit: objectFit,
      verticalAlign: verticalAlign,
      borderRadius: borderRadius,
      borderCollapse: borderCollapse,
      textDirection: textDirection,
      tableLayout: tableLayout,
    );
  }

  static PdfColor? _parseColor(String value) {
    final trimmed = value.trim().toLowerCase();

    // Handle hex colors
    if (trimmed.startsWith('#')) {
      return PdfColor.fromHex(trimmed);
    }

    // Handle rgb/rgba
    if (trimmed.startsWith('rgb')) {
      final match = RegExp(
              r'rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)')
          .firstMatch(trimmed);
      if (match != null) {
        final r = int.tryParse(match.group(1) ?? '0') ?? 0;
        final g = int.tryParse(match.group(2) ?? '0') ?? 0;
        final b = int.tryParse(match.group(3) ?? '0') ?? 0;
        final a = double.tryParse(match.group(4) ?? '1') ?? 1.0;
        return PdfColor(r / 255, g / 255, b / 255, a);
      }
    }

    // Handle named colors
    switch (trimmed) {
      case 'red':
        return PdfColors.red;
      case 'green':
        return PdfColors.green;
      case 'blue':
        return PdfColors.blue;
      case 'black':
        return PdfColors.black;
      case 'white':
        return PdfColors.white;
      case 'grey':
      case 'gray':
        return PdfColors.grey;
      case 'yellow':
        return PdfColors.yellow;
      case 'cyan':
        return PdfColors.cyan;
      case 'magenta':
      case 'purple':
        return PdfColors.purple;
      case 'orange':
        return PdfColors.orange;
      case 'pink':
        return PdfColors.pink;
      case 'brown':
        return PdfColors.brown;
      case 'lime':
        return PdfColors.lime;
      case 'teal':
        return PdfColors.teal;
      case 'indigo':
        return PdfColors.indigo;
      case 'navy':
        return PdfColors.blueGrey800;
      case 'maroon':
        return PdfColors.red800;
      case 'olive':
        return PdfColors.lime800;
      case 'aqua':
        return PdfColors.cyan;
      case 'fuchsia':
        return PdfColors.pink;
      case 'silver':
        return PdfColors.grey400;
      case 'transparent':
        return null;
      default:
        return null;
    }
  }

  static double? _parseLength(String value) {
    if (value.endsWith('px')) {
      return double.tryParse(value.replaceAll('px', ''));
    } else if (value.endsWith('pt')) {
      return double.tryParse(value.replaceAll('pt', ''));
    } else if (value.endsWith('em')) {
      // Assuming 1em = 12pt for simplicity if base not known,
      // but ideally this should be resolved later.
      // For now, let's treat it as a scale factor or fixed size.
      // Let's assume standard 16px (12pt) base?
      // Actually, let's just parse the number.
      return (double.tryParse(value.replaceAll('em', '')) ?? 1) * 12.0;
    } else if (value.endsWith('rem')) {
      return (double.tryParse(value.replaceAll('rem', '')) ?? 1) * 12.0;
    }
    return double.tryParse(value);
  }

  static FontWeight? _parseFontWeight(String value) {
    switch (value.toLowerCase()) {
      case 'bold':
      case '700':
        return FontWeight.bold;
      case 'normal':
      case '400':
        return FontWeight.normal;
      default:
        return null;
    }
  }

  static FontStyle? _parseFontStyle(String value) {
    switch (value.toLowerCase()) {
      case 'italic':
        return FontStyle.italic;
      case 'normal':
        return FontStyle.normal;
      default:
        return null;
    }
  }

  static TextDecoration? _parseTextDecoration(String value) {
    switch (value.toLowerCase()) {
      case 'underline':
        return TextDecoration.underline;
      case 'line-through':
        return TextDecoration.lineThrough;
      case 'overline':
        return TextDecoration.overline;
      case 'none':
        return TextDecoration.none;
      default:
        return null;
    }
  }

  static Display? _parseDisplay(String value) {
    switch (value.toLowerCase()) {
      case 'block':
        return Display.block;
      case 'inline':
        return Display.inline;
      case 'none':
        return Display.none;
      default:
        return null;
    }
  }

  static EdgeInsets? _parseEdgeInsets(String value) {
    final parts = value.split(' ').where((s) => s.isNotEmpty).toList();
    final values = parts.map((p) => _parseLength(p) ?? 0.0).toList();

    if (values.isEmpty) return null;

    if (values.length == 1) {
      return EdgeInsets.all(values[0]);
    } else if (values.length == 2) {
      return EdgeInsets.symmetric(vertical: values[0], horizontal: values[1]);
    } else if (values.length == 3) {
      // top, horizontal, bottom
      return EdgeInsets.only(
          top: values[0], left: values[1], right: values[1], bottom: values[2]);
    } else if (values.length == 4) {
      return EdgeInsets.fromLTRB(values[3], values[0], values[1], values[2]);
    }
    return null;
  }

  static Border? _parseBorder(String value) {
    // Simple parser for "1px solid black"
    final parts = value.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.length < 3) return null;

    final width = _parseLength(parts[0]) ?? 1.0;
    // style ignored for now, assuming solid
    final color = _parseColor(parts[2]) ?? PdfColors.black;

    return Border.all(width: width, color: color);
  }

  static TextAlign? _parseTextAlign(String value) {
    switch (value.toLowerCase()) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
        return TextAlign.center;
      case 'justify':
        return TextAlign.justify;
      default:
        return null;
    }
  }

  static ObjectFit? _parseObjectFit(String value) {
    switch (value.toLowerCase()) {
      case 'contain':
        return ObjectFit.contain;
      case 'cover':
        return ObjectFit.cover;
      case 'fill':
        return ObjectFit.fill;
      case 'none':
        return ObjectFit.none;
      case 'scale-down':
        return ObjectFit.scaleDown;
      default:
        return null;
    }
  }

  static VerticalAlign? _parseVerticalAlign(String value) {
    switch (value.toLowerCase()) {
      case 'top':
        return VerticalAlign.top;
      case 'middle':
        return VerticalAlign.middle;
      case 'bottom':
        return VerticalAlign.bottom;
      case 'baseline':
        return VerticalAlign.baseline;
      default:
        return null;
    }
  }
}
