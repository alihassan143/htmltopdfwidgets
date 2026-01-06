import 'package:flutter/material.dart';

enum Display { block, inline, none }

/// Image fit mode, similar to CSS object-fit
enum ObjectFit { contain, cover, fill, fitWidth, fitHeight, none, scaleDown }

/// Vertical alignment for table cells
enum VerticalAlign { top, middle, bottom, baseline }

class CSSStyle {
  final Color? color;
  final Color? backgroundColor;
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
  final BorderSide? borderTop;
  final BorderSide? borderRight;
  final BorderSide? borderBottom;
  final BorderSide? borderLeft;
  final String? fontFamily;
  final TextAlign? textAlign;
  final ObjectFit? objectFit;
  final VerticalAlign? verticalAlign;
  final double? borderRadius;
  final bool? borderCollapse;
  final TextDirection? textDirection;

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
    );
  }

  /// Parses a CSS string into a CSSStyle object.
  static CSSStyle parse(String cssString) {
    if (cssString.isEmpty) return const CSSStyle();

    Color? color;
    Color? backgroundColor;
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

    final declarations = cssString.split(';');
    BorderSide? borderLeft;
    BorderSide? borderRight;
    BorderSide? borderTop;
    BorderSide? borderBottom;

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
          final b = _parseBorder(value);
          if (b != null) {
            borderTop = b.top;
            borderBottom = b.bottom;
            borderLeft = b.left;
            borderRight = b.right;
          }
          break;
        case 'border-left':
          borderLeft = _parseBorderSide(value);
          break;
        case 'border-right':
          borderRight = _parseBorderSide(value);
          break;
        case 'border-top':
          borderTop = _parseBorderSide(value);
          break;
        case 'border-bottom':
          borderBottom = _parseBorderSide(value);
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
      }
    }

    if (borderTop != null ||
        borderBottom != null ||
        borderLeft != null ||
        borderRight != null) {
      border = Border(
        top: borderTop ?? BorderSide.none,
        bottom: borderBottom ?? BorderSide.none,
        left: borderLeft ?? BorderSide.none,
        right: borderRight ?? BorderSide.none,
      );
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
    );
  }

  static Color? _parseColor(String value) {
    final trimmed = value.trim().toLowerCase();

    // Handle hex colors
    if (trimmed.startsWith('#')) {
      try {
        var hex = trimmed.substring(1);
        if (hex.length == 3) {
          hex = hex.split('').map((c) => '$c$c').join('');
        }
        if (hex.length == 6) {
          return Color(int.parse('0xFF$hex'));
        }
      } catch (e) {
        return null;
      }
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
        return Color.fromRGBO(r, g, b, a);
      }
    }

    // Handle named colors
    if (_cssColors.containsKey(trimmed)) {
      final hex = _cssColors[trimmed]!;
      return Color(int.parse('0xFF$hex'));
    }

    // Fallback for special case 'transparent'
    if (trimmed == 'transparent') {
      return Colors.transparent;
    }

    return null;
  }

  /// W3C CSS3 Extended Color Keywords (141 named colors).
  static const _cssColors = <String, String>{
    // Basic colors
    'black': '000000',
    'white': 'FFFFFF',
    'red': 'FF0000',
    'green': '008000',
    'blue': '0000FF',
    'yellow': 'FFFF00',
    'cyan': '00FFFF',
    'magenta': 'FF00FF',
    'aqua': '00FFFF',
    'fuchsia': 'FF00FF',
    'lime': '00FF00',
    'maroon': '800000',
    'navy': '000080',
    'olive': '808000',
    'purple': '800080',
    'silver': 'C0C0C0',
    'teal': '008080',
    // Gray variations
    'gray': '808080',
    'grey': '808080',
    'darkgray': 'A9A9A9',
    'darkgrey': 'A9A9A9',
    'dimgray': '696969',
    'dimgrey': '696969',
    'lightgray': 'D3D3D3',
    'lightgrey': 'D3D3D3',
    'gainsboro': 'DCDCDC',
    'slategray': '708090',
    'slategrey': '708090',
    'lightslategray': '778899',
    'lightslategrey': '778899',
    'darkslategray': '2F4F4F',
    'darkslategrey': '2F4F4F',
    // Reds
    'indianred': 'CD5C5C',
    'lightcoral': 'F08080',
    'salmon': 'FA8072',
    'darksalmon': 'E9967A',
    'lightsalmon': 'FFA07A',
    'crimson': 'DC143C',
    'firebrick': 'B22222',
    'darkred': '8B0000',
    // Oranges
    'coral': 'FF7F50',
    'tomato': 'FF6347',
    'orangered': 'FF4500',
    'darkorange': 'FF8C00',
    'orange': 'FFA500',
    // Yellows
    'gold': 'FFD700',
    'lightyellow': 'FFFFE0',
    'lemonchiffon': 'FFFACD',
    'lightgoldenrodyellow': 'FAFAD2',
    'papayawhip': 'FFEFD5',
    'moccasin': 'FFE4B5',
    'peachpuff': 'FFDAB9',
    'palegoldenrod': 'EEE8AA',
    'khaki': 'F0E68C',
    'darkkhaki': 'BDB76B',
    // Greens
    'lawngreen': '7CFC00',
    'chartreuse': '7FFF00',
    'limegreen': '32CD32',
    'forestgreen': '228B22',
    'darkgreen': '006400',
    'greenyellow': 'ADFF2F',
    'yellowgreen': '9ACD32',
    'springgreen': '00FF7F',
    'mediumspringgreen': '00FA9A',
    'lightgreen': '90EE90',
    'palegreen': '98FB98',
    'darkseagreen': '8FBC8F',
    'mediumseagreen': '3CB371',
    'seagreen': '2E8B57',
    'olivedrab': '6B8E23',
    'darkolivegreen': '556B2F',
    // Blues
    'lightcyan': 'E0FFFF',
    'paleturquoise': 'AFEEEE',
    'aquamarine': '7FFFD4',
    'turquoise': '40E0D0',
    'mediumturquoise': '48D1CC',
    'darkturquoise': '00CED1',
    'cadetblue': '5F9EA0',
    'steelblue': '4682B4',
    'lightsteelblue': 'B0C4DE',
    'powderblue': 'B0E0E6',
    'lightblue': 'ADD8E6',
    'skyblue': '87CEEB',
    'lightskyblue': '87CEFA',
    'deepskyblue': '00BFFF',
    'dodgerblue': '1E90FF',
    'cornflowerblue': '6495ED',
    'royalblue': '4169E1',
    'mediumblue': '0000CD',
    'darkblue': '00008B',
    'midnightblue': '191970',
    // Purples
    'lavender': 'E6E6FA',
    'thistle': 'D8BFD8',
    'plum': 'DDA0DD',
    'violet': 'EE82EE',
    'orchid': 'DA70D6',
    'mediumorchid': 'BA55D3',
    'mediumpurple': '9370DB',
    'rebeccapurple': '663399',
    'blueviolet': '8A2BE2',
    'darkviolet': '9400D3',
    'darkorchid': '9932CC',
    'darkmagenta': '8B008B',
    'indigo': '4B0082',
    'slateblue': '6A5ACD',
    'darkslateblue': '483D8B',
    'mediumslateblue': '7B68EE',
    // Pinks
    'pink': 'FFC0CB',
    'lightpink': 'FFB6C1',
    'hotpink': 'FF69B4',
    'deeppink': 'FF1493',
    'mediumvioletred': 'C71585',
    'palevioletred': 'DB7093',
    // Browns
    'cornsilk': 'FFF8DC',
    'blanchedalmond': 'FFEBCD',
    'bisque': 'FFE4C4',
    'navajowhite': 'FFDEAD',
    'wheat': 'F5DEB3',
    'burlywood': 'DEB887',
    'tan': 'D2B48C',
    'rosybrown': 'BC8F8F',
    'sandybrown': 'F4A460',
    'goldenrod': 'DAA520',
    'darkgoldenrod': 'B8860B',
    'peru': 'CD853F',
    'chocolate': 'D2691E',
    'saddlebrown': '8B4513',
    'sienna': 'A0522D',
    'brown': 'A52A2A',
    // Whites
    'snow': 'FFFAFA',
    'honeydew': 'F0FFF0',
    'mintcream': 'F5FFFA',
    'azure': 'F0FFFF',
    'aliceblue': 'F0F8FF',
    'ghostwhite': 'F8F8FF',
    'whitesmoke': 'F5F5F5',
    'seashell': 'FFF5EE',
    'beige': 'F5F5DC',
    'oldlace': 'FDF5E6',
    'floralwhite': 'FFFAF0',
    'ivory': 'FFFFF0',
    'antiquewhite': 'FAEBD7',
    'linen': 'FAF0E6',
    'lavenderblush': 'FFF0F5',
    'mistyrose': 'FFE4E1',
  };

  static double? _parseLength(String value) {
    if (value.endsWith('px')) {
      return double.tryParse(value.replaceAll('px', ''));
    } else if (value.endsWith('pt')) {
      return double.tryParse(value.replaceAll('pt', ''));
    } else if (value.endsWith('em')) {
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
      return EdgeInsets.only(
          top: values[0], left: values[1], right: values[1], bottom: values[2]);
    } else if (values.length == 4) {
      return EdgeInsets.fromLTRB(values[3], values[0], values[1], values[2]);
    }
    return null;
  }

  static Border? _parseBorder(String value) {
    final side = _parseBorderSide(value);
    if (side == null) return null;
    return Border.all(width: side.width, color: side.color);
  }

  static BorderSide? _parseBorderSide(String value) {
    final parts = value.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.length < 3) return null;

    // e.g. "1px solid black" or "5px solid #ccc"
    final width = _parseLength(parts[0]) ?? 1.0;
    // parts[1] is style (solid, dashed), currently ignored/assumed solid
    final color = _parseColor(parts[2]) ?? Colors.black;

    return BorderSide(width: width, color: color);
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
