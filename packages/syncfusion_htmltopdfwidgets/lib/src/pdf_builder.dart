import 'dart:typed_data';

import 'package:flutter/material.dart'
    show Color, Colors, FontWeight, FontStyle, TextDecoration, Rect;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'htmltagstyles.dart';
import 'parser/css_style.dart';
import 'parser/render_node.dart';
import 'parser/text_layout.dart';

class PdfBuilder {
  final RenderNode root;
  final PdfDocument document;
  final HtmlTagStyle tagStyle;

  PdfLayoutResult? _lastResult;
  final double _pageWidth = 515; // A4 width minus margins approx

  // Font data cache for fallback fonts (raw bytes)
  Uint8List? _notoSansFontData;
  Uint8List? _notoArabicFontData;
  Uint8List? _notoCJKFontData;
  Uint8List? _notoEmojiFontData;
  bool _fontsLoaded = false;

  get _currentPage => _lastResult?.page ?? document.pages[0];
  get _currentY => _lastResult?.bounds.bottom ?? 0;

  PdfBuilder({
    required this.root,
    required this.document,
    this.tagStyle = const HtmlTagStyle(),
  });

  /// Load fallback fonts from assets
  Future<void> _loadFallbackFonts() async {
    if (_fontsLoaded) return;

    try {
      // Load NotoSans for extended Latin, CJK, emoji fallback
      try {
        final data = await rootBundle.load(
            'packages/htmltopdfwidgets_syncfusion/assets/fonts/NotoSans-Regular.ttf');
        _notoSansFontData = data.buffer.asUint8List();
      } catch (_) {
        try {
          final data =
              await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
          _notoSansFontData = data.buffer.asUint8List();
        } catch (_) {}
      }

      // Load NotoSansArabic for Arabic script
      try {
        final data = await rootBundle.load(
            'packages/htmltopdfwidgets_syncfusion/assets/fonts/NotoSansArabic-Regular.ttf');
        _notoArabicFontData = data.buffer.asUint8List();
      } catch (_) {
        try {
          final data =
              await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
          _notoArabicFontData = data.buffer.asUint8List();
        } catch (_) {}
      }
      try {
        final data = await rootBundle.load(
            'packages/htmltopdfwidgets_syncfusion/assets/fonts/NotoEmoji-Regular.ttf');
        _notoEmojiFontData = data.buffer.asUint8List();
      } catch (_) {
        try {
          final data =
              await rootBundle.load('assets/fonts/NotoEmoji-Regular.ttf');
          _notoEmojiFontData = data.buffer.asUint8List();
        } catch (_) {
          // Fall back to NotoSans if emoji font not available
          _notoEmojiFontData = _notoSansFontData;
        }
      }

      // Use NotoSans for CJK and emoji as well (limited support but better than nothing)
      // _notoCJKFontData = _notoSansFontData;

      // Load DroidSansFallback for CJK
      try {
        final data = await rootBundle.load(
            'packages/htmltopdfwidgets_syncfusion/assets/fonts/DroidSansFallback.ttf');
        _notoCJKFontData = data.buffer.asUint8List();
      } catch (_) {
        try {
          final data =
              await rootBundle.load('assets/fonts/DroidSansFallback.ttf');
          _notoCJKFontData = data.buffer.asUint8List();
        } catch (_) {
          // Fallback to NotoSans if DroidSans is missing (unlikely now)
          _notoCJKFontData = _notoSansFontData;
        }
      }

      _fontsLoaded = true;
    } catch (e) {
      debugPrint('Warning: Could not load fallback fonts: $e');
    }
  }

  Future<void> build() async {
    if (document.pages.count == 0) {
      document.pages.add();
    }

    // Load fallback fonts before building
    await _loadFallbackFonts();

    await _drawNode(root);
  }

  Future<void> _drawNode(RenderNode node,
      {String? listType, int? listIndex}) async {
    if (node.display == Display.none) return;

    // Detect Block vs Inline
    bool isBlock = node.display == Display.block ||
        node.tagName == 'div' ||
        node.tagName == 'p' ||
        node.tagName.startsWith('h') ||
        node.tagName == 'ul' ||
        node.tagName == 'ol' ||
        node.tagName == 'li' ||
        node.tagName == 'blockquote' ||
        node.tagName == 'body';

    // Draw List Marker if this is an LI
    if (node.tagName == 'li' && listType != null) {
      String marker = '';
      if (listType == 'ul') {
        marker = '•';
      } else if (listType == 'ol' && listIndex != null) {
        marker = '$listIndex.';
      }

      if (marker.isNotEmpty) {
        final font = await _resolveFont(node.style);
        double x = 0;
        final margin = node.style.margin;
        if (margin != null) x += margin.left;

        // Indent for marker (rough approximation)
        x += 10;

        double y = _currentY;
        if (margin != null) y += margin.top;

        PdfPage page = _currentPage;
        page.graphics.drawString(marker, font,
            brush: PdfSolidBrush(PdfColor(0, 0, 0)),
            bounds: Rect.fromLTWH(x, y, 20, 0));
      }
    }

    if (node.tagName == 'img') {
      await _drawImage(node);
      return;
    }

    if (node.tagName == 'table') {
      await _drawTable(node);
      return;
    }

    if (isBlock) {
      bool hasBlockChildren = node.children.any((c) =>
          c.display == Display.block ||
          c.tagName == 'div' ||
          c.tagName == 'p' ||
          c.tagName == 'blockquote' ||
          c.tagName.startsWith('h') ||
          c.tagName == 'ul' ||
          c.tagName == 'ol' ||
          c.tagName == 'li');

      if (!hasBlockChildren) {
        // Leaf Block: Layout text and draw
        await _drawLeafBlock(node);
      } else {
        // Determine list context for children
        String? nextListType = listType;
        int? nextListIndex = listIndex;

        if (node.tagName == 'ul') {
          nextListType = 'ul';
        } else if (node.tagName == 'ol') {
          nextListType = 'ol';
          nextListIndex = 0;
        }

        for (var child in node.children) {
          // Increment index for OL items
          int? childIndex = nextListIndex;
          if (nextListType == 'ol' &&
              child.tagName == 'li' &&
              nextListIndex != null) {
            nextListIndex = nextListIndex + 1;
            childIndex = nextListIndex;
          }

          await _drawNode(child, listType: nextListType, listIndex: childIndex);
        }
      }
    } else {
      if (node.tagName == '#text') {
        await _drawLeafBlock(RenderNode(
            tagName: 'span', style: node.style, text: node.text, children: []));
      } else {
        for (var child in node.children) {
          await _drawNode(child);
        }
      }
    }
  }

  Future<void> _drawLeafBlock(RenderNode node) async {
    // 1. Flatten children to Spans (with font fallback)
    List<LayoutSpan> spans = [];
    await _collectSpansWithFallback(node, spans);

    if (spans.isEmpty) {
      // Even if empty, we might need to draw background/borders (e.g. empty div)
      // For now, continue if we have style??
      // If purely empty text, return.
      // But if it has dimensions...
      if (node.style.height == null && node.style.padding == null) return;
    }

    // 2. Perform Layout
    double indent = 0;

    // Null safety access
    final padding = node.style.padding;
    final margin = node.style.margin;

    if (padding != null) indent += padding.left;
    if (margin != null) indent += margin.left;

    double maxWidth = _pageWidth - indent;
    if (padding != null) maxWidth -= padding.right;
    if (margin != null) maxWidth -= margin.right;

    LayoutResult layout =
        TextLayout.performLayout(spans: spans, maxWidth: maxWidth);

    // 3. Draw Background / Border
    double startY = _currentY;
    if (margin != null) startY += margin.top;

    double pageHeight = _currentPage.getClientSize().height;

    PdfPage currentPage = _currentPage;
    double currentY = startY;

    double globalX = 0;
    if (margin != null) globalX += margin.left;

    // Pagination Split Calculation
    List<List<LayoutLine>> pagesOfLines = [];
    List<LayoutLine> currentBuffer = [];
    double currentHeightUsage = 0;

    // If no content (just bg/border), create pseudo-line?
    if (layout.lines.isEmpty &&
        (node.style.height != null || padding != null)) {
      // Handle empty block case if needed, or just let it be 0 height
    }

    double initialAvail = pageHeight - startY;

    for (var line in layout.lines) {
      if (currentHeightUsage + line.height > initialAvail) {
        pagesOfLines.add(currentBuffer);
        currentBuffer = [];
        currentHeightUsage = 0;
        initialAvail = pageHeight;

        currentBuffer.add(line);
        currentHeightUsage += line.height;
      } else {
        currentBuffer.add(line);
        currentHeightUsage += line.height;
      }
    }
    if (currentBuffer.isNotEmpty) pagesOfLines.add(currentBuffer);

    // Prepare Border/Bg Colors
    final bgColor = node.style.backgroundColor;
    final border = node.style.border;

    // Draw Lines
    for (int i = 0; i < pagesOfLines.length; i++) {
      var lines = pagesOfLines[i];

      if (i > 0) {
        currentPage = document.pages.add();
        currentY = 0;
      }

      // Compute height of this chunk
      double chunkHeight = lines.fold(0.0, (s, l) => s + l.height);
      // Add padding to height
      if (padding != null) {
        chunkHeight +=
            padding.top + padding.bottom; // Simplified padding handling
      }

      // If spans are empty but we have padding/height
      if (lines.isEmpty && padding != null) {
        chunkHeight += padding.top + padding.bottom;
      }

      // Draw Background if needed
      if (bgColor != null) {
        currentPage.graphics.drawRectangle(
            brush: PdfSolidBrush(_resolveColor(bgColor)),
            bounds: Rect.fromLTWH(
                globalX,
                currentY,
                layout.width + (padding?.horizontal ?? 0),
                chunkHeight)); // Adjust width for padding
      }

      // Draw Borders (Individual sides)
      if (border != null) {
        final rect = Rect.fromLTWH(globalX, currentY,
            layout.width + (padding?.horizontal ?? 0), chunkHeight);

        if (border.left.style != BorderStyle.none && border.left.width > 0) {
          currentPage.graphics.drawRectangle(
              brush: PdfSolidBrush(_resolveColor(border.left.color)),
              bounds: Rect.fromLTWH(
                  rect.left, rect.top, border.left.width, rect.height));
        }
        if (border.right.style != BorderStyle.none && border.right.width > 0) {
          currentPage.graphics.drawRectangle(
              brush: PdfSolidBrush(_resolveColor(border.right.color)),
              bounds: Rect.fromLTWH(rect.right - border.right.width, rect.top,
                  border.right.width, rect.height));
        }
        if (border.top.style != BorderStyle.none && border.top.width > 0) {
          currentPage.graphics.drawRectangle(
              brush: PdfSolidBrush(_resolveColor(border.top.color)),
              bounds: Rect.fromLTWH(
                  rect.left, rect.top, rect.width, border.top.width));
        }
        if (border.bottom.style != BorderStyle.none &&
            border.bottom.width > 0) {
          currentPage.graphics.drawRectangle(
              brush: PdfSolidBrush(_resolveColor(border.bottom.color)),
              bounds: Rect.fromLTWH(
                  rect.left,
                  rect.bottom - border.bottom.width,
                  rect.width,
                  border.bottom.width));
        }
      }

      // Apply padding offset for text
      double textStartY = currentY + (padding?.top ?? 0);

      for (var line in lines) {
        for (var span in line.spans) {
          // Resolve style
          final spanColor = span.style.color ?? Colors.black;

          currentPage.graphics.drawString(span.text, span.font,
              brush: PdfSolidBrush(_resolveColor(spanColor)),
              bounds: Rect.fromLTWH(globalX + span.x + (padding?.left ?? 0),
                  textStartY + span.y, span.width, span.height));
        }
        textStartY += line.height;
      }

      currentY += chunkHeight;

      // Add bottom margin
      if (margin != null) currentY += margin.bottom;
    }

    // Update Result to track end
    var element = PdfTextElement(
        text: " ", font: PdfStandardFont(PdfFontFamily.helvetica, 1));
    _lastResult = element.draw(
        page: currentPage, bounds: Rect.fromLTWH(0, currentY, 0, 0));
  }

  /// Collect spans with character-level font fallback
  Future<void> _collectSpansWithFallback(
      RenderNode node, List<LayoutSpan> spans) async {
    if (node.text != null && node.text!.isNotEmpty) {
      final text = node.text!;
      final baseFont = await _resolveFont(node.style);
      final fontSize = node.style.fontSize ?? 12;

      // Split text into segments by character type
      List<_TextSegment> segments = _segmentTextByCharType(text);

      for (var segment in segments) {
        PdfFont font;
        String spanText = segment.text;

        switch (segment.type) {
          case _CharType.arabic:
            font = _getFallbackFont(_notoArabicFontData, fontSize) ?? baseFont;
            // Reshape Arabic text to fix disjointed characters
            try {
              if (spanText.trim().isNotEmpty) {
                // TODO: Fix Arabic reshaping API. 'Arabic' class found but method unknown.
                // spanText = Arabic.convert(spanText);
              }
            } catch (e) {
              debugPrint('Error reshaping Arabic text: $e');
            }
            break;
          case _CharType.cjk:
            font = _getFallbackFont(_notoCJKFontData, fontSize) ?? baseFont;
            break;
          case _CharType.emoji:
            // Use Noto Emoji font for emoji characters
            font = _getFallbackFont(_notoEmojiFontData, fontSize) ??
                _getFallbackFont(_notoSansFontData, fontSize) ??
                baseFont;
            break;
          case _CharType.extended:
            // Extended Latin, Cyrillic, etc.
            font = _getFallbackFont(_notoSansFontData, fontSize) ?? baseFont;
            break;
          case _CharType.standard:
            font = baseFont;
        }

        PdfStringFormat? format;
        if (segment.type == _CharType.arabic ||
            node.style.textDirection == TextDirection.rtl) {
          format = PdfStringFormat(
            textDirection: PdfTextDirection.rightToLeft,
            alignment: PdfTextAlignment.right,
            lineAlignment: PdfVerticalAlignment.top,
          );
        }

        spans.add(LayoutSpan(
          text: spanText,
          style: node.style,
          font: font,
          format: format,
        ));
      }
    }

    for (var child in node.children) {
      await _collectSpansWithFallback(child, spans);
    }
  }

  /// Get a fallback font with the correct size
  PdfFont? _getFallbackFont(Uint8List? fontData, double fontSize) {
    if (fontData == null) return null;
    // Create new font with correct size
    return PdfTrueTypeFont(fontData, fontSize);
  }

  /// Segment text by character type for font fallback
  List<_TextSegment> _segmentTextByCharType(String text) {
    List<_TextSegment> segments = [];
    if (text.isEmpty) return segments;

    StringBuffer currentBuffer = StringBuffer();
    _CharType? currentType;

    for (int i = 0; i < text.length; i++) {
      int codePoint = text.codeUnitAt(i);

      // Handle surrogate pairs for emoji
      if (i + 1 < text.length && codePoint >= 0xD800 && codePoint <= 0xDBFF) {
        int lowSurrogate = text.codeUnitAt(i + 1);
        if (lowSurrogate >= 0xDC00 && lowSurrogate <= 0xDFFF) {
          codePoint =
              0x10000 + ((codePoint - 0xD800) << 10) + (lowSurrogate - 0xDC00);
          i++; // Skip low surrogate
        }
      }

      _CharType charType = _getCharType(codePoint);

      if (currentType == null) {
        currentType = charType;
        currentBuffer.write(String.fromCharCode(codePoint));
      } else if (charType == currentType) {
        currentBuffer.write(String.fromCharCode(codePoint));
      } else {
        // Save current segment and start new one
        if (currentBuffer.isNotEmpty) {
          segments.add(_TextSegment(currentBuffer.toString(), currentType));
        }
        currentBuffer = StringBuffer();
        currentBuffer.write(String.fromCharCode(codePoint));
        currentType = charType;
      }
    }

    // Add final segment
    if (currentBuffer.isNotEmpty && currentType != null) {
      segments.add(_TextSegment(currentBuffer.toString(), currentType));
    }

    return segments;
  }

  /// Determine the character type for font selection
  _CharType _getCharType(int codePoint) {
    // Emoji ranges
    if (_isEmoji(codePoint)) {
      return _CharType.emoji;
    }

    // Arabic range (0x0600–0x06FF, 0x0750–0x077F, 0x08A0–0x08FF, 0xFB50–0xFDFF, 0xFE70–0xFEFF)
    if (_isArabic(codePoint)) {
      return _CharType.arabic;
    }

    // CJK ranges
    if (_isCJK(codePoint)) {
      return _CharType.cjk;
    }

    // Extended Latin, Cyrillic, Greek, etc. (above basic ASCII)
    if (codePoint > 0x024F) {
      return _CharType.extended;
    }

    return _CharType.standard;
  }

  bool _isEmoji(int codePoint) {
    // Common emoji ranges
    return (codePoint >= 0x1F600 && codePoint <= 0x1F64F) || // Emoticons
        (codePoint >= 0x1F300 && codePoint <= 0x1F5FF) || // Misc Symbols
        (codePoint >= 0x1F680 && codePoint <= 0x1F6FF) || // Transport
        (codePoint >= 0x1F1E0 && codePoint <= 0x1F1FF) || // Flags
        (codePoint >= 0x2600 && codePoint <= 0x26FF) || // Misc symbols
        (codePoint >= 0x2700 && codePoint <= 0x27BF) || // Dingbats
        (codePoint >= 0xFE00 && codePoint <= 0xFE0F) || // Variation Selectors
        (codePoint >= 0x1F900 &&
            codePoint <= 0x1F9FF) || // Supplemental Symbols
        (codePoint >= 0x1FA00 && codePoint <= 0x1FA6F) || // Chess Symbols
        (codePoint >= 0x1FA70 && codePoint <= 0x1FAFF) || // Symbols Extended-A
        (codePoint >= 0x231A && codePoint <= 0x231B) || // Watch, Hourglass
        (codePoint >= 0x23E9 && codePoint <= 0x23F3) || // Media controls
        (codePoint >= 0x23F8 && codePoint <= 0x23FA); // Media controls
  }

  bool _isArabic(int codePoint) {
    return (codePoint >= 0x0600 && codePoint <= 0x06FF) || // Arabic
        (codePoint >= 0x0750 && codePoint <= 0x077F) || // Arabic Supplement
        (codePoint >= 0x08A0 && codePoint <= 0x08FF) || // Arabic Extended-A
        (codePoint >= 0xFB50 && codePoint <= 0xFDFF) || // Arabic Pres. Forms-A
        (codePoint >= 0xFE70 && codePoint <= 0xFEFF); // Arabic Pres. Forms-B
  }

  bool _isCJK(int codePoint) {
    return (codePoint >= 0x4E00 && codePoint <= 0x9FFF) || // CJK Unified
        (codePoint >= 0x3400 && codePoint <= 0x4DBF) || // CJK Extension A
        (codePoint >= 0x20000 && codePoint <= 0x2A6DF) || // CJK Extension B
        (codePoint >= 0x2A700 && codePoint <= 0x2B73F) || // CJK Extension C
        (codePoint >= 0x2B740 && codePoint <= 0x2B81F) || // CJK Extension D
        (codePoint >= 0xF900 && codePoint <= 0xFAFF) || // CJK Compatibility
        (codePoint >= 0x3000 && codePoint <= 0x303F) || // CJK Punctuation
        (codePoint >= 0x3040 && codePoint <= 0x309F) || // Hiragana
        (codePoint >= 0x30A0 && codePoint <= 0x30FF) || // Katakana
        (codePoint >= 0xAC00 && codePoint <= 0xD7AF); // Korean Hangul
  }

  Future<void> _drawImage(RenderNode node) async {
    final src = node.attributes['src'];
    if (src == null) return;

    Uint8List? imageBytes;

    if (src.startsWith('http')) {
      final response = await http.get(Uri.parse(src));
      if (response.statusCode == 200) {
        imageBytes = response.bodyBytes;
      }
    } else if (src.startsWith('assets/')) {
      try {
        final data = await rootBundle.load(src);
        imageBytes = data.buffer.asUint8List();
      } catch (e) {
        debugPrint('Error loading asset: $e');
      }
    }

    if (imageBytes != null) {
      final bitmap = PdfBitmap(imageBytes);
      double width = node.style.width ?? bitmap.width.toDouble();
      double height = node.style.height ?? bitmap.height.toDouble();

      PdfPage? page = _lastResult?.page ?? document.pages[0];
      double y = _lastResult?.bounds.bottom ?? 0;

      _lastResult =
          bitmap.draw(page: page, bounds: Rect.fromLTWH(0, y, width, height));
    }
  }

  Future<void> _drawTable(RenderNode node) async {
    final grid = PdfGrid();

    List<RenderNode> trs = [];
    void findTrs(RenderNode n) {
      if (n.tagName == 'tr') {
        trs.add(n);
      } else {
        n.children.forEach(findTrs);
      }
    }

    findTrs(node);

    if (trs.isEmpty) return;

    int maxCols = 0;
    for (var tr in trs) {
      int cols = tr.children
          .where((c) => c.tagName == 'td' || c.tagName == 'th')
          .length;
      if (cols > maxCols) {
        maxCols = cols;
      }
    }

    grid.columns.add(count: maxCols);

    for (var tr in trs) {
      final row = grid.rows.add();
      int colIndex = 0;
      for (var child in tr.children) {
        if (child.tagName == 'td' || child.tagName == 'th') {
          if (colIndex >= maxCols) {
            break;
          }

          row.cells[colIndex].value = child.text ?? _extractText(child);

          if (child.style.backgroundColor != null) {
            row.cells[colIndex].style.backgroundBrush =
                PdfSolidBrush(_resolveColor(child.style.backgroundColor!));
          } else if (node.style.backgroundColor != null) {
            row.cells[colIndex].style.backgroundBrush =
                PdfSolidBrush(_resolveColor(node.style.backgroundColor!));
          }

          colIndex++;
        }
      }
    }

    PdfPage? page = _lastResult?.page ?? document.pages[0];
    double y = _lastResult?.bounds.bottom ?? 0;

    _lastResult = grid.draw(page: page, bounds: Rect.fromLTWH(0, y, 0, 0));
  }

  String _extractText(RenderNode node) {
    if (node.text != null) return node.text!;
    return node.children.map((c) => _extractText(c)).join();
  }

  Future<PdfFont> _resolveFont(CSSStyle style) async {
    PdfFontFamily family = PdfFontFamily.helvetica;
    if (style.fontFamily != null) {
      var f = style.fontFamily!.toLowerCase();
      if (f.contains('courier')) family = PdfFontFamily.courier;
      if (f.contains('times')) family = PdfFontFamily.timesRoman;
      if (f.contains('symbol')) family = PdfFontFamily.symbol;
      if (f.contains('zapf')) family = PdfFontFamily.zapfDingbats;
    }

    List<PdfFontStyle> styles = [];
    if (style.fontWeight == FontWeight.bold) styles.add(PdfFontStyle.bold);
    if (style.fontStyle == FontStyle.italic) styles.add(PdfFontStyle.italic);
    if (style.textDecoration == TextDecoration.underline) {
      styles.add(PdfFontStyle.underline);
    } else if (style.textDecoration == TextDecoration.lineThrough) {
      styles.add(PdfFontStyle.strikethrough);
    }

    if (styles.isEmpty) {
      return PdfStandardFont(family, style.fontSize ?? 12,
          style: PdfFontStyle.regular);
    }
    return PdfStandardFont(family, style.fontSize ?? 12, multiStyle: styles);
  }

  PdfColor _resolveColor(Color color) {
    return PdfColor(
      (color.r * 255.0).round() & 0xff,
      (color.g * 255.0).round() & 0xff,
      (color.b * 255.0).round() & 0xff,
      (color.a * 255.0).round() & 0xff,
    );
  }
}

/// Internal helper class for text segmentation
class _TextSegment {
  final String text;
  final _CharType type;

  _TextSegment(this.text, this.type);
}

/// Character type for font selection
enum _CharType {
  standard, // Basic Latin (ASCII)
  extended, // Extended Latin, Cyrillic, Greek, etc.
  arabic, // Arabic script
  cjk, // Chinese, Japanese, Korean
  emoji, // Emoji characters
}
