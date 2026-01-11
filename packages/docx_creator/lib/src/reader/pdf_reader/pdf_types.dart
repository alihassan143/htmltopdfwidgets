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
  double horizontalScaling = 100; // Tz, percentage
  double leading = 0; // TL

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
      ..wordSpacing = wordSpacing
      ..horizontalScaling = horizontalScaling
      ..leading = leading;
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
  PdfMatrix? matrix;
  double rotation;

  PdfPageItem(this.x, this.y, {this.matrix, this.rotation = 0});
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
  final double width;

  PdfTextLine({
    required this.text,
    required double x,
    required double y,
    required this.font,
    required this.size,
    required this.colorR,
    required this.colorG,
    required this.colorB,
    required this.width,
    this.textRise = 0,
    this.fontInfo,
    PdfMatrix? matrix,
    double rotation = 0,
  }) : super(x, y, matrix: matrix, rotation: rotation);
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
    PdfMatrix? matrix,
    double rotation = 0,
  }) : super(x, y, matrix: matrix, rotation: rotation);
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
  final Map<int, int>? differences; // Custom encoding differences
  final String? baseEncoding; // Base encoding for differences

  // Font metrics for layout analysis
  final List<num>? widths;
  final int firstChar;
  final int lastChar;
  final int missingWidth;

  PdfFontInfo({
    required this.name,
    required this.baseFont,
    required this.isBold,
    required this.isItalic,
    this.encoding,
    this.toUnicode,
    this.isEmbedded = false,
    this.subtype = 'Type1',
    this.differences,
    this.baseEncoding,
    this.widths,
    this.firstChar = 0,
    this.lastChar = 255,
    this.missingWidth = 0,
  });

  /// Gets character width in text space units.
  double getCharWidth(int code, double fontSize) {
    if (widths != null && code >= firstChar && code <= lastChar) {
      final index = code - firstChar;
      if (index < widths!.length) {
        return widths![index].toDouble() / 1000.0 * fontSize;
      }
    }
    // Fallback or missing width
    return missingWidth > 0
        ? missingWidth.toDouble() / 1000.0 * fontSize
        : fontSize * 0.5;
  }

  /// Decodes a character code to Unicode.
  int decodeChar(int code) {
    // First check ToUnicode CMap (highest priority)
    if (toUnicode != null && toUnicode!.containsKey(code)) {
      return toUnicode![code]!;
    }

    // Check differences array
    if (differences != null && differences!.containsKey(code)) {
      return differences![code]!;
    }

    // Handle Symbol font
    if (_isSymbolFont(baseFont)) {
      return _symbolToUnicode(code);
    }

    // Handle ZapfDingbats font
    if (_isZapfDingbatsFont(baseFont)) {
      return _zapfDingbatsToUnicode(code);
    }

    // Apply standard encoding based on encoding name or Base14 default
    final enc = encoding ?? baseEncoding ?? _getBase14DefaultEncoding(baseFont);
    if (enc != null) {
      switch (enc) {
        case 'WinAnsiEncoding':
          return _winAnsiToUnicode(code);
        case 'MacRomanEncoding':
          return _macRomanToUnicode(code);
        case 'StandardEncoding':
          return _standardEncodingToUnicode(code);
        case 'MacExpertEncoding':
          // Expert encoding is mostly the same as Standard for basic chars
          return _standardEncodingToUnicode(code);
        case 'Identity-H':
        case 'Identity-V':
          // Identity encoding - code is already Unicode
          return code;
      }
    }

    // For ASCII range, return as-is
    if (code >= 0x20 && code <= 0x7E) {
      return code;
    }

    return code;
  }

  /// Check if font is Symbol
  static bool _isSymbolFont(String fontName) {
    final lowerName = fontName.toLowerCase();
    return lowerName.contains('symbol');
  }

  /// Check if font is ZapfDingbats
  static bool _isZapfDingbatsFont(String fontName) {
    final lowerName = fontName.toLowerCase();
    return lowerName.contains('zapfdingbats') || lowerName.contains('dingbats');
  }

  /// Get default encoding for Base14 fonts
  static String? _getBase14DefaultEncoding(String fontName) {
    // Base14 fonts use StandardEncoding by default (except Symbol/ZapfDingbats)
    final base14 = [
      'Courier',
      'Courier-Bold',
      'Courier-Oblique',
      'Courier-BoldOblique',
      'Helvetica',
      'Helvetica-Bold',
      'Helvetica-Oblique',
      'Helvetica-BoldOblique',
      'Times-Roman',
      'Times-Bold',
      'Times-Italic',
      'Times-BoldItalic',
    ];

    for (final name in base14) {
      if (fontName.contains(name)) {
        return 'StandardEncoding';
      }
    }
    return null;
  }

  /// Symbol font encoding to Unicode
  static int _symbolToUnicode(int code) {
    const map = <int, int>{
      0x22: 0x2200, // forall
      0x24: 0x2203, // thereexists
      0x27: 0x220B, // suchthat
      0x2A: 0x2217, // asteriskmath
      0x2D: 0x2212, // minus
      0x40: 0x2245, // congruent
      0x41: 0x0391, // Alpha
      0x42: 0x0392, // Beta
      0x43: 0x03A7, // Chi
      0x44: 0x0394, // Delta
      0x45: 0x0395, // Epsilon
      0x46: 0x03A6, // Phi
      0x47: 0x0393, // Gamma
      0x48: 0x0397, // Eta
      0x49: 0x0399, // Iota
      0x4B: 0x039A, // Kappa
      0x4C: 0x039B, // Lambda
      0x4D: 0x039C, // Mu
      0x4E: 0x039D, // Nu
      0x4F: 0x039F, // Omicron
      0x50: 0x03A0, // Pi
      0x51: 0x0398, // Theta
      0x52: 0x03A1, // Rho
      0x53: 0x03A3, // Sigma
      0x54: 0x03A4, // Tau
      0x55: 0x03A5, // Upsilon
      0x57: 0x03A9, // Omega
      0x58: 0x039E, // Xi
      0x59: 0x03A8, // Psi
      0x5A: 0x0396, // Zeta
      0x5C: 0x2234, // therefore
      0x5E: 0x22A5, // perpendicular
      0x60: 0xF8E5, // radicalex (Private Use)
      0x61: 0x03B1, // alpha
      0x62: 0x03B2, // beta
      0x63: 0x03C7, // chi
      0x64: 0x03B4, // delta
      0x65: 0x03B5, // epsilon
      0x66: 0x03C6, // phi
      0x67: 0x03B3, // gamma
      0x68: 0x03B7, // eta
      0x69: 0x03B9, // iota
      0x6B: 0x03BA, // kappa
      0x6C: 0x03BB, // lambda
      0x6D: 0x03BC, // mu
      0x6E: 0x03BD, // nu
      0x6F: 0x03BF, // omicron
      0x70: 0x03C0, // pi
      0x71: 0x03B8, // theta
      0x72: 0x03C1, // rho
      0x73: 0x03C3, // sigma
      0x74: 0x03C4, // tau
      0x75: 0x03C5, // upsilon
      0x77: 0x03C9, // omega
      0x78: 0x03BE, // xi
      0x79: 0x03C8, // psi
      0x7A: 0x03B6, // zeta
      0xA0: 0x20AC, // Euro
      0xA1: 0x03D2, // Upsilon1
      0xA2: 0x2032, // minute
      0xA3: 0x2264, // lessequal
      0xA4: 0x2044, // fraction
      0xA5: 0x221E, // infinity
      0xAA: 0x2194, // arrowboth
      0xAB: 0x2190, // arrowleft
      0xAC: 0x2191, // arrowup
      0xAD: 0x2192, // arrowright
      0xAE: 0x2193, // arrowdown
      0xB2: 0x2033, // second
      0xB3: 0x2265, // greaterequal
      0xB4: 0x00D7, // multiply
      0xB7: 0x2022, // bullet
      0xB8: 0x00F7, // divide
      0xB9: 0x2260, // notequal
      0xBA: 0x2261, // equivalence
      0xBB: 0x2248, // approxequal
      0xBC: 0x2026, // ellipsis
      0xC0: 0x2135, // aleph
      0xC1: 0x2111, // Ifraktur
      0xC2: 0x211C, // Rfraktur
      0xC3: 0x2118, // weierstrass
      0xC4: 0x2297, // circlemultiply
      0xC5: 0x2295, // circleplus
      0xC6: 0x2205, // emptyset
      0xC7: 0x2229, // intersection
      0xC8: 0x222A, // union
      0xC9: 0x2283, // propersuperset
      0xCA: 0x2287, // reflexsuperset
      0xCB: 0x2284, // notsubset
      0xCC: 0x2282, // propersubset
      0xCD: 0x2286, // reflexsubset
      0xCE: 0x2208, // element
      0xCF: 0x2209, // notelement
      0xD0: 0x2220, // angle
      0xD1: 0x2207, // gradient
      0xD5: 0x220F, // product
      0xD6: 0x221A, // radical
      0xD7: 0x22C5, // dotmath
      0xD8: 0x00AC, // logicalnot
      0xD9: 0x2227, // logicaland
      0xDA: 0x2228, // logicalor
      0xDB: 0x21D4, // arrowdblboth
      0xDC: 0x21D0, // arrowdblleft
      0xDD: 0x21D1, // arrowdblup
      0xDE: 0x21D2, // arrowdblright
      0xDF: 0x21D3, // arrowdbldown
      0xE0: 0x25CA, // lozenge
      0xE5: 0x2211, // summation
      0xF1: 0x222B, // integral
    };
    return map[code] ?? code;
  }

  /// ZapfDingbats encoding to Unicode
  static int _zapfDingbatsToUnicode(int code) {
    const map = <int, int>{
      0x21: 0x2701, // upper blade scissors
      0x22: 0x2702, // black scissors
      0x23: 0x2703, // lower blade scissors
      0x24: 0x2704, // white scissors
      0x25: 0x260E, // black telephone
      0x26: 0x2706, // telephone location sign
      0x27: 0x2707, // tape drive
      0x28: 0x2708, // airplane
      0x29: 0x2709, // envelope
      0x2A: 0x261B, // black right pointing index
      0x2B: 0x261E, // white right pointing index
      0x2C: 0x270C, // victory hand
      0x2D: 0x270D, // writing hand
      0x2E: 0x270E, // lower right pencil
      0x2F: 0x270F, // pencil
      0x30: 0x2710, // upper right pencil
      0x31: 0x2711, // white nib
      0x32: 0x2712, // black nib
      0x33: 0x2713, // check mark
      0x34: 0x2714, // heavy check mark
      0x35: 0x2715, // multiplication x
      0x36: 0x2716, // heavy multiplication x
      0x37: 0x2717, // ballot x
      0x38: 0x2718, // heavy ballot x
      0x39: 0x2719, // outlined greek cross
      0x3A: 0x271A, // heavy greek cross
      0x3B: 0x271B, // open center cross
      0x3C: 0x271C, // heavy open center cross
      0x3D: 0x271D, // latin cross
      0x3E: 0x271E, // shadowed white latin cross
      0x3F: 0x271F, // outlined latin cross
      0x40: 0x2720, // maltese cross
      0x41: 0x2721, // star of david
      0x42: 0x2722, // four teardrop-spoked asterisk
      0x43: 0x2723, // four balloon-spoked asterisk
      0x44: 0x2724, // heavy four balloon-spoked asterisk
      0x45: 0x2725, // four club-spoked asterisk
      0x46: 0x2726, // black four pointed star
      0x47: 0x2727, // white four pointed star
      0x48: 0x2605, // black star
      0x49: 0x2729, // stress outlined white star
      0x4A: 0x272A, // circled white star
      0x4B: 0x272B, // open center black star
      0x4C: 0x272C, // black center white star
      0x4D: 0x272D, // outlined black star
      0x4E: 0x272E, // heavy outlined black star
      0x4F: 0x272F, // pinwheel star
      0x50: 0x2730, // shadowed white star
      0x51: 0x2731, // heavy asterisk
      0x52: 0x2732, // open center asterisk
      0x53: 0x2733, // eight spoked asterisk
      0x54: 0x2734, // eight pointed black star
      0x55: 0x2735, // eight pointed pinwheel star
      0x56: 0x2736, // six pointed black star
      0x57: 0x2737, // eight pointed rectilinear black star
      0x58: 0x2738, // heavy eight pointed rectilinear black star
      0x59: 0x2739, // twelve pointed black star
      0x5A: 0x273A, // sixteen pointed asterisk
      0x5B: 0x273B, // teardrop-spoked asterisk
      0x5C: 0x273C, // open center teardrop-spoked asterisk
      0x5D: 0x273D, // heavy teardrop-spoked asterisk
      0x5E: 0x273E, // six petalled black and white florette
      0x5F: 0x273F, // black florette
      0x60: 0x2740, // white florette
      0x61: 0x2741, // eight petalled outlined black florette
      0x62: 0x2742, // circled open center eight pointed star
      0x63: 0x2743, // heavy teardrop-spoked pinwheel asterisk
      0x64: 0x2744, // snowflake
      0x65: 0x2745, // tight trifoliate snowflake
      0x66: 0x2746, // heavy chevron snowflake
      0x67: 0x2747, // sparkle
      0x68: 0x2748, // heavy sparkle
      0x69: 0x2749, // balloon-spoked asterisk
      0x6A: 0x274A, // eight teardrop-spoked propeller asterisk
      0x6B: 0x274B, // heavy eight teardrop-spoked propeller asterisk
      0x6C: 0x25CF, // black circle
      0x6D: 0x274D, // shadowed white circle
      0x6E: 0x25A0, // black square
      0x6F: 0x274F, // lower right drop-shadowed white square
      0x70: 0x2750, // upper right drop-shadowed white square
      0x71: 0x2751, // lower right shadowed white square
      0x72: 0x2752, // upper right shadowed white square
      0x73: 0x25B2, // black up-pointing triangle
      0x74: 0x25BC, // black down-pointing triangle
      0x75: 0x25C6, // black diamond
      0x76: 0x2756, // black diamond minus white x
      0x77: 0x25D7, // right half black circle
      0x78: 0x2758, // light vertical bar
      0x79: 0x2759, // medium vertical bar
      0x7A: 0x275A, // heavy vertical bar
      0x7B: 0x275B, // heavy single turned comma quotation mark ornament
      0x7C: 0x275C, // heavy single comma quotation mark ornament
      0x7D: 0x275D, // heavy double turned comma quotation mark ornament
      0x7E: 0x275E, // heavy double comma quotation mark ornament
      // Numbers for enclosed numerals (0-9)
      0xAC: 0x2776, // dingbat negative circled digit one
      0xAD: 0x2777, 0xAE: 0x2778, 0xAF: 0x2779, 0xB0: 0x277A,
      0xB1: 0x277B, 0xB2: 0x277C, 0xB3: 0x277D, 0xB4: 0x277E, 0xB5: 0x277F,
    };
    return map[code] ?? code;
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

  /// MacRoman to Unicode mapping for extended characters.
  static int _macRomanToUnicode(int code) {
    const map = <int, int>{
      0x80: 0x00C4, // Adieresis
      0x81: 0x00C5, // Aring
      0x82: 0x00C7, // Ccedilla
      0x83: 0x00C9, // Eacute
      0x84: 0x00D1, // Ntilde
      0x85: 0x00D6, // Odieresis
      0x86: 0x00DC, // Udieresis
      0x87: 0x00E1, // aacute
      0x88: 0x00E0, // agrave
      0x89: 0x00E2, // acircumflex
      0x8A: 0x00E4, // adieresis
      0x8B: 0x00E3, // atilde
      0x8C: 0x00E5, // aring
      0x8D: 0x00E7, // ccedilla
      0x8E: 0x00E9, // eacute
      0x8F: 0x00E8, // egrave
      0x90: 0x00EA, // ecircumflex
      0x91: 0x00EB, // edieresis
      0x92: 0x00ED, // iacute
      0x93: 0x00EC, // igrave
      0x94: 0x00EE, // icircumflex
      0x95: 0x00EF, // idieresis
      0x96: 0x00F1, // ntilde
      0x97: 0x00F3, // oacute
      0x98: 0x00F2, // ograve
      0x99: 0x00F4, // ocircumflex
      0x9A: 0x00F6, // odieresis
      0x9B: 0x00F5, // otilde
      0x9C: 0x00FA, // uacute
      0x9D: 0x00F9, // ugrave
      0x9E: 0x00FB, // ucircumflex
      0x9F: 0x00FC, // udieresis
      0xA0: 0x2020, // dagger
      0xA1: 0x00B0, // degree
      0xA2: 0x00A2, // cent
      0xA3: 0x00A3, // sterling
      0xA4: 0x00A7, // section
      0xA5: 0x2022, // bullet
      0xA6: 0x00B6, // paragraph
      0xA7: 0x00DF, // germandbls
      0xA8: 0x00AE, // registered
      0xA9: 0x00A9, // copyright
      0xAA: 0x2122, // trademark
      0xAB: 0x00B4, // acute
      0xAC: 0x00A8, // dieresis
      0xAD: 0x2260, // notequal
      0xAE: 0x00C6, // AE
      0xAF: 0x00D8, // Oslash
      0xB0: 0x221E, // infinity
      0xB1: 0x00B1, // plusminus
      0xB2: 0x2264, // lessequal
      0xB3: 0x2265, // greaterequal
      0xB4: 0x00A5, // yen
      0xB5: 0x00B5, // mu
      0xD0: 0x2013, // endash
      0xD1: 0x2014, // emdash
      0xD2: 0x201C, // quotedblleft
      0xD3: 0x201D, // quotedblright
      0xD4: 0x2018, // quoteleft
      0xD5: 0x2019, // quoteright
      0xD6: 0x00F7, // divide
      0xD8: 0x00FF, // ydieresis
      0xE0: 0x2021, // daggerdbl
      0xE1: 0x00B7, // periodcentered
      0xE2: 0x201A, // quotesinglbase
      0xE3: 0x201E, // quotedblbase
      0xE4: 0x2030, // perthousand
    };
    return map[code] ?? code;
  }

  /// Standard Encoding to Unicode mapping.
  static int _standardEncodingToUnicode(int code) {
    const map = <int, int>{
      0x27: 0x2019, // quoteright
      0x60: 0x2018, // quoteleft
      0xA1: 0x00A1, // exclamdown
      0xA2: 0x00A2, // cent
      0xA3: 0x00A3, // sterling
      0xA4: 0x2044, // fraction
      0xA5: 0x00A5, // yen
      0xA6: 0x0192, // florin
      0xA7: 0x00A7, // section
      0xA8: 0x00A4, // currency
      0xA9: 0x0027, // quotesingle
      0xAA: 0x201C, // quotedblleft
      0xAB: 0x00AB, // guillemotleft
      0xAC: 0x2039, // guilsinglleft
      0xAD: 0x203A, // guilsinglright
      0xAE: 0xFB01, // fi
      0xAF: 0xFB02, // fl
      0xB1: 0x2013, // endash
      0xB2: 0x2020, // dagger
      0xB3: 0x2021, // daggerdbl
      0xB4: 0x00B7, // periodcentered
      0xB6: 0x00B6, // paragraph
      0xB7: 0x2022, // bullet
      0xB8: 0x201A, // quotesinglbase
      0xB9: 0x201E, // quotedblbase
      0xBA: 0x201D, // quotedblright
      0xBB: 0x00BB, // guillemotright
      0xBC: 0x2026, // ellipsis
      0xBD: 0x2030, // perthousand
      0xBF: 0x00BF, // questiondown
      0xC1: 0x0060, // grave
      0xC2: 0x00B4, // acute
      0xC3: 0x02C6, // circumflex
      0xC4: 0x02DC, // tilde
      0xC5: 0x00AF, // macron
      0xC6: 0x02D8, // breve
      0xC7: 0x02D9, // dotaccent
      0xC8: 0x00A8, // dieresis
      0xCA: 0x02DA, // ring
      0xCB: 0x00B8, // cedilla
      0xCD: 0x02DD, // hungarumlaut
      0xCE: 0x02DB, // ogonek
      0xCF: 0x02C7, // caron
      0xD0: 0x2014, // emdash
      0xE1: 0x00C6, // AE
      0xE3: 0x00AA, // ordfeminine
      0xE8: 0x0141, // Lslash
      0xE9: 0x00D8, // Oslash
      0xEA: 0x0152, // OE
      0xEB: 0x00BA, // ordmasculine
      0xF1: 0x00E6, // ae
      0xF5: 0x0131, // dotlessi
      0xF8: 0x0142, // lslash
      0xF9: 0x00F8, // oslash
      0xFA: 0x0153, // oe
      0xFB: 0x00DF, // germandbls
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
