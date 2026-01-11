import 'dart:math' as math;

import 'pdf_parser.dart';
import 'pdf_types.dart';

/// Modes for text extraction.
enum PdfExtractionMode {
  /// Simple extraction (default).
  plain,

  /// Preserves physical layout with spaces and newlines.
  layout,
}

/// Callback for visiting PDF operators.
typedef PdfVisitorCallback = void Function(
    String operator, List<dynamic> operands);

/// Extracts text from PDF content streams with proper font encoding.
class PdfTextExtractor {
  late PdfParser parser;
  final Map<String, PdfFontInfo> fonts = {};
  final List<String> warnings = [];

  double pageWidth = 612;
  double pageHeight = 792;

  PdfTextExtractor(this.parser);

  /// Creates extractor for late parser initialization
  PdfTextExtractor.create();

  /// Extracts fonts from page resources.
  void extractPageFonts(String content) {
    // Find Font dictionary in Resources
    String? resourcesContent;

    // Check for direct Resources dictionary or reference
    final refMatch =
        RegExp(r'/Resources\s+(\d+)\s+\d+\s+R').firstMatch(content);
    if (refMatch != null) {
      final resourcesObj = parser.getObject(int.parse(refMatch.group(1)!));
      if (resourcesObj != null) {
        resourcesContent = resourcesObj.content;
      }
    } else {
      // Direct dictionary: /Resources << ... >>
      final resTag = '/Resources';
      final resIndex = content.indexOf(resTag);
      if (resIndex != -1) {
        final openIndex = content.indexOf('<<', resIndex);
        if (openIndex != -1) {
          resourcesContent = _extractDictionary(content, openIndex);
        }
      }
    }

    if (resourcesContent == null) return;

    // Parse Font dictionary
    _parseFontDict(resourcesContent);
  }

  void _parseFontDict(String resourcesContent) {
    // Try inline font dictionary - use balanced bracket matching
    final fontStart = resourcesContent.indexOf('/Font');
    if (fontStart == -1) return;

    final afterFont = resourcesContent.substring(fontStart + 5).trimLeft();

    // Check for reference first
    final refMatch = RegExp(r'^(\d+)\s+\d+\s+R').firstMatch(afterFont);
    if (refMatch != null) {
      final fontDictObj = parser.getObject(int.parse(refMatch.group(1)!));
      if (fontDictObj != null) {
        _parseFontRefs(fontDictObj.content);
      }
      return;
    }

    // Check for inline dictionary
    if (afterFont.startsWith('<<')) {
      final fontDictContent = _extractBalancedDict(afterFont);
      if (fontDictContent != null) {
        _parseFontRefs(fontDictContent);
      }
    }
  }

  /// Extracts content of balanced << >> dictionary
  String? _extractBalancedDict(String content) {
    if (!content.startsWith('<<')) return null;

    var depth = 0;
    var start = 0;

    for (var i = 0; i < content.length - 1; i++) {
      if (content.substring(i, i + 2) == '<<') {
        if (depth == 0) start = i + 2;
        depth++;
        i++;
      } else if (content.substring(i, i + 2) == '>>') {
        depth--;
        if (depth == 0) {
          return content.substring(start, i);
        }
        i++;
      }
    }
    return null;
  }

  void _parseFontRefs(String fontDict) {
    final fontRefs = RegExp(r'/(\w+)\s+(\d+)\s+\d+\s+R').allMatches(fontDict);
    for (final match in fontRefs) {
      final fontName = '/${match.group(1)!}';
      final fontRef = int.parse(match.group(2)!);

      final fontObj = parser.getObject(fontRef);
      if (fontObj != null) {
        fonts[fontName] = _parseFontObject(fontName, fontObj);
      }
    }
  }

  PdfFontInfo _parseFontObject(String name, PdfObject obj) {
    var baseFont = 'Helvetica';
    var isBold = false;
    var isItalic = false;
    String? encoding;
    Map<int, int>? toUnicode;
    var isEmbedded = false;
    var subtype = 'Type1';
    Map<int, int>? differences;
    String? baseEncoding;

    // Get Subtype
    final subtypeMatch = RegExp(r'/Subtype\s*/(\w+)').firstMatch(obj.content);
    if (subtypeMatch != null) {
      subtype = subtypeMatch.group(1)!;
    }

    // Get BaseFont
    final baseFontMatch = RegExp(r'/BaseFont\s*/(\S+)').firstMatch(obj.content);
    if (baseFontMatch != null) {
      baseFont = baseFontMatch.group(1)!;
      final lowerFont = baseFont.toLowerCase();
      isBold = lowerFont.contains('bold');
      isItalic = lowerFont.contains('italic') || lowerFont.contains('oblique');
    }

    // Get Encoding - handle both name and dictionary formats
    final encodingNameMatch =
        RegExp(r'/Encoding\s*/(\w+)').firstMatch(obj.content);
    if (encodingNameMatch != null) {
      encoding = encodingNameMatch.group(1);
    } else {
      // Try to find encoding dictionary reference
      final encodingRefMatch =
          RegExp(r'/Encoding\s+(\d+)\s+\d+\s+R').firstMatch(obj.content);
      if (encodingRefMatch != null) {
        final encodingObj =
            parser.getObject(int.parse(encodingRefMatch.group(1)!));
        if (encodingObj != null) {
          final parsed = _parseEncodingDict(encodingObj.content);
          baseEncoding = parsed['baseEncoding'] as String?;
          differences = parsed['differences'] as Map<int, int>?;
          encoding = baseEncoding;
        }
      } else {
        // Try inline encoding dictionary: /Encoding << ... >>
        final inlineEncodingMatch =
            RegExp(r'/Encoding\s*<<([^>]+)>>').firstMatch(obj.content);
        if (inlineEncodingMatch != null) {
          final parsed = _parseEncodingDict(inlineEncodingMatch.group(1)!);
          baseEncoding = parsed['baseEncoding'] as String?;
          differences = parsed['differences'] as Map<int, int>?;
          encoding = baseEncoding;
        }
      }
    }

    // Check for embedded font
    final fontFileMatch =
        RegExp(r'/FontFile[23]?\s+(\d+)\s+\d+\s+R').firstMatch(obj.content);
    if (fontFileMatch != null) {
      isEmbedded = true;
    }

    // Get ToUnicode CMap
    final toUnicodeMatch =
        RegExp(r'/ToUnicode\s+(\d+)\s+\d+\s+R').firstMatch(obj.content);
    if (toUnicodeMatch != null) {
      final cmapRef = int.parse(toUnicodeMatch.group(1)!);
      final cmapContent = parser.getStreamContent(cmapRef);
      if (cmapContent != null) {
        final cmap = PdfCMap();
        cmap.parseCMap(cmapContent);
        toUnicode = cmap.charToUnicode;
      }
    }

    // Handle Type0 fonts (CIDFonts)
    if (subtype == 'Type0') {
      final descendantMatch = RegExp(r'/DescendantFonts\s*\[\s*(\d+)\s+\d+\s+R')
          .firstMatch(obj.content);
      if (descendantMatch != null) {
        final cidFontObj =
            parser.getObject(int.parse(descendantMatch.group(1)!));
        if (cidFontObj != null) {
          final cidBaseFont =
              RegExp(r'/BaseFont\s*/(\S+)').firstMatch(cidFontObj.content);
          if (cidBaseFont != null) {
            baseFont = cidBaseFont.group(1)!;
            final lowerFont = baseFont.toLowerCase();
            isBold = lowerFont.contains('bold');
            isItalic =
                lowerFont.contains('italic') || lowerFont.contains('oblique');
          }
        }
      }

      // Check for Identity-H/Identity-V encoding
      final identityMatch =
          RegExp(r'/Encoding\s*/(Identity-[HV])').firstMatch(obj.content);
      if (identityMatch != null) {
        encoding = identityMatch.group(1);
      }
      if (identityMatch != null) {
        encoding = identityMatch.group(1);
      }
    }

    // Parse Font Widths
    List<num>? widths;
    int firstChar = 0;
    int lastChar = 255;
    int missingWidth = 0;

    // Check for Widths array (direct or indirect)
    final widthsMatch =
        RegExp(r'/Widths\s*(?:(\[\s*[\d.\s\r\n]+\])|(\d+)\s+\d+\s+R)')
            .firstMatch(obj.content);
    if (widthsMatch != null) {
      String? widthsContent;
      if (widthsMatch.group(1) != null) {
        // Direct array
        widthsContent = widthsMatch.group(1)!;
      } else {
        // Indirect reference
        final refId = int.parse(widthsMatch.group(2)!);
        final widthObj = parser.getObject(refId);
        if (widthObj != null) {
          // Extract content between [ and ]
          final start = widthObj.content.indexOf('[');
          final end = widthObj.content.lastIndexOf(']');
          if (start != -1 && end != -1) {
            widthsContent = widthObj.content.substring(start, end + 1);
          }
        }
      }

      if (widthsContent != null) {
        // Remove brackets and split
        final clean = widthsContent.replaceAll(RegExp(r'[\[\]]'), '');
        widths = clean
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .map((s) => num.tryParse(s) ?? 0)
            .toList();
      }
    }

    // First/Last char
    final firstCharMatch =
        RegExp(r'/FirstChar\s+(\d+)').firstMatch(obj.content);
    if (firstCharMatch != null) firstChar = int.parse(firstCharMatch.group(1)!);

    final lastCharMatch = RegExp(r'/LastChar\s+(\d+)').firstMatch(obj.content);
    if (lastCharMatch != null) lastChar = int.parse(lastCharMatch.group(1)!);

    return PdfFontInfo(
      name: name,
      baseFont: baseFont,
      isBold: isBold,
      isItalic: isItalic,
      encoding: encoding,
      toUnicode: toUnicode,
      isEmbedded: isEmbedded,
      subtype: subtype,
      differences: differences,
      baseEncoding: baseEncoding,
      widths: widths,
      firstChar: firstChar,
      lastChar: lastChar,
      missingWidth: missingWidth,
    );
  }

  /// Parses an Encoding dictionary for BaseEncoding and Differences.
  Map<String, dynamic> _parseEncodingDict(String content) {
    final result = <String, dynamic>{};

    // Get BaseEncoding
    final baseMatch = RegExp(r'/BaseEncoding\s*/(\w+)').firstMatch(content);
    if (baseMatch != null) {
      result['baseEncoding'] = baseMatch.group(1);
    }

    // Parse Differences array
    final diffMatch =
        RegExp(r'/Differences\s*\[([^\]]+)\]').firstMatch(content);
    if (diffMatch != null) {
      final differences = <int, int>{};
      final diffContent = diffMatch.group(1)!;
      final tokens = diffContent.split(RegExp(r'\s+'));

      var currentCode = 0;
      for (final token in tokens) {
        if (token.isEmpty) continue;

        final codeNum = int.tryParse(token);
        if (codeNum != null) {
          currentCode = codeNum;
        } else if (token.startsWith('/')) {
          // This is a glyph name - map to Unicode
          final glyphName = token.substring(1);
          final unicode = _glyphNameToUnicode(glyphName);
          if (unicode != null) {
            differences[currentCode] = unicode;
          }
          currentCode++;
        }
      }

      result['differences'] = differences;
    }

    return result;
  }

  /// Converts a glyph name to Unicode code point.
  /// Comprehensive Adobe Glyph List mapping.
  int? _glyphNameToUnicode(String name) {
    // Extensive glyph names mapping from Adobe Glyph List
    const glyphMap = <String, int>{
      // Basic ASCII
      'space': 0x0020, 'exclam': 0x0021, 'quotedbl': 0x0022,
      'numbersign': 0x0023, 'dollar': 0x0024, 'percent': 0x0025,
      'ampersand': 0x0026, 'quotesingle': 0x0027, 'parenleft': 0x0028,
      'parenright': 0x0029, 'asterisk': 0x002A, 'plus': 0x002B,
      'comma': 0x002C, 'hyphen': 0x002D, 'period': 0x002E, 'slash': 0x002F,
      'zero': 0x0030, 'one': 0x0031, 'two': 0x0032, 'three': 0x0033,
      'four': 0x0034, 'five': 0x0035, 'six': 0x0036, 'seven': 0x0037,
      'eight': 0x0038, 'nine': 0x0039, 'colon': 0x003A, 'semicolon': 0x003B,
      'less': 0x003C, 'equal': 0x003D, 'greater': 0x003E, 'question': 0x003F,
      'at': 0x0040,
      'A': 0x0041, 'B': 0x0042, 'C': 0x0043, 'D': 0x0044, 'E': 0x0045,
      'F': 0x0046, 'G': 0x0047, 'H': 0x0048, 'I': 0x0049, 'J': 0x004A,
      'K': 0x004B, 'L': 0x004C, 'M': 0x004D, 'N': 0x004E, 'O': 0x004F,
      'P': 0x0050, 'Q': 0x0051, 'R': 0x0052, 'S': 0x0053, 'T': 0x0054,
      'U': 0x0055, 'V': 0x0056, 'W': 0x0057, 'X': 0x0058, 'Y': 0x0059,
      'Z': 0x005A,
      'bracketleft': 0x005B, 'backslash': 0x005C, 'bracketright': 0x005D,
      'asciicircum': 0x005E, 'underscore': 0x005F, 'grave': 0x0060,
      'a': 0x0061, 'b': 0x0062, 'c': 0x0063, 'd': 0x0064, 'e': 0x0065,
      'f': 0x0066, 'g': 0x0067, 'h': 0x0068, 'i': 0x0069, 'j': 0x006A,
      'k': 0x006B, 'l': 0x006C, 'm': 0x006D, 'n': 0x006E, 'o': 0x006F,
      'p': 0x0070, 'q': 0x0071, 'r': 0x0072, 's': 0x0073, 't': 0x0074,
      'u': 0x0075, 'v': 0x0076, 'w': 0x0077, 'x': 0x0078, 'y': 0x0079,
      'z': 0x007A,
      'braceleft': 0x007B, 'bar': 0x007C, 'braceright': 0x007D,
      'asciitilde': 0x007E,

      // Latin Extended-A & Extended-B
      'Amacron': 0x0100, 'amacron': 0x0101, 'Abreve': 0x0102, 'abreve': 0x0103,
      'Aogonek': 0x0104, 'aogonek': 0x0105, 'Cacute': 0x0106, 'cacute': 0x0107,
      'Ccircumflex': 0x0108, 'ccircumflex': 0x0109, 'Cdotaccent': 0x010A,
      'cdotaccent': 0x010B, 'Ccaron': 0x010C, 'ccaron': 0x010D,
      'Dcaron': 0x010E, 'dcaron': 0x010F, 'Dcroat': 0x0110, 'dcroat': 0x0111,
      'Emacron': 0x0112, 'emacron': 0x0113, 'Ebreve': 0x0114, 'ebreve': 0x0115,
      'Edotaccent': 0x0116, 'edotaccent': 0x0117, 'Eogonek': 0x0118,
      'eogonek': 0x0119, 'Ecaron': 0x011A, 'ecaron': 0x011B,
      'Gbreve': 0x011E, 'gbreve': 0x011F, 'Gdotaccent': 0x0120,
      'gdotaccent': 0x0121, 'Gcommaaccent': 0x0122, 'gcommaaccent': 0x0123,
      'Hbar': 0x0126, 'hbar': 0x0127, 'Itilde': 0x0128, 'itilde': 0x0129,
      'Imacron': 0x012A, 'imacron': 0x012B, 'Iogonek': 0x012E,
      'iogonek': 0x012F,
      'Idotaccent': 0x0130, 'dotlessi': 0x0131,
      'Lacute': 0x0139, 'lacute': 0x013A, 'Lcommaaccent': 0x013B,
      'lcommaaccent': 0x013C, 'Lcaron': 0x013D, 'lcaron': 0x013E,
      'Lslash': 0x0141, 'lslash': 0x0142, 'Nacute': 0x0143, 'nacute': 0x0144,
      'Ncommaaccent': 0x0145, 'ncommaaccent': 0x0146, 'Ncaron': 0x0147,
      'ncaron': 0x0148, 'Eng': 0x014A, 'eng': 0x014B,
      'Omacron': 0x014C, 'omacron': 0x014D, 'Obreve': 0x014E, 'obreve': 0x014F,
      'Ohungarumlaut': 0x0150, 'ohungarumlaut': 0x0151,
      'OE': 0x0152, 'oe': 0x0153, 'Racute': 0x0154, 'racute': 0x0155,
      'Rcommaaccent': 0x0156, 'rcommaaccent': 0x0157, 'Rcaron': 0x0158,
      'rcaron': 0x0159, 'Sacute': 0x015A, 'sacute': 0x015B,
      'Scircumflex': 0x015C, 'scircumflex': 0x015D, 'Scedilla': 0x015E,
      'scedilla': 0x015F, 'Scaron': 0x0160, 'scaron': 0x0161,
      'Tcommaaccent': 0x0162, 'tcommaaccent': 0x0163, 'Tcaron': 0x0164,
      'tcaron': 0x0165, 'Tbar': 0x0166, 'tbar': 0x0167,
      'Utilde': 0x0168, 'utilde': 0x0169, 'Umacron': 0x016A, 'umacron': 0x016B,
      'Ubreve': 0x016C, 'ubreve': 0x016D, 'Uring': 0x016E, 'uring': 0x016F,
      'Uhungarumlaut': 0x0170, 'uhungarumlaut': 0x0171,
      'Uogonek': 0x0172, 'uogonek': 0x0173, 'Wcircumflex': 0x0174,
      'wcircumflex': 0x0175, 'Ycircumflex': 0x0176, 'ycircumflex': 0x0177,
      'Ydieresis': 0x0178, 'Zacute': 0x0179, 'zacute': 0x017A,
      'Zdotaccent': 0x017B, 'zdotaccent': 0x017C, 'Zcaron': 0x017D,
      'zcaron': 0x017E, 'florin': 0x0192,

      // Latin-1 Supplement
      'exclamdown': 0x00A1, 'cent': 0x00A2, 'sterling': 0x00A3,
      'currency': 0x00A4, 'yen': 0x00A5, 'brokenbar': 0x00A6,
      'section': 0x00A7, 'dieresis': 0x00A8, 'copyright': 0x00A9,
      'ordfeminine': 0x00AA, 'guillemotleft': 0x00AB, 'logicalnot': 0x00AC,
      'registered': 0x00AE, 'macron': 0x00AF, 'degree': 0x00B0,
      'plusminus': 0x00B1, 'twosuperior': 0x00B2, 'threesuperior': 0x00B3,
      'acute': 0x00B4, 'mu': 0x00B5, 'paragraph': 0x00B6,
      'periodcentered': 0x00B7, 'cedilla': 0x00B8, 'onesuperior': 0x00B9,
      'ordmasculine': 0x00BA, 'guillemotright': 0x00BB, 'onequarter': 0x00BC,
      'onehalf': 0x00BD, 'threequarters': 0x00BE, 'questiondown': 0x00BF,
      'Agrave': 0x00C0, 'Aacute': 0x00C1, 'Acircumflex': 0x00C2,
      'Atilde': 0x00C3, 'Adieresis': 0x00C4, 'Aring': 0x00C5,
      'AE': 0x00C6, 'Ccedilla': 0x00C7, 'Egrave': 0x00C8, 'Eacute': 0x00C9,
      'Ecircumflex': 0x00CA, 'Edieresis': 0x00CB, 'Igrave': 0x00CC,
      'Iacute': 0x00CD, 'Icircumflex': 0x00CE, 'Idieresis': 0x00CF,
      'Eth': 0x00D0, 'Ntilde': 0x00D1, 'Ograve': 0x00D2, 'Oacute': 0x00D3,
      'Ocircumflex': 0x00D4, 'Otilde': 0x00D5, 'Odieresis': 0x00D6,
      'multiply': 0x00D7, 'Oslash': 0x00D8, 'Ugrave': 0x00D9, 'Uacute': 0x00DA,
      'Ucircumflex': 0x00DB, 'Udieresis': 0x00DC, 'Yacute': 0x00DD,
      'Thorn': 0x00DE, 'germandbls': 0x00DF,
      'agrave': 0x00E0, 'aacute': 0x00E1, 'acircumflex': 0x00E2,
      'atilde': 0x00E3, 'adieresis': 0x00E4, 'aring': 0x00E5,
      'ae': 0x00E6, 'ccedilla': 0x00E7, 'egrave': 0x00E8, 'eacute': 0x00E9,
      'ecircumflex': 0x00EA, 'edieresis': 0x00EB, 'igrave': 0x00EC,
      'iacute': 0x00ED, 'icircumflex': 0x00EE, 'idieresis': 0x00EF,
      'eth': 0x00F0, 'ntilde': 0x00F1, 'ograve': 0x00F2, 'oacute': 0x00F3,
      'ocircumflex': 0x00F4, 'otilde': 0x00F5, 'odieresis': 0x00F6,
      'divide': 0x00F7, 'oslash': 0x00F8, 'ugrave': 0x00F9, 'uacute': 0x00FA,
      'ucircumflex': 0x00FB, 'udieresis': 0x00FC, 'yacute': 0x00FD,
      'thorn': 0x00FE, 'ydieresis': 0x00FF,

      // Spacing Modifier Letters
      'circumflex': 0x02C6, 'caron': 0x02C7, 'breve': 0x02D8,
      'dotaccent': 0x02D9, 'ring': 0x02DA, 'ogonek': 0x02DB,
      'tilde': 0x02DC, 'hungarumlaut': 0x02DD,

      // Greek Letters
      'Alpha': 0x0391, 'Beta': 0x0392, 'Gamma': 0x0393, 'Delta': 0x0394,
      'Epsilon': 0x0395, 'Zeta': 0x0396, 'Eta': 0x0397, 'Theta': 0x0398,
      'Iota': 0x0399, 'Kappa': 0x039A, 'Lambda': 0x039B, 'Mu': 0x039C,
      'Nu': 0x039D, 'Xi': 0x039E, 'Omicron': 0x039F, 'Pi': 0x03A0,
      'Rho': 0x03A1, 'Sigma': 0x03A3, 'Tau': 0x03A4, 'Upsilon': 0x03A5,
      'Phi': 0x03A6, 'Chi': 0x03A7, 'Psi': 0x03A8, 'Omega': 0x03A9,
      'alpha': 0x03B1, 'beta': 0x03B2, 'gamma': 0x03B3, 'delta': 0x03B4,
      'epsilon': 0x03B5, 'zeta': 0x03B6, 'eta': 0x03B7, 'theta': 0x03B8,
      'iota': 0x03B9, 'kappa': 0x03BA, 'lambda': 0x03BB, 'mugreek': 0x03BC,
      'nu': 0x03BD, 'xi': 0x03BE, 'omicron': 0x03BF, 'pi': 0x03C0,
      'rho': 0x03C1, 'sigma1': 0x03C2, 'sigma': 0x03C3, 'tau': 0x03C4,
      'upsilon': 0x03C5, 'phi': 0x03C6, 'chi': 0x03C7, 'psi': 0x03C8,
      'omega': 0x03C9, 'theta1': 0x03D1, 'phi1': 0x03D5, 'omega1': 0x03D6,

      // General Punctuation
      'endash': 0x2013, 'emdash': 0x2014, 'afii61664': 0x200D,
      'quoteleft': 0x2018, 'quoteright': 0x2019, 'quotesinglbase': 0x201A,
      'quotedblleft': 0x201C, 'quotedblright': 0x201D, 'quotedblbase': 0x201E,
      'dagger': 0x2020, 'daggerdbl': 0x2021, 'bullet': 0x2022,
      'ellipsis': 0x2026, 'perthousand': 0x2030, 'minute': 0x2032,
      'second': 0x2033, 'guilsinglleft': 0x2039, 'guilsinglright': 0x203A,
      'fraction': 0x2044, 'Euro': 0x20AC,

      // Letterlike Symbols
      'trademark': 0x2122, 'ohm': 0x2126, 'estimated': 0x212E,
      'aleph': 0x2135, 'afii61289': 0x2113, 'afii61352': 0x2116,

      // Arrows
      'arrowleft': 0x2190, 'arrowup': 0x2191, 'arrowright': 0x2192,
      'arrowdown': 0x2193, 'arrowboth': 0x2194, 'arrowupdn': 0x2195,
      'arrowdblup': 0x21D1, 'arrowdblright': 0x21D2, 'arrowdbldown': 0x21D3,
      'arrowdblleft': 0x21D0, 'arrowdblboth': 0x21D4,

      // Mathematical Operators
      'minus': 0x2212, 'universal': 0x2200,
      'partialdiff': 0x2202, 'existential': 0x2203, 'emptyset': 0x2205,
      'increment': 0x2206, 'gradient': 0x2207, 'element': 0x2208,
      'notelement': 0x2209, 'suchthat': 0x220B, 'product': 0x220F,
      'summation': 0x2211, 'asteriskmath': 0x2217, 'radical': 0x221A,
      'proportional': 0x221D, 'infinity': 0x221E, 'angle': 0x2220,
      'logicaland': 0x2227, 'logicalor': 0x2228, 'intersection': 0x2229,
      'union': 0x222A, 'integral': 0x222B, 'therefore': 0x2234,
      'similar': 0x223C, 'congruent': 0x2245, 'approxequal': 0x2248,
      'notequal': 0x2260, 'equivalence': 0x2261, 'lessequal': 0x2264,
      'greaterequal': 0x2265, 'propersubset': 0x2282, 'propersuperset': 0x2283,
      'notsubset': 0x2284, 'reflexsubset': 0x2286, 'reflexsuperset': 0x2287,
      'circleplus': 0x2295, 'circlemultiply': 0x2297, 'perpendicular': 0x22A5,
      'dotmath': 0x22C5,

      // Miscellaneous Symbols
      'lozenge': 0x25CA, 'spade': 0x2660, 'club': 0x2663,
      'heart': 0x2665, 'diamond': 0x2666,

      // Geometric Shapes
      'filledbox': 0x25A0, 'H22073': 0x25A1, 'filledrect': 0x25AC,
      'triagup': 0x25B2, 'triagrt': 0x25BA, 'triagdn': 0x25BC,
      'triaglf': 0x25C4, 'circle': 0x25CB, 'H18533': 0x25CF,

      // Ligatures
      'fi': 0xFB01, 'fl': 0xFB02, 'ff': 0xFB00, 'ffi': 0xFB03, 'ffl': 0xFB04,

      // Box Drawing (partial)
      'SF100000': 0x2500, 'SF110000': 0x2502, 'SF010000': 0x250C,
      'SF030000': 0x2510, 'SF020000': 0x2514, 'SF040000': 0x2518,
      'SF080000': 0x253C, 'SF060000': 0x252C, 'SF070000': 0x2534,
      'SF050000': 0x251C, 'SF090000': 0x2524,

      // Miscellaneous common names
      'nbspace': 0x00A0, 'softhyphen': 0x00AD,
      'hyphensoft': 0x00AD, 'hyphenminus': 0x002D,
      'nonbreakingspace': 0x00A0,
    };

    if (glyphMap.containsKey(name)) {
      return glyphMap[name];
    }

    // Handle uniXXXX format (e.g., uni0041 = 'A')
    if (name.startsWith('uni') && name.length >= 7) {
      final hex = name.substring(3, 7);
      return int.tryParse(hex, radix: 16);
    }

    // Handle uXXXX or uXXXXX format
    if (name.startsWith('u') && name.length >= 5) {
      final hex = name.substring(1);
      return int.tryParse(hex, radix: 16);
    }

    // Handle gXXXX format (glyph ID - return as-is, can't map)
    if (name.startsWith('g') && name.length > 1) {
      final id = int.tryParse(name.substring(1));
      if (id != null) return null; // Can't map glyph IDs to Unicode
    }

    // Single character names
    if (name.length == 1) {
      return name.codeUnitAt(0);
    }

    return null;
  }

  /// Extracts text from a content stream.
  ///
  /// [visitor] is an optional callback allowing custom processing of all operators.
  List<PdfTextLine> extractText(String stream, {PdfVisitorCallback? visitor}) {
    if (stream.trim().isEmpty) return [];

    final lines = <PdfTextLine>[];
    var state = PdfGraphicsState();
    final stateStack = <PdfGraphicsState>[];
    final tokens = parser.tokenize(stream);

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      List<dynamic> currentOperands = [];

      switch (token) {
        case 'q':
          stateStack.add(state.clone());
          break;

        case 'Q':
          if (stateStack.isNotEmpty) {
            state = stateStack.removeLast();
          }
          break;

        case 'cm':
          if (i >= 6) {
            final a = double.tryParse(tokens[i - 6]) ?? 1;
            final b = double.tryParse(tokens[i - 5]) ?? 0;
            final c = double.tryParse(tokens[i - 4]) ?? 0;
            final d = double.tryParse(tokens[i - 3]) ?? 1;
            final e = double.tryParse(tokens[i - 2]) ?? 0;
            final f = double.tryParse(tokens[i - 1]) ?? 0;
            state.ctm = state.ctm.multiply(PdfMatrix(a, b, c, d, e, f));
            currentOperands = [a, b, c, d, e, f];
          }
          break;

        case 'BT':
          state.textMatrix = PdfMatrix.identity();
          state.textLineMatrix = PdfMatrix.identity();
          break;

        case 'ET':
          // End text object
          break;

        case 'Tm':
          if (i >= 6) {
            final a = double.tryParse(tokens[i - 6]) ?? 1;
            final b = double.tryParse(tokens[i - 5]) ?? 0;
            final c = double.tryParse(tokens[i - 4]) ?? 0;
            final d = double.tryParse(tokens[i - 3]) ?? 1;
            final e = double.tryParse(tokens[i - 2]) ?? 0;
            final f = double.tryParse(tokens[i - 1]) ?? 0;
            state.textMatrix = PdfMatrix(a, b, c, d, e, f);
            state.textLineMatrix = state.textMatrix.clone();
            currentOperands = [a, b, c, d, e, f];
          }
          break;

        case 'Td':
          if (i >= 2) {
            final tx = double.tryParse(tokens[i - 2]) ?? 0;
            final ty = double.tryParse(tokens[i - 1]) ?? 0;
            final mat = PdfMatrix(1, 0, 0, 1, tx, ty);
            state.textLineMatrix = mat.multiply(state.textLineMatrix);
            state.textMatrix = state.textLineMatrix.clone();
            currentOperands = [tx, ty];
          }
          break;

        case 'TD':
          if (i >= 2) {
            final tx = double.tryParse(tokens[i - 2]) ?? 0;
            final ty = double.tryParse(tokens[i - 1]) ?? 0;
            // TD also sets leading to -ty
            final mat = PdfMatrix(1, 0, 0, 1, tx, ty);
            state.textLineMatrix = mat.multiply(state.textLineMatrix);
            state.textMatrix = state.textLineMatrix.clone();
            state.leading = -ty;
            currentOperands = [tx, ty];
          }
          break;

        case 'T*':
          // Move to start of next line (using current leading)
          state.textLineMatrix = PdfMatrix(1, 0, 0, 1, 0, -state.leading)
              .multiply(state.textLineMatrix);
          state.textMatrix = state.textLineMatrix.clone();
          break;

        case 'Tf':
          if (i >= 2) {
            state.fontName = tokens[i - 2];
            state.fontSize = double.tryParse(tokens[i - 1]) ?? 12;
            currentOperands = [state.fontName, state.fontSize];
          }
          break;

        case 'Tc':
          if (i >= 1) {
            state.charSpacing = double.tryParse(tokens[i - 1]) ?? 0;
            currentOperands = [state.charSpacing];
          }
          break;

        case 'Tw':
          if (i >= 1) {
            state.wordSpacing = double.tryParse(tokens[i - 1]) ?? 0;
            currentOperands = [state.wordSpacing];
          }
          break;

        case 'Ts':
          if (i >= 1) {
            state.textRise = double.tryParse(tokens[i - 1]) ?? 0;
            currentOperands = [state.textRise];
          }
          break;

        case 'Tz':
          if (i >= 1) {
            state.horizontalScaling = double.tryParse(tokens[i - 1]) ?? 100;
            currentOperands = [state.horizontalScaling];
          }
          break;

        case 'TL': // Set Text Leading
          if (i >= 1) {
            state.leading = double.tryParse(tokens[i - 1]) ?? 0;
            currentOperands = [state.leading];
          }
          break;

        case 'Tj':
          if (i >= 1) {
            final textLine = _processTextString(tokens[i - 1], state);
            if (textLine != null) lines.add(textLine);
            currentOperands = [tokens[i - 1]];
          }
          break;

        case 'TJ':
          if (i >= 1) {
            String arrayToken = tokens[i - 1];

            // Handle split array (tokenizer might split [ ... ])
            if (arrayToken == ']') {
              // Walk backwards to find matching [
              var j = i - 2;
              int depth = 1;
              final buffer = <String>[];
              buffer.add(']');

              while (j >= 0 && depth > 0) {
                final t = tokens[j];
                buffer.insert(0, t); // Prepend

                if (t == ']') depth++;
                if (t == '[') depth--;

                j--;
              }

              if (depth == 0) {
                arrayToken = buffer.join(' '); // Reconstruct with spaces
                // Remove the used operand from currentOperands (not strictly needed as we just log/use it)
                // Note: The original i-1 token was just ']'
              }
            }

            try {
              final textLines = _processTextArray(arrayToken, state);
              lines.addAll(textLines);
            } catch (e) {}
            currentOperands = [arrayToken];
          }
          break;

        case "'":
          state.textLineMatrix = PdfMatrix(1, 0, 0, 1, 0, -state.leading)
              .multiply(state.textLineMatrix);
          state.textMatrix = state.textLineMatrix.clone();
          if (i >= 1) {
            final textLine = _processTextString(tokens[i - 1], state);
            if (textLine != null) lines.add(textLine);
            currentOperands = [tokens[i - 1]];
          }
          break;

        case '"':
          // Set word spacing, char spacing, move to next line, show text
          if (i >= 3) {
            state.wordSpacing = double.tryParse(tokens[i - 3]) ?? 0;
            state.charSpacing = double.tryParse(tokens[i - 2]) ?? 0;
            state.textLineMatrix = PdfMatrix(1, 0, 0, 1, 0, -state.leading)
                .multiply(state.textLineMatrix);
            state.textMatrix = state.textLineMatrix.clone();
            final textLine = _processTextString(tokens[i - 1], state);
            if (textLine != null) lines.add(textLine);
            currentOperands = [tokens[i - 3], tokens[i - 2], tokens[i - 1]];
          }
          break;

        case 'rg':
          if (i >= 3) {
            state.fillColorR = double.tryParse(tokens[i - 3]) ?? 0;
            state.fillColorG = double.tryParse(tokens[i - 2]) ?? 0;
            state.fillColorB = double.tryParse(tokens[i - 1]) ?? 0;
            currentOperands = [
              state.fillColorR,
              state.fillColorG,
              state.fillColorB
            ];
          }
          break;

        case 'RG':
          if (i >= 3) {
            state.strokeColorR = double.tryParse(tokens[i - 3]) ?? 0;
            state.strokeColorG = double.tryParse(tokens[i - 2]) ?? 0;
            state.strokeColorB = double.tryParse(tokens[i - 1]) ?? 0;
            currentOperands = [
              state.strokeColorR,
              state.strokeColorG,
              state.strokeColorB
            ];
          }
          break;

        case 'g':
          if (i >= 1) {
            final gray = double.tryParse(tokens[i - 1]) ?? 0;
            state.fillColorR = gray;
            state.fillColorG = gray;
            state.fillColorB = gray;
            currentOperands = [gray];
          }
          break;

        case 'G':
          if (i >= 1) {
            final gray = double.tryParse(tokens[i - 1]) ?? 0;
            state.strokeColorR = gray;
            state.strokeColorG = gray;
            state.strokeColorB = gray;
            currentOperands = [gray];
          }
          break;
      }

      if (visitor != null) {
        visitor(token, currentOperands);
      }
    }

    // Apply deduplication to remove overlapping text from multi-layer PDFs
    return _deduplicateLines(lines);
  }

  /// Extracts text as a formatted string using the specified [mode].
  String extractTextString(String stream,
      {PdfExtractionMode mode = PdfExtractionMode.plain}) {
    final lines = extractText(stream);

    // Deduplicate overlapping text lines (common in multi-layer PDFs)
    final deduped = _deduplicateLines(lines);

    // Sort lines by position (Top-down, Left-right)
    deduped.sort((a, b) {
      if ((a.y - b.y).abs() > a.size * 0.5) {
        return b.y.compareTo(a.y);
      }
      return a.x.compareTo(b.x);
    });

    final buffer = StringBuffer();

    if (mode == PdfExtractionMode.plain) {
      for (final line in deduped) {
        buffer.write(line.text);
        buffer.write(' ');
      }
      return buffer.toString().trim();
    }

    // Layout mode
    double? lastY;
    double? lastX;

    for (final line in deduped) {
      if (lastY != null) {
        final distY = (lastY - line.y).abs();
        if (distY > (line.size * 0.5)) {
          buffer.writeln();
          lastX = 0;
        }
      }

      if (lastX != null) {
        final distX = line.x - lastX;
        final charWidth = line.size * 0.5;
        if (distX > charWidth) {
          final spaces = (distX / charWidth).round();
          if (spaces > 0) {
            buffer.write(' ' * math.min(spaces, 10));
          }
        }
      }

      buffer.write(line.text);
      lastY = line.y;
      lastX = line.x + line.width;
    }

    return buffer.toString();
  }

  /// Removes duplicate text lines at overlapping positions.
  /// Some PDFs (e.g., LibreOffice exports) render text twice at different
  /// Y positions for visual effects. This detects and removes duplicates.
  List<PdfTextLine> _deduplicateLines(List<PdfTextLine> lines) {
    if (lines.isEmpty) return lines;

    // Group lines by their Y coordinate (rounded to paragraph level ~14pt)
    final yGroups = <int, List<PdfTextLine>>{};
    for (final line in lines) {
      final yGroup = (line.y / 14).round();
      yGroups.putIfAbsent(yGroup, () => []).add(line);
    }

    // Find Y groups that are duplicates of each other by comparing content
    final groupKeys = yGroups.keys.toList()..sort((a, b) => b.compareTo(a));
    final usedGroups = <int>{};
    final result = <PdfTextLine>[];

    for (final key in groupKeys) {
      if (usedGroups.contains(key)) continue;

      final group = yGroups[key]!;
      usedGroups.add(key);
      result.addAll(group);

      // Check if there's a duplicate group with similar X pattern but different Y
      // LibreOffice typically offsets duplicate text by ~40pt vertically
      for (final otherKey in groupKeys) {
        if (usedGroups.contains(otherKey)) continue;
        final offset = (key - otherKey).abs();
        if (offset >= 2 && offset <= 4) {
          // ~28-56pt apart at 14pt grouping
          // Check if content is similar (same texts at similar X positions)
          final otherGroup = yGroups[otherKey]!;
          if (_areDuplicateGroups(group, otherGroup)) {
            usedGroups.add(otherKey); // Mark as duplicate, don't include
          }
        }
      }
    }

    return result;
  }

  /// Checks if two groups have similar text content at similar X positions.
  bool _areDuplicateGroups(List<PdfTextLine> a, List<PdfTextLine> b) {
    if (a.isEmpty || b.isEmpty) return false;

    // Build text signatures for each group (text@rounded-x)
    final sigA = <String>{};
    final sigB = <String>{};

    for (final line in a) {
      sigA.add('${line.text}@${(line.x / 5).round()}');
    }
    for (final line in b) {
      sigB.add('${line.text}@${(line.x / 5).round()}');
    }

    // If >70% overlap, consider them duplicates
    final overlap = sigA.intersection(sigB).length;
    final minSize = sigA.length < sigB.length ? sigA.length : sigB.length;

    return minSize > 0 && overlap / minSize > 0.7;
  }

  PdfTextLine? _processTextString(String textEntry, PdfGraphicsState state) {
    var text = textEntry;

    // Handle hex strings
    if (text.startsWith('<') && text.endsWith('>')) {
      if (text.length >= 2) {
        text = _decodeHexString(text, state);
      }
    } else if (text.startsWith('(') && text.endsWith(')')) {
      if (text.length >= 2) {
        text = _decodeLiteralString(text.substring(1, text.length - 1), state);
      }
    }

    if (text.isEmpty) return null;

    final mat = state.textMatrix.multiply(state.ctm);
    final fontInfo = fonts[state.fontName];

    // Calculate accumulated width first
    double accumulatedWidth = 0;

    if (fontInfo != null) {
      for (var i = 0; i < text.length; i++) {
        final code = text.codeUnitAt(i);
        // Note: text is already decoded to Unicode string here
        // HEURISTIC: Use code if in range, matching PdfFontInfo expectation for simple fonts
        double charW = state.fontSize * 0.5;
        if (code >= fontInfo.firstChar && code <= fontInfo.lastChar) {
          charW = fontInfo.getCharWidth(code, state.fontSize);
        }

        // Add char width + char spacing + word spacing (if space)
        final totalW =
            (charW + state.charSpacing + (code == 32 ? state.wordSpacing : 0)) *
                (state.horizontalScaling / 100);
        accumulatedWidth += totalW;
      }
    } else {
      accumulatedWidth =
          text.length * state.fontSize * 0.5 * (state.horizontalScaling / 100);
    }

    // Calculate rotation: atan2(c, d)? No, usually b and a
    // Matrix: [a b c d e f]
    // Rotation is typically encoded in a, b, c, d
    // For no skewed rotation: tan(theta) = b/a ... atan2(b, a)
    final rotation = math.atan2(mat.b, mat.a) * (180 / math.pi);

    final line = PdfTextLine(
      text: text,
      x: mat.e,
      y: mat.f,
      font: state.fontName,
      size: state.fontSize * mat.scale, // Use matrix scale
      colorR: state.fillColorR,
      colorG: state.fillColorG,
      colorB: state.fillColorB,
      width: accumulatedWidth,
      textRise: state.textRise,
      fontInfo: fontInfo,
      matrix: mat,
      rotation: rotation,
    );

    if (fontInfo != null) {
      line.isBold = fontInfo.isBold;
      line.isItalic = fontInfo.isItalic;
    }

    // Advance text matrix
    state.textMatrix =
        PdfMatrix(1, 0, 0, 1, accumulatedWidth, 0).multiply(state.textMatrix);

    return line;
  }

  List<PdfTextLine> _processTextArray(
      String arrayEntry, PdfGraphicsState state) {
    if (arrayEntry.length < 2) return [];

    final lines = <PdfTextLine>[];
    final content = arrayEntry.substring(1, arrayEntry.length - 1);

    // Parse array elements: strings are in () or <>, numbers are numeric
    final elements = <dynamic>[];
    var i = 0;
    while (i < content.length) {
      final c = content[i];

      if (c == '(') {
        // Literal string
        var end = i + 1;
        var depth = 1;
        while (end < content.length && depth > 0) {
          if (content[end] == '(' && content[end - 1] != '\\') depth++;
          if (content[end] == ')' && content[end - 1] != '\\') depth--;
          end++;
        }
        elements.add(content.substring(i, end));
        i = end;
      } else if (c == '<') {
        // Hex string
        final end = content.indexOf('>', i);
        if (end != -1) {
          elements.add(content.substring(i, end + 1));
          i = end + 1;
        } else {
          i++;
        }
      } else if (RegExp(r'[\d.\-]').hasMatch(c)) {
        // Number
        var end = i;
        while (
            end < content.length && RegExp(r'[\d.\-]').hasMatch(content[end])) {
          end++;
        }
        final num = double.tryParse(content.substring(i, end));
        if (num != null) elements.add(num);
        i = end;
      } else {
        i++;
      }
    }

    // Process elements
    for (final elem in elements) {
      if (elem is String) {
        final line = _processTextString(elem, state);
        if (line != null) lines.add(line);
      } else if (elem is double) {
        // Kerning adjustment - move text position
        final tx = -elem * 0.001 * state.fontSize;
        state.textMatrix =
            PdfMatrix(1, 0, 0, 1, tx, 0).multiply(state.textMatrix);
      }
    }

    return lines;
  }

  String _decodeHexString(String hex, PdfGraphicsState state) {
    final content =
        hex.substring(1, hex.length - 1).replaceAll(RegExp(r'\s'), '');
    final fontInfo = fonts[state.fontName];

    // Determine if this is a CID font (2 bytes per character code)
    // CID fonts use 2-byte character codes; simple fonts use 1-byte
    final isCID = fontInfo != null &&
        (fontInfo.subtype == 'Type0' ||
            fontInfo.subtype == 'CIDFontType2' ||
            fontInfo.subtype == 'CIDFontType0');

    // Check encoding type for Identity-H/V (always 2-byte)
    final isIdentityEncoding = fontInfo?.encoding == 'Identity-H' ||
        fontInfo?.encoding == 'Identity-V';

    // Only use 2-byte decoding for actual CID fonts with Identity encoding
    // ToUnicode CMap presence alone doesn't mean 2-byte codes
    final use2Byte = isCID || isIdentityEncoding;

    if (use2Byte) {
      // 2-byte (CID) decoding - 4 hex chars = 1 character code
      final sb = StringBuffer();
      for (var i = 0; i < content.length; i += 4) {
        final chunk = content.substring(
            i, i + 4 < content.length ? i + 4 : content.length);
        final code = int.tryParse(chunk.padRight(4, '0'), radix: 16) ?? 0;

        // Priority: ToUnicode CMap -> Identity mapping -> raw code
        if (fontInfo?.toUnicode != null &&
            fontInfo!.toUnicode!.containsKey(code)) {
          sb.writeCharCode(fontInfo.toUnicode![code]!);
        } else if (isIdentityEncoding && code > 0 && code < 0xFFFF) {
          // Identity encoding: code is Unicode directly
          sb.writeCharCode(code);
        } else if (code > 0 && code < 0xFFFF) {
          // Fallback: treat as Unicode
          sb.writeCharCode(code);
        }
      }
      return sb.toString();
    } else {
      // 1-byte decoding for simple fonts - 2 hex chars = 1 character code
      final sb = StringBuffer();
      for (var i = 0; i < content.length; i += 2) {
        final chunk = content.substring(
            i, i + 2 < content.length ? i + 2 : content.length);
        final code = int.tryParse(chunk.padRight(2, '0'), radix: 16) ?? 0;

        // First check ToUnicode CMap (for simple fonts with ToUnicode)
        if (fontInfo?.toUnicode != null &&
            fontInfo!.toUnicode!.containsKey(code)) {
          sb.writeCharCode(fontInfo.toUnicode![code]!);
        } else {
          // Apply font encoding
          final decoded = fontInfo?.decodeChar(code) ?? code;
          if (decoded > 0) {
            sb.writeCharCode(decoded);
          }
        }
      }
      return sb.toString();
    }
  }

  String _decodeLiteralString(String s, PdfGraphicsState state) {
    final fontInfo = fonts[state.fontName];
    final sb = StringBuffer();
    var i = 0;

    while (i < s.length) {
      if (s[i] == '\\' && i + 1 < s.length) {
        switch (s[i + 1]) {
          case 'n':
            sb.write('\n');
            i += 2;
            break;
          case 'r':
            sb.write('\r');
            i += 2;
            break;
          case 't':
            sb.write('\t');
            i += 2;
            break;
          case 'b':
            sb.write('\b');
            i += 2;
            break;
          case 'f':
            sb.write('\f');
            i += 2;
            break;
          case '(':
            sb.write('(');
            i += 2;
            break;
          case ')':
            sb.write(')');
            i += 2;
            break;
          case '\\':
            sb.write('\\');
            i += 2;
            break;
          default:
            // Octal escape
            if (s[i + 1].codeUnitAt(0) >= 48 && s[i + 1].codeUnitAt(0) <= 55) {
              var end = i + 2;
              while (end < s.length &&
                  end < i + 4 &&
                  s[end].codeUnitAt(0) >= 48 &&
                  s[end].codeUnitAt(0) <= 55) {
                end++;
              }
              final octal = s.substring(i + 1, end);
              final code = int.tryParse(octal, radix: 8) ?? 0;
              sb.writeCharCode(fontInfo?.decodeChar(code) ?? code);
              i = end;
            } else {
              sb.write(s[i + 1]);
              i += 2;
            }
        }
      } else {
        final code = s.codeUnitAt(i);
        sb.writeCharCode(fontInfo?.decodeChar(code) ?? code);
        i++;
      }
    }

    return sb.toString();
  }

  String _extractDictionary(String content, int openIndex) {
    var depth = 1;
    var current = openIndex + 2;
    while (depth > 0 && current < content.length) {
      if (content.startsWith('<<', current)) {
        depth++;
        current += 2;
      } else if (content.startsWith('>>', current)) {
        depth--;
        if (depth == 0) break;
        current += 2;
      } else {
        current++;
      }
    }
    return content.substring(openIndex + 2, current);
  }
}
