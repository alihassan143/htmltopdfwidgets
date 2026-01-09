import 'pdf_parser.dart';
import 'pdf_types.dart';

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

    // Get Encoding
    final encodingMatch = RegExp(r'/Encoding\s*/(\w+)').firstMatch(obj.content);
    if (encodingMatch != null) {
      encoding = encodingMatch.group(1);
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
    }

    return PdfFontInfo(
      name: name,
      baseFont: baseFont,
      isBold: isBold,
      isItalic: isItalic,
      encoding: encoding,
      toUnicode: toUnicode,
      isEmbedded: isEmbedded,
      subtype: subtype,
    );
  }

  /// Parses text from a content stream.
  List<PdfTextLine> extractText(String stream) {
    if (stream.trim().isEmpty) return [];

    final lines = <PdfTextLine>[];
    var state = PdfGraphicsState();
    final stateStack = <PdfGraphicsState>[];
    final tokens = parser.tokenize(stream);

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];

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
          }
          break;

        case 'Td':
          if (i >= 2) {
            final tx = double.tryParse(tokens[i - 2]) ?? 0;
            final ty = double.tryParse(tokens[i - 1]) ?? 0;
            final mat = PdfMatrix(1, 0, 0, 1, tx, ty);
            state.textLineMatrix = mat.multiply(state.textLineMatrix);
            state.textMatrix = state.textLineMatrix.clone();
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
          }
          break;

        case 'T*':
          // Move to start of next line (using current leading)
          state.textLineMatrix = PdfMatrix(1, 0, 0, 1, 0, -state.fontSize * 1.2)
              .multiply(state.textLineMatrix);
          state.textMatrix = state.textLineMatrix.clone();
          break;

        case 'Tf':
          if (i >= 2) {
            state.fontName = tokens[i - 2];
            state.fontSize = double.tryParse(tokens[i - 1]) ?? 12;
          }
          break;

        case 'Tc':
          if (i >= 1) {
            state.charSpacing = double.tryParse(tokens[i - 1]) ?? 0;
          }
          break;

        case 'Tw':
          if (i >= 1) {
            state.wordSpacing = double.tryParse(tokens[i - 1]) ?? 0;
          }
          break;

        case 'Ts':
          if (i >= 1) {
            state.textRise = double.tryParse(tokens[i - 1]) ?? 0;
          }
          break;

        case 'Tj':
          if (i >= 1) {
            final textLine = _processTextString(tokens[i - 1], state);
            if (textLine != null) lines.add(textLine);
          }
          break;

        case 'TJ':
          if (i >= 1) {
            final textLines = _processTextArray(tokens[i - 1], state);
            lines.addAll(textLines);
          }
          break;

        case "'":
          // Move to next line and show text
          state.textLineMatrix = PdfMatrix(1, 0, 0, 1, 0, -state.fontSize * 1.2)
              .multiply(state.textLineMatrix);
          state.textMatrix = state.textLineMatrix.clone();
          if (i >= 1) {
            final textLine = _processTextString(tokens[i - 1], state);
            if (textLine != null) lines.add(textLine);
          }
          break;

        case 'rg':
          if (i >= 3) {
            state.fillColorR = double.tryParse(tokens[i - 3]) ?? 0;
            state.fillColorG = double.tryParse(tokens[i - 2]) ?? 0;
            state.fillColorB = double.tryParse(tokens[i - 1]) ?? 0;
          }
          break;

        case 'RG':
          if (i >= 3) {
            state.strokeColorR = double.tryParse(tokens[i - 3]) ?? 0;
            state.strokeColorG = double.tryParse(tokens[i - 2]) ?? 0;
            state.strokeColorB = double.tryParse(tokens[i - 1]) ?? 0;
          }
          break;

        case 'g':
          if (i >= 1) {
            final gray = double.tryParse(tokens[i - 1]) ?? 0;
            state.fillColorR = gray;
            state.fillColorG = gray;
            state.fillColorB = gray;
          }
          break;

        case 'G':
          if (i >= 1) {
            final gray = double.tryParse(tokens[i - 1]) ?? 0;
            state.strokeColorR = gray;
            state.strokeColorG = gray;
            state.strokeColorB = gray;
          }
          break;
      }
    }

    return lines;
  }

  PdfTextLine? _processTextString(String textEntry, PdfGraphicsState state) {
    var text = textEntry;

    // Handle hex strings
    if (text.startsWith('<') && text.endsWith('>')) {
      text = _decodeHexString(text, state);
    } else if (text.startsWith('(') && text.endsWith(')')) {
      text = _decodeLiteralString(text.substring(1, text.length - 1), state);
    }

    if (text.isEmpty) return null;

    final mat = state.textMatrix.multiply(state.ctm);
    final fontInfo = fonts[state.fontName];

    final line = PdfTextLine(
      text: text,
      x: mat.e,
      y: mat.f,
      font: state.fontName,
      size: state.fontSize * mat.scale,
      colorR: state.fillColorR,
      colorG: state.fillColorG,
      colorB: state.fillColorB,
      textRise: state.textRise,
      fontInfo: fontInfo,
    );

    if (fontInfo != null) {
      line.isBold = fontInfo.isBold;
      line.isItalic = fontInfo.isItalic;
    }

    // Advance text matrix
    final width = text.length * state.fontSize * 0.5;
    state.textMatrix =
        PdfMatrix(1, 0, 0, 1, width, 0).multiply(state.textMatrix);

    return line;
  }

  List<PdfTextLine> _processTextArray(
      String arrayEntry, PdfGraphicsState state) {
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
