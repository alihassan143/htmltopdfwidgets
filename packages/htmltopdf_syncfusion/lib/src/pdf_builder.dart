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
      {String? listType, int? listIndex, double parentX = 0}) async {
    if (node.display == Display.none) return;

    // Calculate current content offset
    double currentX = parentX;
    final margin = node.style.margin;
    if (margin != null) currentX += margin.left;
    final padding = node.style.padding;
    double contentX = currentX;
    if (padding != null) contentX += padding.left;

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

    // Check for checkbox child to suppress marker
    bool hasCheckbox =
        node.children.isNotEmpty && node.children.first.tagName == 'checkbox';

    // Draw List Marker if this is an LI
    if (node.tagName == 'li' && listType != null && !hasCheckbox) {
      String marker = '';
      if (listType == 'ul') {
        marker =
            '-'; // Unicode bullet \u2022 fails in some contexts, hyphen is safer
      } else if (listType == 'ol' && listIndex != null) {
        marker = '$listIndex.';
      }

      if (marker.isNotEmpty) {
        final font = await _resolveFont(node.style);

        // Marker Indent: relative to currentX (which includes margin)
        // We want to draw it slightly into the margin area.
        // If margin was 20, currentX is parentX + 20.
        // We want marker at parentX + 5.
        // So (currentX - 15).

        // Ensure we don't go below parentX (or 0)
        double markerX = currentX >= 15 ? currentX - 15 : currentX;

        double y = _currentY;
        if (margin != null) y += margin.top;

        PdfPage page = _currentPage;
        page.graphics.drawString(marker, font,
            brush: PdfSolidBrush(PdfColor(0, 0, 0)),
            bounds: Rect.fromLTWH(markerX, y, 20, 0));
      }
    }

    if (node.tagName == 'img') {
      await _drawImage(node, parentX: parentX);
      return;
    }

    if (node.tagName == 'checkbox') {
      await _drawCheckbox(node, parentX: parentX);
      return;
    }

    if (node.tagName == 'table') {
      await _drawTable(node, parentX: parentX);
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
        await _drawLeafBlock(node,
            parentX:
                currentX); // Use currentX (with margin, logic inside handles padding)
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

          await _drawNode(child,
              listType: nextListType,
              listIndex: childIndex,
              parentX: contentX); // Pass contentX as parentX for children
        }
      }
    } else {
      if (node.tagName == '#text') {
        // Should use parent contentX?
        // Inline nodes usually flow inside block.
        // _drawLeafBlock handles flow.
        // But if we call _drawLeafBlock for individual text, it assumes block-like behavior?
        // Wait, inline #text usually handled by parent block unless top level.
        // If parent called us, we are inside a block probably.
        // But if node is #text directly (child of block), we shouldn't create new block?
        // The parser groups text into blocks usually.
        // If we found #text here, it might be stray text?
        // Creating spans...

        await _drawLeafBlock(
            RenderNode(
                tagName: 'span',
                style: node.style,
                text: node.text,
                children: []),
            parentX: parentX); // Just pass parentX if inline
      } else {
        for (var child in node.children) {
          await _drawNode(child, parentX: parentX);
        }
      }
    }
  }

  Future<void> _drawLeafBlock(RenderNode node, {double parentX = 0}) async {
    // 1. Flatten children to Spans (with font fallback)
    List<LayoutSpan> spans = [];
    await _collectSpansWithFallback(node, spans);

    if (spans.isEmpty) {
      if (node.style.height == null && node.style.padding == null) return;
    }

    // 2. Perform Layout
    // Global X for block start
    double globalX = parentX;

    // Null safety access
    final padding = node.style.padding;
    final margin = node.style.margin;

    if (margin != null) globalX += margin.left;

    // Width calculation
    // Max width is Page Width - globalX - right margins
    double maxWidth = _pageWidth - globalX;

    if (margin != null) maxWidth -= margin.right;
    if (padding != null) maxWidth -= padding.right;

    // Remove padding left from maxWidth available for TEXT (since indent is added to text start)
    if (padding != null) maxWidth -= padding.left;

    LayoutResult layout =
        TextLayout.performLayout(spans: spans, maxWidth: maxWidth);

    // 3. Draw Background / Border
    double startY = _currentY;
    if (margin != null) startY += margin.top;

    double pageHeight = _currentPage.getClientSize().height;

    PdfPage currentPage = _currentPage;
    double currentY = startY;

    // ...

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
  /// Collect spans with character-level font fallback
  Future<void> _collectSpansWithFallback(
      RenderNode node, List<LayoutSpan> spans,
      {CSSStyle? parentStyle}) async {
    // Inherit styles from parent if available
    CSSStyle effectiveStyle = node.style;
    if (parentStyle != null) {
      effectiveStyle = node.style.inheritFrom(parentStyle);
    }

    // Handle br tag specifically
    if (node.tagName == 'br') {
      final baseFont = await _resolveFont(effectiveStyle);
      spans.add(LayoutSpan(text: '\n', style: effectiveStyle, font: baseFont));
      return;
    }

    if (node.text != null && node.text!.isNotEmpty) {
      final text = node.text!;
      final baseFont = await _resolveFont(effectiveStyle);
      final fontSize = effectiveStyle.fontSize ?? 12;

      // Handle checkbox specially if text is [ ] or [x] and tag is checkbox
      if (node.tagName == 'checkbox') {
        // We can use a specific font symbol if available, or just text.
        // For now, text is fine as parser sets it to [ ] or [x].
      }

      // Split text into segments by character type
      List<_TextSegment> segments = _segmentTextByCharType(text);

      for (var segment in segments) {
        PdfFont font;
        String spanText = segment.text;

        switch (segment.type) {
          case _CharType.arabic:
            font = _getFallbackFont(_notoArabicFontData, fontSize) ?? baseFont;
            try {
              if (spanText.trim().isNotEmpty) {
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
            font = _getFallbackFont(_notoEmojiFontData, fontSize) ??
                _getFallbackFont(_notoSansFontData, fontSize) ??
                baseFont;
            break;
          case _CharType.extended:
            font = _getFallbackFont(_notoSansFontData, fontSize) ?? baseFont;
            break;
          case _CharType.standard:
            font = baseFont;
        }

        PdfStringFormat? format;
        if (segment.type == _CharType.arabic ||
            effectiveStyle.textDirection == TextDirection.rtl) {
          format = PdfStringFormat(
            textDirection: PdfTextDirection.rightToLeft,
            alignment: PdfTextAlignment.right,
            lineAlignment: PdfVerticalAlignment.top,
          );
        }

        spans.add(LayoutSpan(
          text: spanText,
          style: effectiveStyle,
          font: font,
          format: format,
        ));
      }
    }

    for (var child in node.children) {
      await _collectSpansWithFallback(child, spans,
          parentStyle: effectiveStyle);
    }
  }

  Future<void> _drawTable(RenderNode node, {double parentX = 0}) async {
    // ... Simplified Table implementation using PdfGrid
    final grid = PdfGrid();

    // Define columns based on max cells in a row (simplified)
    // We need to parse structure properly.

    // Find rows
    List<RenderNode> rows = [];
    if (node.tagName == 'table') {
      for (var child in node.children) {
        if (child.tagName == 'thead' || child.tagName == 'tbody') {
          rows.addAll(child.children.where((c) => c.tagName == 'tr'));
        } else if (child.tagName == 'tr') {
          rows.add(child);
        }
      }
    }

    if (rows.isEmpty) return;

    // Determine columns
    int maxCols = 0;
    for (var row in rows) {
      int currentCols = 0;
      for (var cell in row.children) {
        if (cell.tagName == 'td' || cell.tagName == 'th') {
          int colspan = int.tryParse(cell.attributes['colspan'] ?? '1') ?? 1;
          currentCols += colspan;
        }
      }
      if (currentCols > maxCols) maxCols = currentCols;
    }

    grid.columns.add(count: maxCols);

    // Add rows and cells
    for (var rowNode in rows) {
      final pdfRow = grid.rows.add();
      int colIndex = 0;

      for (var cellNode in rowNode.children) {
        if (cellNode.tagName != 'td' && cellNode.tagName != 'th') continue;

        if (colIndex >= maxCols) break;

        final pdfCell = pdfRow.cells[colIndex];

        // Set colspan/rowspan
        int colspan = int.tryParse(cellNode.attributes['colspan'] ?? '1') ?? 1;
        int rowspan = int.tryParse(cellNode.attributes['rowspan'] ?? '1') ?? 1;

        if (colspan > 1) pdfCell.columnSpan = colspan;
        if (rowspan > 1) pdfCell.rowSpan = rowspan;

        // Content
        // Complex content in cell? PdfGridCell supports text or PdfGrid (nested).
        // For rich text, we might need a custom renderer inside the cell or just plain text if simple.
        // Syncfusion PdfGridCell has `value` which can be String or PdfGrid.
        // But we have formatted text.
        // We can set `pdfCell.value = PdfTextElement(...)`? No.
        // We can use `pdfCell.graphics`? No, PdfGrid handles drawing.
        // If we have complex content, we might have to use nested tables or text extraction.
        // For now, let's extract text but try to preserve basic styling (bg color).
        // A better approach for rich text in cells involves `PdfGridCell.style.cellPadding` and drawing manually using `BeginCellLayout` event, which is complex.
        // Given the constraints, we will convert cell content to plain text but respect cell styles.

        pdfCell.value = _extractText(cellNode);

        // Styles
        final bgColor =
            cellNode.style.backgroundColor ?? node.style.backgroundColor;
        if (bgColor != null) {
          pdfCell.style.backgroundBrush = PdfSolidBrush(_resolveColor(bgColor));
        }

        // Borders
        // Syncfusion PdfGrid handles borders via PdfBorders.
        // We can map CSS borders to PdfBorders.
        // Currently simplified to general grid style or cell style.
        final border = cellNode.style.border;
        if (border != null) {
          // Map border
          // pdfCell.style.borders = ...
        }

        // Padding
        // pdfCell.style.cellPadding = ...

        colIndex += colspan;
      }
    }

    // Apply table-wide border if present
    final tableBorder = node.style.border;
    if (tableBorder != null && tableBorder.top.width > 0) {
      grid.style.borderOverlapStyle = PdfBorderOverlapStyle.overlap;
      // grid.style.borders = ...
    }

    PdfPage? page = _lastResult?.page ?? document.pages[0];
    double y = _lastResult?.bounds.bottom ?? 0;

    // Incorporate parentX
    double x = parentX;
    if (node.style.margin != null) x += node.style.margin!.left;

    // Draw
    _lastResult = grid.draw(
        page: page,
        bounds: Rect.fromLTWH(x, y + (node.style.margin?.top ?? 0), 0, 0));
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

  Future<void> _drawCheckbox(RenderNode node, {double parentX = 0}) async {
    final page = _lastResult?.page ?? document.pages[0];
    double y = _lastResult?.bounds.bottom ?? 0;

    final margin = node.style.margin;
    if (margin != null) y += margin.top;

    double x = parentX;
    if (margin != null) x += margin.left;

    final width = node.style.width ?? 15.0; // Default size
    final height = node.style.height ?? 15.0;

    final isChecked = node.attributes['checked'] == 'true';
    final name = 'Checkbox_${DateTime.now().microsecondsSinceEpoch}';

    final checkbox = PdfCheckBoxField(
      page,
      name,
      Rect.fromLTWH(x, y, width, height),
      isChecked: isChecked,
      style: PdfCheckBoxStyle.cross,
      borderWidth: 1,
      borderColor: PdfColor(0, 0, 0),
    );

    document.form.fields.add(checkbox);

    var element = PdfTextElement(
      text: " ",
      font: PdfStandardFont(PdfFontFamily.helvetica, 1),
    );

    _lastResult = element.draw(
        page: page,
        bounds: Rect.fromLTWH(x, y + height + (margin?.bottom ?? 0), 0, 0));
  }

  Future<void> _drawImage(RenderNode node, {double parentX = 0}) async {
    final src = node.attributes['src'];
    if (src == null) return;

    Uint8List? imageBytes;

    try {
      if (src.startsWith('http')) {
        final response = await http.get(Uri.parse(src));
        if (response.statusCode == 200) {
          final contentType = response.headers['content-type'];
          if (contentType != null && contentType.startsWith('image/')) {
            imageBytes = response.bodyBytes;
          } else {
            debugPrint(
                'Skipping image with non-image content-type: $contentType for url: $src');
          }
        } else {
          debugPrint(
              'Failed to load image, status code: ${response.statusCode} for url: $src');
        }
      } else if (src.startsWith('assets/')) {
        final data = await rootBundle.load(src);
        imageBytes = data.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Error loading image source: $e');
    }

    final page = _lastResult?.page ?? document.pages[0];
    double y = _lastResult?.bounds.bottom ?? 0;

    final margin = node.style.margin;
    if (margin != null) y += margin.top;

    double x = parentX;
    if (margin != null) x += margin.left;

    if (imageBytes != null && imageBytes.isNotEmpty) {
      try {
        final bitmap = PdfBitmap(imageBytes);
        double width = node.style.width ?? bitmap.width.toDouble();
        double height = node.style.height ?? bitmap.height.toDouble();

        // Ensure it fits within page width
        // maxWidth = _pageWidth - x - (margin?.right ?? 0)

        // Draw Image
        page.graphics.drawImage(bitmap, Rect.fromLTWH(x, y, width, height));

        // Adance Y by height
        // To sync _lastResult, draw dummy
        var element = PdfTextElement(
          text: " ",
          font: PdfStandardFont(PdfFontFamily.helvetica, 1),
        );
        _lastResult = element.draw(
            page: page,
            bounds: Rect.fromLTWH(x, y + height + (margin?.bottom ?? 0), 0, 0));
      } catch (e) {
        debugPrint('Error creating/drawing PdfBitmap: $e');
        // Optionally draw a placeholder or error text
        page.graphics.drawString(
            "Image Error",
            PdfStandardFont(PdfFontFamily.helvetica, 8,
                style: PdfFontStyle.italic),
            brush: PdfBrushes.red,
            bounds: Rect.fromLTWH(x, y, 100, 15));

        // Advance cursor slightly so it's not overlapping
        var element = PdfTextElement(text: " ");
        _lastResult =
            element.draw(page: page, bounds: Rect.fromLTWH(x, y + 20, 0, 0));
      }
    } else {
      // Failed to load, maybe draw placeholder or nothing?
      // Just return for now to avoid crash
    }
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
