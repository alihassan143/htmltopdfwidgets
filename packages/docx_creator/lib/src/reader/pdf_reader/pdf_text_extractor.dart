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
  int? _glyphNameToUnicode(String name) {
    // Common glyph names mapping
    const glyphMap = <String, int>{
      'space': 0x0020,
      'exclam': 0x0021,
      'quotedbl': 0x0022,
      'numbersign': 0x0023,
      'dollar': 0x0024,
      'percent': 0x0025,
      'ampersand': 0x0026,
      'quotesingle': 0x0027,
      'parenleft': 0x0028,
      'parenright': 0x0029,
      'asterisk': 0x002A,
      'plus': 0x002B,
      'comma': 0x002C,
      'hyphen': 0x002D,
      'period': 0x002E,
      'slash': 0x002F,
      'zero': 0x0030,
      'one': 0x0031,
      'two': 0x0032,
      'three': 0x0033,
      'four': 0x0034,
      'five': 0x0035,
      'six': 0x0036,
      'seven': 0x0037,
      'eight': 0x0038,
      'nine': 0x0039,
      'colon': 0x003A,
      'semicolon': 0x003B,
      'less': 0x003C,
      'equal': 0x003D,
      'greater': 0x003E,
      'question': 0x003F,
      'at': 0x0040,
      'A': 0x0041, 'B': 0x0042, 'C': 0x0043, 'D': 0x0044, 'E': 0x0045,
      'F': 0x0046, 'G': 0x0047, 'H': 0x0048, 'I': 0x0049, 'J': 0x004A,
      'K': 0x004B, 'L': 0x004C, 'M': 0x004D, 'N': 0x004E, 'O': 0x004F,
      'P': 0x0050, 'Q': 0x0051, 'R': 0x0052, 'S': 0x0053, 'T': 0x0054,
      'U': 0x0055, 'V': 0x0056, 'W': 0x0057, 'X': 0x0058, 'Y': 0x0059,
      'Z': 0x005A,
      'bracketleft': 0x005B,
      'backslash': 0x005C,
      'bracketright': 0x005D,
      'asciicircum': 0x005E,
      'underscore': 0x005F,
      'grave': 0x0060,
      'a': 0x0061, 'b': 0x0062, 'c': 0x0063, 'd': 0x0064, 'e': 0x0065,
      'f': 0x0066, 'g': 0x0067, 'h': 0x0068, 'i': 0x0069, 'j': 0x006A,
      'k': 0x006B, 'l': 0x006C, 'm': 0x006D, 'n': 0x006E, 'o': 0x006F,
      'p': 0x0070, 'q': 0x0071, 'r': 0x0072, 's': 0x0073, 't': 0x0074,
      'u': 0x0075, 'v': 0x0076, 'w': 0x0077, 'x': 0x0078, 'y': 0x0079,
      'z': 0x007A,
      'braceleft': 0x007B,
      'bar': 0x007C,
      'braceright': 0x007D,
      'asciitilde': 0x007E,
      // Extended characters
      'bullet': 0x2022,
      'endash': 0x2013,
      'emdash': 0x2014,
      'quoteleft': 0x2018,
      'quoteright': 0x2019,
      'quotedblleft': 0x201C,
      'quotedblright': 0x201D,
      'ellipsis': 0x2026,
      'trademark': 0x2122,
      'copyright': 0x00A9,
      'registered': 0x00AE,
      'degree': 0x00B0,
      'plusminus': 0x00B1,
      'multiply': 0x00D7,
      'divide': 0x00F7,
      'fi': 0xFB01,
      'fl': 0xFB02,
      // Accented characters
      'Agrave': 0x00C0, 'Aacute': 0x00C1, 'Acircumflex': 0x00C2,
      'Atilde': 0x00C3, 'Adieresis': 0x00C4, 'Aring': 0x00C5,
      'AE': 0x00C6, 'Ccedilla': 0x00C7,
      'Egrave': 0x00C8, 'Eacute': 0x00C9, 'Ecircumflex': 0x00CA,
      'Edieresis': 0x00CB,
      'Igrave': 0x00CC, 'Iacute': 0x00CD, 'Icircumflex': 0x00CE,
      'Idieresis': 0x00CF,
      'Ntilde': 0x00D1,
      'Ograve': 0x00D2, 'Oacute': 0x00D3, 'Ocircumflex': 0x00D4,
      'Otilde': 0x00D5, 'Odieresis': 0x00D6, 'Oslash': 0x00D8,
      'Ugrave': 0x00D9, 'Uacute': 0x00DA, 'Ucircumflex': 0x00DB,
      'Udieresis': 0x00DC,
      'Yacute': 0x00DD, 'germandbls': 0x00DF,
      'agrave': 0x00E0, 'aacute': 0x00E1, 'acircumflex': 0x00E2,
      'atilde': 0x00E3, 'adieresis': 0x00E4, 'aring': 0x00E5,
      'ae': 0x00E6, 'ccedilla': 0x00E7,
      'egrave': 0x00E8, 'eacute': 0x00E9, 'ecircumflex': 0x00EA,
      'edieresis': 0x00EB,
      'igrave': 0x00EC, 'iacute': 0x00ED, 'icircumflex': 0x00EE,
      'idieresis': 0x00EF,
      'ntilde': 0x00F1,
      'ograve': 0x00F2, 'oacute': 0x00F3, 'ocircumflex': 0x00F4,
      'otilde': 0x00F5, 'odieresis': 0x00F6, 'oslash': 0x00F8,
      'ugrave': 0x00F9, 'uacute': 0x00FA, 'ucircumflex': 0x00FB,
      'udieresis': 0x00FC,
      'yacute': 0x00FD, 'ydieresis': 0x00FF,
      // Currency
      'Euro': 0x20AC,
      'cent': 0x00A2,
      'sterling': 0x00A3,
      'yen': 0x00A5,
    };

    if (glyphMap.containsKey(name)) {
      return glyphMap[name];
    }

    // Handle uniXXXX format
    if (name.startsWith('uni') && name.length >= 7) {
      final hex = name.substring(3, 7);
      return int.tryParse(hex, radix: 16);
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

    return lines;
  }

  /// Extracts text as a formatted string using the specified [mode].
  String extractTextString(String stream,
      {PdfExtractionMode mode = PdfExtractionMode.plain}) {
    final lines = extractText(stream);

    // Sort lines by position (Top-down, Left-right)
    lines.sort((a, b) {
      if ((a.y - b.y).abs() > a.size * 0.5) {
        return b.y.compareTo(a.y);
      }
      return a.x.compareTo(b.x);
    });

    final buffer = StringBuffer();

    if (mode == PdfExtractionMode.plain) {
      for (final line in lines) {
        buffer.write(line.text);
        buffer.write(' ');
      }
      return buffer.toString().trim();
    }

    // Layout mode
    double? lastY;
    double? lastX;

    for (final line in lines) {
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

    // Check if this is a CID font (2 bytes per char)
    final isCID = fontInfo != null &&
        (fontInfo.subtype == 'Type0' || fontInfo.subtype == 'CIDFontType2');

    if (isCID || content.length >= 4) {
      // Try 2-byte decoding
      final sb = StringBuffer();
      for (var i = 0; i < content.length; i += 4) {
        final chunk = content.substring(
            i, i + 4 < content.length ? i + 4 : content.length);
        final code = int.tryParse(chunk.padRight(4, '0'), radix: 16) ?? 0;

        if (fontInfo?.toUnicode != null &&
            fontInfo!.toUnicode!.containsKey(code)) {
          sb.writeCharCode(fontInfo.toUnicode![code]!);
        } else {
          sb.writeCharCode(code);
        }
      }
      return sb.toString();
    } else {
      // 1-byte decoding
      final sb = StringBuffer();
      for (var i = 0; i < content.length; i += 2) {
        final chunk = content.substring(
            i, i + 2 < content.length ? i + 2 : content.length);
        final code = int.tryParse(chunk.padRight(2, '0'), radix: 16) ?? 0;
        sb.writeCharCode(fontInfo?.decodeChar(code) ?? code);
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
