import 'dart:typed_data';

/// Internal PDF object representation.
class PdfObject {
  final int objNum;
  final int offset;
  String content = '';
  String? stream;

  PdfObject(this.objNum, this.offset);
}

/// Graphics state for PDF rendering.
class PdfGraphicsState {
  PdfMatrix ctm = PdfMatrix.identity();
  PdfMatrix textMatrix = PdfMatrix.identity();
  PdfMatrix textLineMatrix = PdfMatrix.identity();

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
  double charSpacing = 0;
  double wordSpacing = 0;

  PdfGraphicsState clone() {
    return PdfGraphicsState()
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
      ..textRise = textRise
      ..charSpacing = charSpacing
      ..wordSpacing = wordSpacing;
  }
}

/// 2D Affine Transform Matrix.
class PdfMatrix {
  final double a, b, c, d, e, f;

  const PdfMatrix(this.a, this.b, this.c, this.d, this.e, this.f);

  factory PdfMatrix.identity() => const PdfMatrix(1, 0, 0, 1, 0, 0);

  PdfMatrix multiply(PdfMatrix other) {
    return PdfMatrix(
      a * other.a + b * other.c,
      a * other.b + b * other.d,
      c * other.a + d * other.c,
      c * other.b + d * other.d,
      e * other.a + f * other.c + other.e,
      e * other.b + f * other.d + other.f,
    );
  }

  PdfMatrix clone() => PdfMatrix(a, b, c, d, e, f);

  /// Transform point (x, y) -> (x', y')
  List<double> transform(double x, double y) {
    return [a * x + c * y + e, b * x + d * y + f];
  }

  /// Transform vector (ignore translation)
  List<double> transformVec(double x, double y) {
    return [a * x + c * y, b * x + d * y];
  }

  /// Get scale factor (approximate)
  double get scale => (a.abs() + d.abs()) / 2;
}

/// Path construction command.
class PdfPathCommand {
  final String type;
  final List<double> nums;

  const PdfPathCommand(this.type, this.nums);

  factory PdfPathCommand.moveTo(double x, double y) =>
      PdfPathCommand('move', [x, y]);
  factory PdfPathCommand.lineTo(double x, double y) =>
      PdfPathCommand('line', [x, y]);
  factory PdfPathCommand.cubic(
          double x1, double y1, double x2, double y2, double x3, double y3) =>
      PdfPathCommand('cubic', [x1, y1, x2, y2, x3, y3]);
  factory PdfPathCommand.rect(double x, double y, double w, double h) =>
      PdfPathCommand('rect', [x, y, w, h]);
  factory PdfPathCommand.close() => const PdfPathCommand('close', []);
}

/// Represents a graphic line segment (for tables/underlines).
class PdfGraphicLine {
  final double x1, y1, x2, y2;
  final double lineWidth;
  final int colorR, colorG, colorB;

  const PdfGraphicLine(
    this.x1,
    this.y1,
    this.x2,
    this.y2, {
    this.lineWidth = 1,
    this.colorR = 0,
    this.colorG = 0,
    this.colorB = 0,
  });

  bool get isHorizontal => (y1 - y2).abs() < 0.5;
  bool get isVertical => (x1 - x2).abs() < 0.5;

  double get length {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return (dx * dx + dy * dy);
  }

  double get minX => x1 < x2 ? x1 : x2;
  double get maxX => x1 > x2 ? x1 : x2;
  double get minY => y1 < y2 ? y1 : y2;
  double get maxY => y1 > y2 ? y1 : y2;
}

/// Abstract base item for page layout.
abstract class PdfPageItem {
  double x;
  double y;
  PdfPageItem(this.x, this.y);
}

/// Represents a simplified text line with position and style.
class PdfTextLine extends PdfPageItem {
  final String text;
  final String font;
  final double size;
  final double colorR;
  final double colorG;
  final double colorB;

  // Advanced features
  final double textRise;
  bool isUnderline = false;
  bool isStrikethrough = false;
  bool isBold = false;
  bool isItalic = false;

  // Font encoding info
  final PdfFontInfo? fontInfo;

  PdfTextLine({
    required this.text,
    required double x,
    required double y,
    required this.font,
    required this.size,
    required this.colorR,
    required this.colorG,
    required this.colorB,
    this.textRise = 0,
    this.fontInfo,
  }) : super(x, y);

  double get width => text.length * size * 0.5;
}

/// Represents an image on the page.
class PdfImageItem extends PdfPageItem {
  final Uint8List bytes;
  final double width;
  final double height;
  final String extension;
  final String filter;

  PdfImageItem({
    required this.bytes,
    required double x,
    required double y,
    required this.width,
    required this.height,
    required this.extension,
    this.filter = 'Unknown',
  }) : super(x, y);
}

/// Internal font info with encoding support.
class PdfFontInfo {
  final String name;
  final String baseFont;
  final bool isBold;
  final bool isItalic;
  final String? encoding;
  final Map<int, int>? toUnicode;
  final bool isEmbedded;
  final String subtype; // Type1, TrueType, Type0, CIDFontType2

  PdfFontInfo({
    required this.name,
    required this.baseFont,
    required this.isBold,
    required this.isItalic,
    this.encoding,
    this.toUnicode,
    this.isEmbedded = false,
    this.subtype = 'Type1',
  });

  /// Decodes a character code to Unicode.
  int decodeChar(int code) {
    if (toUnicode != null && toUnicode!.containsKey(code)) {
      return toUnicode![code]!;
    }
    // Apply standard encoding
    if (encoding == 'WinAnsiEncoding') {
      return _winAnsiToUnicode(code);
    }
    return code;
  }

  /// WinAnsi to Unicode mapping for extended characters.
  static int _winAnsiToUnicode(int code) {
    const map = <int, int>{
      0x80: 0x20AC, // Euro
      0x82: 0x201A, // Single low quote
      0x83: 0x0192, // Florin
      0x84: 0x201E, // Double low quote
      0x85: 0x2026, // Ellipsis
      0x86: 0x2020, // Dagger
      0x87: 0x2021, // Double dagger
      0x88: 0x02C6, // Circumflex
      0x89: 0x2030, // Per mille
      0x8A: 0x0160, // S caron
      0x8B: 0x2039, // Left single guillemet
      0x8C: 0x0152, // OE ligature
      0x8E: 0x017D, // Z caron
      0x91: 0x2018, // Left single quote
      0x92: 0x2019, // Right single quote
      0x93: 0x201C, // Left double quote
      0x94: 0x201D, // Right double quote
      0x95: 0x2022, // Bullet
      0x96: 0x2013, // En dash
      0x97: 0x2014, // Em dash
      0x98: 0x02DC, // Tilde
      0x99: 0x2122, // Trademark
      0x9A: 0x0161, // s caron
      0x9B: 0x203A, // Right single guillemet
      0x9C: 0x0153, // oe ligature
      0x9E: 0x017E, // z caron
      0x9F: 0x0178, // Y diaeresis
    };
    return map[code] ?? code;
  }
}

/// Internal XObject info (images).
class PdfXObjectInfo {
  final String name;
  final int objRef;
  final int width;
  final int height;
  final String filter;
  final Uint8List? bytes;
  final String? subtype;
  final String? colorSpace;
  final int bitsPerComponent;

  PdfXObjectInfo({
    required this.name,
    required this.objRef,
    required this.width,
    required this.height,
    required this.filter,
    this.bytes,
    this.subtype,
    this.colorSpace,
    this.bitsPerComponent = 8,
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

/// Represents a detected table cell.
class PdfTableCell {
  final double x;
  final double y;
  final double width;
  final double height;
  final List<PdfTextLine> textLines;
  final String? backgroundColor;
  final bool hasTopBorder;
  final bool hasBottomBorder;
  final bool hasLeftBorder;
  final bool hasRightBorder;

  PdfTableCell({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.textLines,
    this.backgroundColor,
    this.hasTopBorder = false,
    this.hasBottomBorder = false,
    this.hasLeftBorder = false,
    this.hasRightBorder = false,
  });
}

/// Represents a detected table.
class PdfDetectedTable {
  final double x;
  final double y;
  final double width;
  final double height;
  final List<List<PdfTableCell>> rows;

  PdfDetectedTable({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rows,
  });

  int get rowCount => rows.length;
  int get colCount => rows.isEmpty ? 0 : rows.first.length;
}

/// CMap for character code to Unicode mapping.
class PdfCMap {
  final Map<int, int> charToUnicode = {};
  final Map<int, String> charToString = {};

  /// Parses a ToUnicode CMap stream.
  void parseCMap(String content) {
    // Parse beginbfchar ... endbfchar sections
    final bfcharRegex =
        RegExp(r'beginbfchar\s*(.*?)\s*endbfchar', dotAll: true);
    for (final match in bfcharRegex.allMatches(content)) {
      _parseBfChar(match.group(1)!);
    }

    // Parse beginbfrange ... endbfrange sections
    final bfrangeRegex =
        RegExp(r'beginbfrange\s*(.*?)\s*endbfrange', dotAll: true);
    for (final match in bfrangeRegex.allMatches(content)) {
      _parseBfRange(match.group(1)!);
    }
  }

  void _parseBfChar(String content) {
    // Format: <srcCode> <dstString>
    final pairRegex = RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>');
    for (final match in pairRegex.allMatches(content)) {
      final srcCode = int.parse(match.group(1)!, radix: 16);
      final dstHex = match.group(2)!;
      if (dstHex.length == 4) {
        charToUnicode[srcCode] = int.parse(dstHex, radix: 16);
      } else {
        // Multi-character mapping
        final sb = StringBuffer();
        for (var i = 0; i < dstHex.length; i += 4) {
          final end = i + 4 < dstHex.length ? i + 4 : dstHex.length;
          sb.writeCharCode(int.parse(dstHex.substring(i, end), radix: 16));
        }
        charToString[srcCode] = sb.toString();
      }
    }
  }

  void _parseBfRange(String content) {
    // Format: <start> <end> <dstStart> or <start> <end> [<dst1> <dst2> ...]
    final rangeRegex = RegExp(
        r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(<[0-9A-Fa-f]+>|\[.+?\])');
    for (final match in rangeRegex.allMatches(content)) {
      final start = int.parse(match.group(1)!, radix: 16);
      final end = int.parse(match.group(2)!, radix: 16);
      final dst = match.group(3)!;

      if (dst.startsWith('[')) {
        // Array of destinations
        final dstCodes = RegExp(r'<([0-9A-Fa-f]+)>')
            .allMatches(dst)
            .map((m) => int.parse(m.group(1)!, radix: 16))
            .toList();
        for (var i = 0; i <= end - start && i < dstCodes.length; i++) {
          charToUnicode[start + i] = dstCodes[i];
        }
      } else {
        // Single start destination, increment for range
        var dstCode = int.parse(dst.substring(1, dst.length - 1), radix: 16);
        for (var i = start; i <= end; i++) {
          charToUnicode[i] = dstCode++;
        }
      }
    }
  }

  /// Decodes a character code.
  String decode(int code) {
    if (charToString.containsKey(code)) {
      return charToString[code]!;
    }
    if (charToUnicode.containsKey(code)) {
      return String.fromCharCode(charToUnicode[code]!);
    }
    return String.fromCharCode(code);
  }
}
