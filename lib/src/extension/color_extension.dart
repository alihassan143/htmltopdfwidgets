import 'package:pdf/pdf.dart';

// Define an extension for PdfColor to add additional functionality.
extension ColorExtension on PdfColor {
  /// Try to parse the `rgba(red, green, blue, alpha)` from the string.
  static PdfColor? tryFromRgbaString(String colorString) {
    final reg = RegExp(r'rgba\((\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)');
    final match = reg.firstMatch(colorString);

    if (match == null) {
      return null; // Return null if the provided string does not match the expected format.
    }

    if (match.groupCount < 4) {
      return null; // Return null if there are not enough color components.
    }

    final redStr = match.group(1);
    final greenStr = match.group(2);
    final blueStr = match.group(3);
    final alphaStr = match.group(4);

    // Attempt to parse color components as integers.
    final red = redStr != null ? int.tryParse(redStr) : null;
    final green = greenStr != null ? int.tryParse(greenStr) : null;
    final blue = blueStr != null ? int.tryParse(blueStr) : null;
    final alpha = alphaStr != null ? int.tryParse(alphaStr) : null;

    // If any component parsing fails, return null.
    if (red == null || green == null || blue == null || alpha == null) {
      return null;
    }

    // Create a PdfColor from the parsed RGBA values.
    return PdfColor.fromInt(
        hexOfRGBA(red, green, blue, opacity: alpha.toDouble()));
  }

  // Convert PdfColor to an RGBA string format.
  String toRgbaString() {
    return 'rgba($red, $green, $blue, $alpha)';
  }

  static PdfColor hexToPdfColor(String hexColor) {
    // Remove the leading '#' if it exists
    hexColor = hexColor.replaceAll('#', '');

    // Ensure the hex string is in the correct format (6 characters long)
    if (hexColor.length == 3) {
      hexColor = hexColor.split('').map((char) => '$char$char').join();
    }

    if (hexColor.length != 6) {
      throw ArgumentError('Invalid hex color format');
    }

    // Convert hex string to integer values for RGB
    final int red = int.parse(hexColor.substring(0, 2), radix: 16);
    final int green = int.parse(hexColor.substring(2, 4), radix: 16);
    final int blue = int.parse(hexColor.substring(4, 6), radix: 16);

    // Return a PdfColor object using the RGB values (normalized to 0-1)
    return PdfColor.fromInt((red << 16) | (green << 8) | blue);
  }
}

// Function to calculate the hex representation of an RGBA color.
int hexOfRGBA(int r, int g, int b, {double opacity = 1}) {
  // Ensure that color values and opacity are within valid ranges.
  r = (r < 0) ? -r : r;
  g = (g < 0) ? -g : g;
  b = (b < 0) ? -b : b;
  opacity = (opacity < 0) ? -opacity : opacity;
  opacity = (opacity > 1) ? 255 : opacity * 255;
  r = (r > 255) ? 255 : r;
  g = (g > 255) ? 255 : g;
  b = (b > 255) ? 255 : b;
  int a = opacity.toInt();

  // Calculate and return the hex representation of the color.
  return int.parse(
      '0x${a.toRadixString(16)}${r.toRadixString(16)}${g.toRadixString(16)}${b.toRadixString(16)}');
}

bool isRgba(String color) {
  // Regular expression to check if the color is in 'rgba' format
  final rgbaRegex = RegExp(r"^rgba?\((\s*\d+\s*,){2,3}\s*\d+(\.\d+)?\s*\)$",
      caseSensitive: false);
  return rgbaRegex.hasMatch(color);
}

bool isHex(String color) {
  // Regular expression to check if the color is in hex format (#RRGGBB or #RGB)
  final hexRegex =
      RegExp(r"^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$", caseSensitive: false);
  return hexRegex.hasMatch(color);
}
