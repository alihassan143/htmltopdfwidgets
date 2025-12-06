import 'package:pdf/pdf.dart';

extension ColorExtension on PdfColor {
  /// Parse either HEX (#RRGGBB or #RGB) or RGBA (rgba(r,g,b,a)) into PdfColor.
  static PdfColor? parse(String colorString) {
    colorString = colorString.trim();

    if (isHex(colorString)) {
      return hexToPdfColor(colorString);
    } else if (isRgba(colorString)) {
      return tryFromRgbaString(colorString);
    }
    return null; // Not a recognized format
  }

  /// Parse rgba(r,g,b,a) to PdfColor
  static PdfColor? tryFromRgbaString(String colorString) {
    final reg =
        RegExp(r'rgba\((\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d*\.?\d+)\s*\)');
    final match = reg.firstMatch(colorString);
    if (match == null) return null;

    final red = int.tryParse(match.group(1) ?? '');
    final green = int.tryParse(match.group(2) ?? '');
    final blue = int.tryParse(match.group(3) ?? '');
    final alpha = double.tryParse(match.group(4) ?? '');

    if (red == null || green == null || blue == null || alpha == null) {
      return null;
    }

    return PdfColor.fromInt(hexOfRGBA(red, green, blue, opacity: alpha));
  }

  /// Convert HEX (#RRGGBB or #RGB) to PdfColor
  static PdfColor hexToPdfColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 3) {
      hexColor = hexColor.split('').map((c) => '$c$c').join();
    }
    if (hexColor.length != 6) {
      throw ArgumentError('Invalid hex color format');
    }

    final red = int.parse(hexColor.substring(0, 2), radix: 16);
    final green = int.parse(hexColor.substring(2, 4), radix: 16);
    final blue = int.parse(hexColor.substring(4, 6), radix: 16);

    return PdfColor.fromInt((red << 16) | (green << 8) | blue);
  }
}

/// Convert RGBA values to a single int for PdfColor
int hexOfRGBA(int r, int g, int b, {double opacity = 1}) {
  r = r.clamp(0, 255);
  g = g.clamp(0, 255);
  b = b.clamp(0, 255);
  final a = (opacity.clamp(0, 1) * 255).toInt();

  return (a << 24) | (r << 16) | (g << 8) | b;
}

/// Check if a string is rgba format
bool isRgba(String color) {
  final rgbaRegex = RegExp(
      r"^rgba?\((\s*\d+\s*,){2}\s*\d+\s*,\s*\d*\.?\d+\s*\)$",
      caseSensitive: false);
  return rgbaRegex.hasMatch(color);
}

/// Check if a string is hex format (#RRGGBB or #RGB)
bool isHex(String color) {
  final hexRegex =
      RegExp(r"^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$", caseSensitive: false);
  return hexRegex.hasMatch(color);
}
