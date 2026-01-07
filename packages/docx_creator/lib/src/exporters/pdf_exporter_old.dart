import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../docx_creator.dart';

/// Exports [DocxBuiltDocument] to PDF format using a custom pure Dart implementation.
///
/// This exporter renders the document structure directly to PDF 1.4 objects,
/// leveraging the [DocxVisitor] pattern for content traversal.
class PdfExporter {
  /// Creates a PDF exporter.
  PdfExporter({
    this.fontName = 'Helvetica',
    this.fontSize = 12,
    this.pageWidth = 612.0, // Letter
    this.pageHeight = 792.0,
    this.marginTop = 72.0,
    this.marginBottom = 72.0,
    this.marginLeft = 72.0,
    this.marginRight = 72.0,
  });

  final String fontName;
  final int fontSize;

  // Default settings
  final double pageWidth;
  final double pageHeight;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;

  /// Exports the document to a file.
  Future<void> exportToFile(DocxBuiltDocument doc, String filePath) async {
    final bytes = exportToBytes(doc);
    await File(filePath).writeAsBytes(bytes);
  }

  /// Exports the document to bytes.
  Uint8List exportToBytes(DocxBuiltDocument doc) {
    // 1. Split content into logical sections
    final sections = _splitSections(doc);

    // 2. Initialize Writer (using default page size for writer init, but pages will define their own media box)
    final writer = _PdfDocumentWriter(
      width: pageWidth,
      height: pageHeight,
      fontName: fontName,
    );

    // 3. Process each section
    for (final sectionData in sections) {
      final sDef = sectionData.def;

      // Setup page params for this section
      final effectiveW = sDef.effectiveWidth / 20.0;
      final effectiveH = sDef.effectiveHeight / 20.0;
      final mt = sDef.marginTop / 20.0;
      final mb = sDef.marginBottom / 20.0;
      final ml = sDef.marginLeft / 20.0;
      final mr = sDef.marginRight / 20.0;

      final paginator = _PdfPaginator(
        width: effectiveW,
        height: effectiveH,
        marginTop: mt,
        marginBottom: mb,
        marginLeft: ml,
        marginRight: mr,
        baseFontSize: fontSize,
      );

      final pages = paginator.paginate(sectionData.nodes);

      for (final pageNodes in pages) {
        final renderer = _PdfPageRenderer(
          width: effectiveW,
          height: effectiveH,
          marginTop: mt,
          marginBottom: mb,
          marginLeft: ml,
          marginRight: mr,
          baseFontSize: fontSize,
        );

        // Render Header
        if (sDef.header != null) {
          // Temporarily adjust cursor to header area
          // Or use separate render area
          // Simple approach: Render header at top margin
          // We need a way to position header.
          renderer.renderHeader(sDef.header!);
        }

        // Render Footer
        if (sDef.footer != null) {
          renderer.renderFooter(sDef.footer!);
        }

        // Render Body
        for (final node in pageNodes) {
          if (node is DocxList) {
            renderer.renderList(node);
          } else {
            node.accept(renderer);
          }
        }

        writer.addPage(renderer.buffer.toString(), renderer.resources,
            width: effectiveW, height: effectiveH);
      }
    }

    // 4. Finalize
    return writer.save();
  }

  List<_SectionData> _splitSections(DocxBuiltDocument doc) {
    final result = <_SectionData>[];
    var currentNodes = <DocxNode>[];
    // Start with default or first section def
    // Actually DocxBuiltDocument usually has one main section?
    // Or explicit breaks define NEW sections.

    // default section
    var currentDef = doc.section ??
        DocxSectionDef(
          pageSize: DocxPageSize.letter,
          marginTop: (marginTop * 20).toInt(),
          marginBottom: (marginBottom * 20).toInt(),
          marginLeft: (marginLeft * 20).toInt(),
          marginRight: (marginRight * 20).toInt(),
        );

    for (final node in doc.elements) {
      if (node is DocxSectionBreakBlock) {
        // Represents end of previous section with SPECIFIC properties?
        // Actually DocxSectionBreakBlock usually defines properties of the PRECEDING section.
        // See docx_section_break.dart: "Inserting... defines properties of the PRECEDING section"

        // So, the nodes we collected belong to THIS break's definition.
        result.add(_SectionData(node.section, currentNodes));
        currentNodes = [];
        // What allows next section?
        // The next section takes properties from the *next* break or the final doc section.
        // If this break is continuous, maybe we don't paginate?
        // For PDF, easier to treat break as explicit page break usually.

        // Wait, if break defines PRECEDING, then valid logic is:
        // Collect nodes. When hit break, bundle nodes with break.section.
        // But what if multiple breaks?

        // If we pass a Break, we start collecting for next section.
        // What is the definition of the NEXT section?
        // It defaults to doc.section until another break or end.
        currentDef = doc.section ?? currentDef; // Reset to default?
      } else {
        currentNodes.add(node);
      }
    }

    if (currentNodes.isNotEmpty) {
      // Final section
      result.add(_SectionData(currentDef, currentNodes));
    }

    return result;
  }
}

class _SectionData {
  final DocxSectionDef def;
  final List<DocxNode> nodes;
  _SectionData(this.def, this.nodes);
}

/// Handles the low-level PDF object structure.
class _PdfDocumentWriter {
  final double width;
  final double height;
  final String fontName;

  final List<_PdfObject> _objects = [];

  _PdfDocumentWriter({
    required this.width,
    required this.height,
    required this.fontName,
  });

  void addPage(String contentStream, Map<String, _PdfResource> resources,
      {double? width, double? height}) {
    // 1. Create content object
    final contentObj = _createObject(
        '<< /Length ${contentStream.length} >>\nstream\n$contentStream\nendstream');

    // 2. Build Resource Dictionary
    final fontRes = StringBuffer('/Font <<\n');
    final xObjectRes = StringBuffer('/XObject <<\n');
    bool hasFonts = false;
    bool hasXObjects = false;

    // Always include standard fonts
    fontRes.writeln('/F1 ${_getFontObjId('Standard')} 0 R');
    fontRes.writeln('/F2 ${_getFontObjId('Bold')} 0 R');
    fontRes.writeln('/F3 ${_getFontObjId('Italic')} 0 R');
    fontRes.writeln('/F4 ${_getFontObjId('BoldItalic')} 0 R');
    fontRes.writeln('/F5 ${_getFontObjId('Mono')} 0 R');
    hasFonts = true;

    // Add other resources (Images)
    resources.forEach((name, res) {
      if (res.type == 'XObject') {
        final imgObj = _createObject(res.content);
        xObjectRes.writeln('$name ${imgObj.id} 0 R');
        hasXObjects = true;
      }
    });

    fontRes.write('>>');
    xObjectRes.write('>>');

    final resDict = StringBuffer('<<\n');
    if (hasFonts) resDict.writeln(fontRes.toString());
    if (hasXObjects) resDict.writeln(xObjectRes.toString());
    resDict.write('>>');

    // 3. Create Page Object
    final w = width ?? this.width;
    final h = height ?? this.height;

    final pageParams = '<<\n/Type /Page\n/Parent 2 0 R\n'
        '/MediaBox [0 0 $w $h]\n'
        '/Contents ${contentObj.id} 0 R\n'
        '/Resources ${resDict.toString()}\n>>';

    _createObject(pageParams, isPage: true);
  }

  Uint8List save() {
    return _finalize();
  }

  // --- Internal ---

  int _nextId = 9; // Start after fixed objects

  _PdfObject _createObject(String content, {bool isPage = false}) {
    final obj = _PdfObject(_nextId++, content, isPage: isPage);
    _objects.add(obj);
    return obj;
  }

  int _getFontObjId(String type) {
    switch (type) {
      case 'Standard':
        return 3;
      case 'Bold':
        return 4;
      case 'Italic':
        return 5;
      case 'BoldItalic':
        return 6;
      case 'Mono':
        return 7;
      default:
        return 3;
    }
  }

  Uint8List _finalize() {
    final buffer = BytesBuilder();
    int offset = 0;

    void write(String s) {
      final b = utf8.encode(s);
      buffer.add(b);
      offset += b.length;
    }

    // Header
    write('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');

    final offsets = <int, int>{}; // ID -> Offset

    void writeObj(int id, String content) {
      offsets[id] = offset;
      write('$id 0 obj\n$content\nendobj\n');
    }

    // 1. Catalog
    writeObj(1, '<< /Type /Catalog /Pages 2 0 R >>');

    // 2. Pages
    final pageIds =
        _objects.where((o) => o.isPage).map((o) => '${o.id} 0 R').join(' ');
    writeObj(2,
        '<< /Type /Pages /Kids [$pageIds] /Count ${_objects.where((o) => o.isPage).length} >>');

    // 3-7. Fonts
    writeObj(3, _buildFontDict(fontName));
    writeObj(4, _buildFontDict(_bold(fontName)));
    writeObj(5, _buildFontDict(_italic(fontName)));
    writeObj(6, _buildFontDict(_boldItalic(fontName)));
    writeObj(7, _buildFontDict('Courier'));

    // 8. Info
    writeObj(8,
        '<< /Creator (docx_creator) /Producer (Dart PdfExporter) /CreationDate (${_dateStr()}) >>');

    // 9+. Dynamic Objects (Pages, Contents, Images)
    for (final obj in _objects) {
      writeObj(obj.id, obj.content);
    }

    // XRef
    final startXref = offset;
    write('xref\n');
    write('0 ${offsets.length + 1}\n');
    write('0000000000 65535 f \n');

    for (int i = 1; i <= _objects.last.id; i++) {
      // Simple iteration up to max ID
      if (offsets.containsKey(i)) {
        write('${offsets[i]!.toString().padLeft(10, '0')} 00000 n \n');
      } else {
        write('0000000000 65535 f \n');
      }
    }

    // Trailer
    write(
        'trailer\n<< /Size ${_objects.last.id + 1} /Root 1 0 R /Info 8 0 R >>\n');
    write('startxref\n$startXref\n%%EOF\n');

    return buffer.toBytes();
  }

  String _buildFontDict(String name) {
    return '<< /Type /Font /Subtype /Type1 /BaseFont /$name /Encoding /WinAnsiEncoding >>';
  }

  String _bold(String f) => f == 'Times-Roman' ? 'Times-Bold' : '$f-Bold';
  String _italic(String f) =>
      f == 'Times-Roman' ? 'Times-Italic' : '$f-Oblique';
  String _boldItalic(String f) =>
      f == 'Times-Roman' ? 'Times-BoldItalic' : '$f-BoldOblique';

  String _dateStr() {
    final now = DateTime.now();
    return 'D:${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}000000';
  }
}

class _PdfObject {
  final int id;
  final String content;
  final bool isPage;
  _PdfObject(this.id, this.content, {this.isPage = false});
}

class _PdfResource {
  final String type;
  final String content;
  _PdfResource(this.type, this.content);
}

/// Visitor that generates drawing commands for a single page.
class _PdfPageRenderer implements DocxVisitor {
  final double width;
  final double height;
  final double marginTop;
  final double marginBottom;
  double marginLeft;
  double marginRight;
  final int baseFontSize;

  final StringBuffer buffer = StringBuffer();
  final Map<String, _PdfResource> resources = {};

  double cursorY;
  int imageCounter = 0;

  _PdfPageRenderer({
    required this.width,
    required this.height,
    required this.marginTop,
    required this.marginBottom,
    required this.marginLeft,
    required this.marginRight,
    required this.baseFontSize,
  }) : cursorY = height - marginTop;

  @override
  void visitParagraph(DocxBlock paragraph) {
    if (paragraph is! DocxParagraph) return;

    final fontSize = getFontSize(paragraph.styleId);
    final lineHeight = fontSize * 1.4;
    final indent = (paragraph.indentLeft ?? 0) / 20.0;

    // Build words list
    final words = <_Word>[];

    for (final child in paragraph.children) {
      if (child is DocxText) {
        final seg = createSegment(child, paragraph.styleId);
        final subWords = seg.text.split(' ');
        for (int i = 0; i < subWords.length; i++) {
          final w = subWords[i];
          if (w.isEmpty && i < subWords.length - 1) {
            // Treat space as a word with width?
            // Creating explicit space word makes justification easier?
            // For now, adhere to existing logic (spaces implicit or zero width word?)
            // Existing logic added logic in flow loop for spaceWidth.
          }
          if (w.isNotEmpty) {
            final width = w.length * fontSize * 0.5;
            words.add(_Word(w, seg.fontRef, seg.color, width));
          }
        }
      } else if (child is DocxTab) {
        // Add tab as a word with width
        words.add(_Word('', '', '', 36.0, isTab: true));
      } else if (child is DocxLineBreak) {
        words.add(_Word('', '', '', 0, isBreak: true));
      }
    }

    // Flow words into lines structure first
    final maxWidth = width - marginLeft - marginRight - indent;
    final lines = <List<_Word>>[];
    var currentLine = <_Word>[];
    var currentLineWidth = 0.0;
    final spaceWidth = fontSize * 0.25;

    for (final word in words) {
      if (word.isBreak) {
        // Force line break
        lines.add(currentLine);
        currentLine = [];
        currentLineWidth = 0;
        continue;
      }

      if (currentLineWidth + word.width + spaceWidth > maxWidth &&
          currentLine.isNotEmpty) {
        lines.add(currentLine);
        currentLine = [word];
        currentLineWidth = word.width;
      } else {
        if (currentLine.isNotEmpty) currentLineWidth += spaceWidth;
        currentLine.add(word);
        currentLineWidth += word.width;
      }
    }
    if (currentLine.isNotEmpty) lines.add(currentLine);

    // Measure total height
    final effectiveLines = lines.isEmpty ? 1 : lines.length;
    final totalHeight = effectiveLines * lineHeight;

    // Draw Background
    if (paragraph.shadingFill != null && paragraph.shadingFill != 'auto') {
      final bgRgb = hexToRgb(paragraph.shadingFill!);
      final bgX = marginLeft + indent;
      final bgW = maxWidth;
      buffer.writeln(
          'q $bgRgb rg $bgX ${cursorY - totalHeight} $bgW $totalHeight re f Q');
    }

    // Render Lines
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Handle empty lines (from breaks)
      if (line.isEmpty) {
        cursorY -= lineHeight;
        continue;
      }

      final isLast = i == lines.length - 1;

      // Calc line width for alignment
      double lineWidth = 0;
      for (var j = 0; j < line.length; j++) {
        lineWidth += line[j].width;
        if (j < line.length - 1) lineWidth += spaceWidth;
      }

      double x = marginLeft + indent;
      double wordSpacing = 0;

      if (paragraph.align == DocxAlign.center) {
        x += (maxWidth - lineWidth) / 2;
      } else if (paragraph.align == DocxAlign.right) {
        x += (maxWidth - lineWidth);
      } else if (paragraph.align == DocxAlign.justify && !isLast) {
        final spaceCount = line.length - 1;
        if (spaceCount > 0) {
          final slack = maxWidth - lineWidth;
          if (slack > 0) wordSpacing = slack / spaceCount;
        }
      }
      if (wordSpacing > 10) wordSpacing = 0;

      buffer.writeln('BT 1 0 0 1 $x $cursorY Tm');
      if (wordSpacing > 0) {
        buffer.writeln('${wordSpacing.toStringAsFixed(3)} Tw');
      }

      for (int k = 0; k < line.length; k++) {
        final word = line[k];

        if (word.isTab) {
          // Move cursor
          // Reset Tw to 0 for tab move? No, Td is independent of Tw.
          buffer.writeln('${word.width} 0 Td');
        } else {
          buffer.writeln('${word.fontRef} $fontSize Tf');
          buffer.writeln('${word.color} rg');
          buffer.writeln('(${escape(word.text)}) Tj');
        }

        if (k < line.length - 1) {
          // Space
          // If next word is Tab, do we need space?
          // Logic above: `lineWidth += spaceWidth`.
          // So we expect a space.
          buffer.writeln('( ) Tj');
        }
      }
      if (wordSpacing > 0) buffer.writeln('0 Tw');
      buffer.writeln('ET');

      cursorY -= lineHeight;
    }

    if (lines.isEmpty) cursorY -= lineHeight; // Handle empty paragraph height
    cursorY -= fontSize * 0.5;
  }

  @override
  void visitTable(DocxBlock table) {
    if (table is! DocxTable) return;
    if (table.rows.isEmpty) return;

    final cols = table.rows.first.cells.length;
    final colWidth = (width - marginLeft - marginRight) / cols;

    for (final row in table.rows) {
      double maxRowH = 0;

      // 1. Measure Height
      for (final cell in row.cells) {
        final h = measureCellHeight(cell, colWidth - 4);
        if (h > maxRowH) maxRowH = h;
      }
      if (maxRowH < 20) maxRowH = 20;

      final rowY = cursorY;

      // 2. Draw Backgrounds (before content!)
      for (int i = 0; i < row.cells.length; i++) {
        final cell = row.cells[i];
        if (cell.shadingFill != null && cell.shadingFill != 'auto') {
          final bgX = marginLeft + (i * colWidth);
          final bgRgb = hexToRgb(cell.shadingFill!);
          buffer.writeln(
              'q $bgRgb rg $bgX ${rowY - maxRowH} $colWidth $maxRowH re f Q');
        }
      }

      // 3. Draw Borders
      for (int i = 0; i < row.cells.length; i++) {
        final x = marginLeft + (i * colWidth);
        buffer
            .writeln('q 0.5 w $x ${rowY - maxRowH} $colWidth $maxRowH re S Q');
      }

      // 4. Render Content
      for (int i = 0; i < row.cells.length; i++) {
        final cell = row.cells[i];
        final x = marginLeft + (i * colWidth);

        double currentCellY = rowY - baseFontSize - 4;
        for (final block in cell.children) {
          final h = renderCellBlock(block, x + 2, currentCellY, colWidth - 4);
          currentCellY -= h;
        }
      }

      cursorY -= maxRowH;
    }
    cursorY -= 10;
  }

  // Helper to render any block inside a cell
  double renderCellBlock(DocxNode block, double x, double y, double w) {
    if (block is DocxParagraph) {
      renderCellText(block, x, y, w);
      return measureParagraphHeight(block, w);
    } else if (block is DocxTable) {
      // Nested Table
      final savedMarginLeft = marginLeft;
      final savedMarginRight = marginRight;
      final savedCursorY = cursorY;
      // We assume 'width' is constant (page width).

      // Constrain rendering to cell area
      marginLeft = x;
      marginRight = width - x - w;

      // Tricky: visitTable uses _cursorY to start.
      // It expects _cursorY to be where the table starts.
      cursorY = y;

      visitTable(block);

      final usedHeight = y - cursorY;

      // Restore
      marginLeft = savedMarginLeft;
      marginRight = savedMarginRight;
      cursorY = savedCursorY;

      return usedHeight;
    } else if (block is DocxList) {
      // Render list items manually for now or try to use renderList
      // renderList uses global margins too...
      final savedMarginLeft = marginLeft;
      final savedCursorY = cursorY;

      marginLeft = x; // Adjust margin for bullets
      cursorY = y;

      renderList(block); // This will mess up _cursorY

      final usedHeight = y - cursorY;

      marginLeft = savedMarginLeft;
      cursorY = savedCursorY;

      return usedHeight;
    }
    return 0;
  }

  void renderHeader(DocxNode header) {
    // Header area: Top margin
    // Save state
    final savedCursorY = cursorY;
    final savedMarginLeft = marginLeft;

    // Position for header
    // Usually 0.5 inch from top edge.
    // Top edge is `height`.
    cursorY = height - 36; // 0.5 inch

    // Header content usually has specific styles, but we render normally
    if (header is DocxBlock) {
      // Headers are usually blocks (paragraphs/tables)
      if (header is DocxParagraph) {
        visitParagraph(header);
      } else if (header is DocxTable) {
        visitTable(header);
      }
    }

    // Restore
    cursorY = savedCursorY;
    marginLeft = savedMarginLeft;
  }

  void renderFooter(DocxNode footer) {
    final savedCursorY = cursorY;
    final savedMarginLeft = marginLeft;

    // Position for footer
    // Usually 0.5 inch from bottom edge.
    cursorY = 36 + 20; // 0.5 inch + approx height?
    // We render DOWN from cursorY.

    if (footer is DocxBlock) {
      if (footer is DocxParagraph) {
        visitParagraph(footer);
      } else if (footer is DocxTable) {
        visitTable(footer);
      }
    }

    cursorY = savedCursorY;
    marginLeft = savedMarginLeft;
  }

  @override
  void visitHeader(DocxNode header) {
    // Visitor pattern entry point, but we call renderHeader explicitly from exporter
    renderHeader(header);
  }

  @override
  void visitFooter(DocxNode footer) {
    renderFooter(footer);
  }

  @override
  void visitRawXml(DocxNode rawXml) {}

  @override
  void visitRawInline(DocxNode rawInline) {}

  @override
  void visitShape(DocxInline shape) {}

  @override
  void visitShapeBlock(DocxBlock shapeBlock) {}

  @override
  void visitTableOfContents(DocxBlock toc) {}

  // Also need to implement other missing visitor methods if any
  @override
  void visitText(DocxInline text) {} // Handled by visitParagraph

  @override
  void visitTableRow(DocxNode row) {} // Handled by visitTable

  @override
  void visitTableCell(DocxNode cell) {} // Handled by visitTable

  @override
  void visitSection(DocxNode section) {} // Handled by splitSections

  @override
  void visitImage(DocxNode image) {
    Uint8List? bytes;
    double w = 100, h = 100;

    if (image is DocxImage) {
      bytes = image.bytes;
      w = image.width;
      h = image.height;
    } else if (image is DocxInlineImage) {
      bytes = image.bytes;
      w = image.width;
      h = image.height;
    }

    if (bytes != null) {
      final resName = '/Im${++imageCounter}';
      final hex =
          bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

      resources[resName] = _PdfResource('XObject',
          '<< /Type /XObject /Subtype /Image /Width 200 /Height 200 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /ASCIIHexDecode >> stream\n$hex>\nendstream');

      cursorY -= h;
      final x = marginLeft;
      buffer.writeln('q $w 0 0 $h $x $cursorY cm $resName Do Q');
    }
  }

  void renderList(DocxList list) {
    int index = list.startIndex;
    for (final item in list.items) {
      final levelIndent = (item.level * 36.0);
      final markerX = marginLeft + levelIndent + 20;
      final contentX = markerX + 24;

      String marker = list.isOrdered ? '${index++}.' : '\\225';

      // Marker
      buffer.writeln(
          'BT 1 0 0 1 $markerX $cursorY Tm /F1 $baseFontSize Tf 0 0 0 rg ($marker) Tj ET');

      // Content
      for (final child in item.children) {
        if (child is DocxText) {
          buffer.writeln(
              'BT 1 0 0 1 $contentX $cursorY Tm /F1 $baseFontSize Tf 0 0 0 rg (${escape(child.content)}) Tj ET');
        }
      }
      cursorY -= (baseFontSize * 1.5);
    }
    cursorY -= 10;
  }

  // --- Helpers ---

  void renderCellText(DocxParagraph p, double x, double y, double w) {
    final segments = <_TextSegment>[];
    for (var c in p.children) {
      if (c is DocxText) segments.add(createSegment(c, p.styleId));
    }

    buffer.writeln('BT 1 0 0 1 $x $y Tm');
    for (var s in segments) {
      buffer.writeln(
          '${s.fontRef} $baseFontSize Tf ${s.color} rg (${escape(s.text)}) Tj');
    }
    buffer.writeln('ET');
  }

  double getFontSize(String? style) => (style?.startsWith('Heading') ?? false)
      ? baseFontSize * 1.5
      : baseFontSize.toDouble();

  _TextSegment createSegment(DocxText t, String? style) {
    String ref = '/F1';
    if (t.isBold) ref = '/F2';
    if (t.isItalic) ref = '/F3';
    if (style != null && style.startsWith('Heading')) ref = '/F2';

    final c =
        t.effectiveColorHex != null ? hexToRgb(t.effectiveColorHex!) : '0 0 0';
    return _TextSegment(t.content, ref, c);
  }

  String hexToRgb(String hex) {
    if (hex.length != 6) return '0 0 0';
    final r = int.parse(hex.substring(0, 2), radix: 16) / 255;
    final g = int.parse(hex.substring(2, 4), radix: 16) / 255;
    final b = int.parse(hex.substring(4, 6), radix: 16) / 255;
    return '${r.toStringAsFixed(2)} ${g.toStringAsFixed(2)} ${b.toStringAsFixed(2)}';
  }

  String escape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('(', '\\(')
      .replaceAll(')', '\\)')
      .replaceAll('•', '\\225')
      .replaceAll('—', '\\227') // em dash
      .replaceAll('–', '\\226') // en dash
      .replaceAll('“', '\\223')
      .replaceAll('”', '\\224')
      .replaceAll('‘', '\\221')
      .replaceAll('’', '\\222');

  // Helpers for measuring
  double measureParagraphHeight(DocxParagraph p, double width) {
    if (p.children.isEmpty) return baseFontSize.toDouble();

    final segments = <_TextSegment>[];
    for (final child in p.children) {
      if (child is DocxText) {
        segments.add(createSegment(child, p.styleId));
      }
    }

    final words = <_Word>[];
    for (final seg in segments) {
      final subWords = seg.text.split(' ');
      for (final w in subWords) {
        if (w.isNotEmpty) {
          words.add(
              _Word(w, seg.fontRef, seg.color, w.length * baseFontSize * 0.5));
        }
      }
    }

    if (words.isEmpty) return baseFontSize.toDouble();

    double currentW = 0;
    int lines = 1;
    final spaceW = baseFontSize * 0.25;

    for (var w in words) {
      if (currentW + w.width + spaceW > width) {
        lines++;
        currentW = w.width;
      } else {
        currentW += w.width + spaceW;
      }
    }
    return lines * (baseFontSize * 1.4);
  }

  double measureTableHeight(DocxTable table, double width) {
    if (table.rows.isEmpty) return 0;
    final cols = table.rows.first.cells.length;
    final colW = width / cols;

    double totalH = 0;
    for (final row in table.rows) {
      double maxH = 0;
      for (final cell in row.cells) {
        final h = measureCellHeight(cell, colW - 4);
        if (h > maxH) maxH = h;
      }
      if (maxH < 20) maxH = 20;
      totalH += maxH;
    }
    return totalH;
  }

  double measureCellHeight(DocxTableCell cell, double w) {
    double h = 0;
    for (var b in cell.children) {
      if (b is DocxParagraph) {
        h += measureParagraphHeight(b, w);
      } else if (b is DocxTable) {
        h += measureTableHeight(b, w);
      } else if (b is DocxList) {
        h += b.items.length * baseFontSize * 1.5;
      }
      // Add padding/spacing between blocks?
    }
    return h + 10;
  }
}

class _TextSegment {
  final String text;
  final String fontRef;
  final String color;
  _TextSegment(this.text, this.fontRef, this.color);
}

class _Word {
  final String text;
  final String fontRef;
  final String color;
  final double width;
  final bool isTab;
  final bool isBreak;

  _Word(this.text, this.fontRef, this.color, this.width,
      {this.isTab = false, this.isBreak = false});
}

class _PdfPaginator {
  final double width;
  final double height;
  final double marginTop, marginBottom, marginLeft, marginRight;
  final int baseFontSize;

  _PdfPaginator(
      {required this.width,
      required this.height,
      required this.marginTop,
      required this.marginBottom,
      required this.marginLeft,
      required this.marginRight,
      required this.baseFontSize});

  List<List<DocxNode>> paginate(List<DocxNode> nodes) {
    final pages = <List<DocxNode>>[];
    var current = <DocxNode>[];
    double y = height - marginTop - marginBottom;

    for (var node in nodes) {
      // Force page break for section breaks
      if (node is DocxSectionBreakBlock) {
        current.add(node);
        pages.add(current);
        current = [];
        y = height - marginTop - marginBottom;
        continue;
      }

      double h = 20;
      if (node is DocxTable) h = (node.rows.length * 30.0) + 10;
      if (node is DocxParagraph) h = 30; // approx
      if (node is DocxImage) h = node.height + 10;
      if (node is DocxList) h = node.items.length * 20.0 + 10;

      if (y - h < 0) {
        pages.add(current);
        current = [];
        y = height - marginTop - marginBottom;
      }
      current.add(node);
      y -= h;
    }
    if (current.isNotEmpty) pages.add(current);
    if (pages.isEmpty) pages.add([]);
    return pages;
  }
}
