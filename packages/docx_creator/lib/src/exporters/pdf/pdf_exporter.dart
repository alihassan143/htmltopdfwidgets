import 'dart:io';
import 'dart:typed_data';

import '../../../docx_creator.dart';
import 'pdf_content_builder.dart';
import 'pdf_document_writer.dart';
import 'pdf_font_manager.dart';
import 'pdf_layout_engine.dart';

/// Exports [DocxBuiltDocument] to PDF format.
///
/// Uses a modular architecture with separate components for:
/// - Layout and measurement ([PdfLayoutEngine])
/// - Content stream building ([PdfContentBuilder])
/// - Low-level PDF structure ([PdfDocumentWriter])
class PdfExporter {
  /// Default page width (Letter: 8.5 inches = 612 points)
  final double pageWidth;

  /// Default page height (Letter: 11 inches = 792 points)
  final double pageHeight;

  /// Default margins (1 inch = 72 points)
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;

  final int fontSize;

  // State for current export
  PdfDocumentWriter? _writer;
  final _pageImages = <String, int>{};
  var _imageCount = 0;

  /// Creates a PDF exporter with configurable defaults.
  PdfExporter({
    this.pageWidth = 612.0,
    this.pageHeight = 792.0,
    this.marginTop = 72.0,
    this.marginBottom = 72.0,
    this.marginLeft = 72.0,
    this.marginRight = 72.0,
    this.fontSize = 12,
  });

  /// Exports the document to a file.
  Future<void> exportToFile(DocxBuiltDocument doc, String filePath) async {
    final bytes = exportToBytes(doc);
    await File(filePath).writeAsBytes(bytes);
  }

  /// Exports the document to bytes.
  Uint8List exportToBytes(DocxBuiltDocument doc) {
    _writer = PdfDocumentWriter();
    final sections = _splitSections(doc);

    for (final section in sections) {
      _processSection(section);
    }

    return _writer!.save();
  }

  void _processSection(_SectionData section) {
    final layout = PdfLayoutEngine(
      pageWidth: section.width,
      pageHeight: section.height,
      marginTop: section.marginTop,
      marginBottom: section.marginBottom,
      marginLeft: section.marginLeft,
      marginRight: section.marginRight,
      baseFontSize: fontSize.toDouble(),
    );

    final pages = layout.paginate(section.nodes);

    for (final pageNodes in pages) {
      final content = _renderPage(
        pageNodes,
        layout,
        header: section.header,
        footer: section.footer,
      );

      _writer!.addPage(
        contentStream: content,
        width: section.width,
        height: section.height,
        xObjectIds: Map.from(_pageImages),
      );

      _pageImages.clear();
      _imageCount = 0;
    }
  }

  String _renderPage(
    List<DocxNode> nodes,
    PdfLayoutEngine layout, {
    DocxNode? header,
    DocxNode? footer,
  }) {
    final builder = PdfContentBuilder();
    var cursorY = layout.contentTop;

    // Render header
    if (header != null) {
      _renderNode(
          header, builder, layout.marginLeft, layout.pageHeight - 36, layout);
    }

    // Render footer
    if (footer != null) {
      _renderNode(footer, builder, layout.marginLeft, 36, layout);
    }

    // Render body content
    for (final node in nodes) {
      cursorY = _renderNode(node, builder, layout.marginLeft, cursorY, layout);
    }

    return builder.content;
  }

  double _renderNode(
    DocxNode node,
    PdfContentBuilder builder,
    double x,
    double y,
    PdfLayoutEngine layout,
  ) {
    if (node is DocxParagraph) {
      return _renderParagraph(node, builder, x, y, layout);
    } else if (node is DocxTable) {
      return _renderTable(node, builder, x, y, layout);
    } else if (node is DocxList) {
      return _renderList(node, builder, x, y, layout);
    } else if (node is DocxImage) {
      return _renderImage(node, builder, x, y, layout);
    }
    return y;
  }

  double _renderParagraph(
    DocxParagraph paragraph,
    PdfContentBuilder builder,
    double startX,
    double startY,
    PdfLayoutEngine layout,
  ) {
    final fontSize = layout.getFontSize(paragraph.styleId);
    final lineHeight = fontSize * 1.4;
    final indent = (paragraph.indentLeft ?? 0) / 20.0;
    final maxWidth = layout.contentWidth - indent;

    // Collect words with their formatting
    final words = <_Word>[];
    for (final child in paragraph.children) {
      if (child is DocxText) {
        // Apply bold for headings or if text is explicitly bold
        final isHeading = paragraph.styleId?.startsWith('Heading') ?? false;
        final fontRef = PdfFontManager().selectFont(
          isBold: child.isBold || isHeading,
          isItalic: child.isItalic,
        );
        final color = child.effectiveColorHex ?? '000000';

        for (final word in child.content.split(' ')) {
          if (word.isNotEmpty) {
            final width = builder.measureText(word, fontSize);
            words.add(_Word(word, fontRef, color, width));
          }
        }
      } else if (child is DocxLineBreak) {
        words.add(_Word.lineBreak());
      } else if (child is DocxTab) {
        words.add(_Word.tab(fontSize * 3));
      }
    }

    // Flow words into lines
    final spaceWidth = fontSize * 0.25;
    final lines = _flowWords(words, maxWidth, spaceWidth);

    // Calculate total height for background
    final totalHeight = lines.isEmpty ? lineHeight : lines.length * lineHeight;

    // In PDF, Y increases upward. Text baseline is at Y position.
    // We need to:
    // 1. Draw background from (startY - lineHeight + some padding) downward
    // 2. Position first text baseline at (startY - fontSize) so it's inside the box

    // Draw background first - positioned to contain all text lines
    final bgBottom = startY - totalHeight;

    if (paragraph.shadingFill != null && paragraph.shadingFill != 'auto') {
      builder.saveState();
      builder.setFillColorHex(paragraph.shadingFill!);
      builder.fillRect(startX + indent, bgBottom, maxWidth, totalHeight);
      builder.restoreState();
    }

    // Render lines - position text baseline so text appears inside background
    // First line baseline should be inside the first line's vertical space
    var y = startY -
        fontSize *
            0.3; // Offset down slightly so text is inside the line height

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) {
        y -= lineHeight;
        continue;
      }

      // Calculate alignment
      var lineWidth = 0.0;
      for (var j = 0; j < line.length; j++) {
        lineWidth += line[j].width;
        if (j < line.length - 1) lineWidth += spaceWidth;
      }

      var x = startX + indent;
      var wordSpacing = 0.0;

      if (paragraph.align == DocxAlign.center) {
        x += (maxWidth - lineWidth) / 2;
      } else if (paragraph.align == DocxAlign.right) {
        x += maxWidth - lineWidth;
      } else if (paragraph.align == DocxAlign.justify && i < lines.length - 1) {
        final spaceCount = line.length - 1;
        if (spaceCount > 0) {
          final slack = maxWidth - lineWidth;
          if (slack > 0 && slack < fontSize * 2) {
            wordSpacing = slack / spaceCount;
          }
        }
      }

      // Draw text
      builder.beginText();
      builder.setTextMatrix(x, y);
      if (wordSpacing > 0) builder.setWordSpacing(wordSpacing);

      for (var k = 0; k < line.length; k++) {
        final word = line[k];

        if (word.isTab) {
          builder.moveText(word.width, 0);
        } else {
          builder.setFont(word.fontRef, fontSize);
          builder.setFillColorHex(word.color);
          builder.showText(word.text);

          if (k < line.length - 1) {
            builder.showText(' ');
          }
        }
      }

      if (wordSpacing > 0) builder.setWordSpacing(0);
      builder.endText();

      y -= lineHeight;
    }

    if (lines.isEmpty) y = startY - lineHeight;

    // Add extra spacing after paragraphs (especially headings)
    final isHeading = paragraph.styleId?.startsWith('Heading') ?? false;
    final spacing = isHeading ? fontSize * 0.8 : fontSize * 0.5;
    return y - spacing;
  }

  List<List<_Word>> _flowWords(
      List<_Word> words, double maxWidth, double spaceWidth) {
    final lines = <List<_Word>>[];
    var currentLine = <_Word>[];
    var currentWidth = 0.0;

    for (final word in words) {
      if (word.isBreak) {
        lines.add(currentLine);
        currentLine = [];
        currentWidth = 0;
        continue;
      }

      if (currentWidth + word.width + spaceWidth > maxWidth &&
          currentLine.isNotEmpty) {
        lines.add(currentLine);
        currentLine = [word];
        currentWidth = word.width;
      } else {
        if (currentLine.isNotEmpty) currentWidth += spaceWidth;
        currentLine.add(word);
        currentWidth += word.width;
      }
    }

    if (currentLine.isNotEmpty) lines.add(currentLine);
    if (lines.isEmpty) lines.add([]);
    return lines;
  }

  double _renderTable(
    DocxTable table,
    PdfContentBuilder builder,
    double startX,
    double startY,
    PdfLayoutEngine layout,
  ) {
    if (table.rows.isEmpty) return startY;

    final cols = table.rows.first.cells.length;
    final colWidth = layout.contentWidth / cols;
    var y = startY;

    for (final row in table.rows) {
      // Measure row height
      var maxRowHeight = 20.0;
      for (final cell in row.cells) {
        final h = layout.measureCell(cell, colWidth - 4);
        if (h > maxRowHeight) maxRowHeight = h;
      }

      // Draw cell backgrounds
      for (var i = 0; i < row.cells.length; i++) {
        final cell = row.cells[i];
        final cellX = startX + i * colWidth;

        if (cell.shadingFill != null && cell.shadingFill != 'auto') {
          builder.saveState();
          builder.setFillColorHex(cell.shadingFill!);
          builder.fillRect(cellX, y - maxRowHeight, colWidth, maxRowHeight);
          builder.restoreState();
        }
      }

      // Draw borders
      builder.saveState();
      builder.setStrokeColor(0, 0, 0);
      for (var i = 0; i < row.cells.length; i++) {
        final cellX = startX + i * colWidth;
        builder.strokeRect(cellX, y - maxRowHeight, colWidth, maxRowHeight);
      }
      builder.restoreState();

      // Render cell content
      for (var i = 0; i < row.cells.length; i++) {
        final cell = row.cells[i];
        final cellX = startX + i * colWidth + 2;
        var cellY = y - fontSize - 4;

        for (final block in cell.children) {
          if (block is DocxParagraph) {
            _renderCellParagraph(
                block, builder, cellX, cellY, colWidth - 4, layout);
            cellY -= layout.measureParagraphInWidth(block, colWidth - 4);
          }
        }
      }

      y -= maxRowHeight;
    }

    return y - 10;
  }

  double _renderCellParagraph(
    DocxParagraph paragraph,
    PdfContentBuilder builder,
    double x,
    double y,
    double width,
    PdfLayoutEngine layout,
  ) {
    // 1. Collect all words from the paragraph
    final words = <_Word>[];
    for (final child in paragraph.children) {
      if (child is DocxText) {
        final text = child.content;
        final fontRef = PdfFontManager().selectFont(
          isBold: child.isBold,
          isItalic: child.isItalic,
        );
        final color = child.effectiveColorHex ?? '000000';

        // Split text into words for wrapping
        // Note: This is a simplified split; robust splitting would handle more whitespace cases
        final parts = text.split(' ');
        for (var i = 0; i < parts.length; i++) {
          final part = parts[i];
          if (part.isEmpty && i < parts.length - 1) {
            continue; // Skip empty parts from split, unless it's significant (simplification)
          }

          // Approximate width calculation
          // Ideally we would use PdfFontManager.measureText if available, or approximate
          final w = part.length * (fontSize * PdfFontManager.avgCharWidth);
          words.add(_Word(part, fontRef, color, w));
        }
      }
    }

    if (words.isEmpty) {
      return fontSize * 1.4; // Return default line height if empty
    }

    // 2. Flow words into lines based on cell width
    final spaceWidth = fontSize * 0.25;
    final lines = _flowWords(words, width, spaceWidth);
    final lineHeight = fontSize * 1.4;

    // 3. Render each line
    var currentY = y;
    for (final line in lines) {
      if (line.isEmpty) {
        currentY -= lineHeight;
        continue;
      }

      builder.beginText();
      builder.setTextMatrix(x, currentY);

      for (var k = 0; k < line.length; k++) {
        final word = line[k];
        builder.setFont(word.fontRef, fontSize.toDouble());
        builder.setFillColorHex(word.color);
        builder.showText(word.text);

        if (k < line.length - 1) {
          builder.showText(' ');
        }
      }
      builder.endText();
      currentY -= lineHeight;
    }

    // Return total height used
    return lines.length * lineHeight;
  }

  double _renderList(
    DocxList list,
    PdfContentBuilder builder,
    double startX,
    double startY,
    PdfLayoutEngine layout,
  ) {
    var y = startY;
    var index = list.startIndex;
    final lineHeight = fontSize * 1.5;
    final bulletIndent = 36.0;
    final textIndent = 24.0;

    for (final item in list.items) {
      final levelIndent = item.level * bulletIndent;
      final markerX = startX + levelIndent;
      final contentX = markerX + textIndent;
      final availableWidth =
          layout.contentWidth - (contentX - layout.marginLeft);

      // Draw bullet/number marker
      final marker = list.isOrdered ? '${index++}.' : '\x95';
      builder.beginText();
      builder.setTextMatrix(markerX, y);
      builder.setFont(PdfFontManager.fontRegular, fontSize.toDouble());
      builder.setFillColorHex('000000');
      builder.showText(marker);
      builder.endText();

      // Collect all words
      final words = <_Word>[];
      for (final child in item.children) {
        if (child is DocxText) {
          final text = child.content;
          final fontRef = PdfFontManager().selectFont(
            isBold: child.isBold,
            isItalic: child.isItalic,
          );
          final color = child.effectiveColorHex ?? '000000';

          final parts = text.split(' ');
          for (var i = 0; i < parts.length; i++) {
            final part = parts[i];
            if (part.isEmpty && i < parts.length - 1) continue;
            // Approx width
            final w = part.length * (fontSize * PdfFontManager.avgCharWidth);
            words.add(_Word(part, fontRef, color, w));
          }
        }
      }

      if (words.isNotEmpty) {
        final spaceWidth = fontSize * 0.25;
        final lines = _flowWords(words, availableWidth, spaceWidth);

        var currentY = y;
        for (final line in lines) {
          if (line.isEmpty) {
            currentY -= lineHeight;
            continue;
          }

          builder.beginText();
          builder.setTextMatrix(contentX, currentY);

          for (var k = 0; k < line.length; k++) {
            final word = line[k];
            builder.setFont(word.fontRef, fontSize.toDouble());
            builder.setFillColorHex(word.color);
            builder.showText(word.text);

            if (k < line.length - 1) {
              builder.showText(' ');
            }
          }
          builder.endText();
          currentY -= lineHeight;
        }
        y = currentY;
      } else {
        y -= lineHeight;
      }

      y -= fontSize * 0.2;
    }

    return y - 10;
  }

  double _renderImage(
    DocxImage image,
    PdfContentBuilder builder,
    double x,
    double y,
    PdfLayoutEngine layout,
  ) {
    final writer = _writer;
    final bytes = image.bytes;
    if (writer == null) return y;

    // Register image with writer
    final imageId = writer.addImage(
      bytes: bytes,
      width: image.width.toInt(),
      height: image.height.toInt(),
    );

    final imageName = '/Im${++_imageCount}';
    _pageImages[imageName] = imageId;

    final renderHeight = image.height;
    final renderWidth = image.width; // Or scale if needed

    // Draw image
    // Note: PDF coordinates are bottom-up, so y is bottom-left of image
    // But our y is top-down flow. We want top-left of image at y.
    // So draw at y - height
    builder.drawImage(
        imageName, x, y - renderHeight, renderWidth, renderHeight);

    return y - renderHeight - 10;
  }

  List<_SectionData> _splitSections(DocxBuiltDocument doc) {
    final result = <_SectionData>[];
    var currentNodes = <DocxNode>[];

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
        result.add(_SectionData.fromDef(node.section, currentNodes));
        currentNodes = [];
        currentDef = doc.section ?? currentDef;
      } else {
        currentNodes.add(node);
      }
    }

    if (currentNodes.isNotEmpty) {
      result.add(_SectionData.fromDef(currentDef, currentNodes));
    }

    if (result.isEmpty) {
      result.add(_SectionData.fromDef(currentDef, []));
    }

    return result;
  }
}

class _SectionData {
  final double width;
  final double height;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final List<DocxNode> nodes;
  final DocxNode? header;
  final DocxNode? footer;

  _SectionData({
    required this.width,
    required this.height,
    required this.marginTop,
    required this.marginBottom,
    required this.marginLeft,
    required this.marginRight,
    required this.nodes,
    this.header,
    this.footer,
  });

  factory _SectionData.fromDef(DocxSectionDef def, List<DocxNode> nodes) {
    return _SectionData(
      width: def.effectiveWidth / 20.0,
      height: def.effectiveHeight / 20.0,
      marginTop: def.marginTop / 20.0,
      marginBottom: def.marginBottom / 20.0,
      marginLeft: def.marginLeft / 20.0,
      marginRight: def.marginRight / 20.0,
      nodes: nodes,
      header: def.header,
      footer: def.footer,
    );
  }
}

class _Word {
  final String text;
  final String fontRef;
  final String color;
  final double width;
  final bool isTab;
  final bool isBreak;

  _Word(this.text, this.fontRef, this.color, this.width)
      : isTab = false,
        isBreak = false;

  _Word.tab(this.width)
      : text = '',
        fontRef = '',
        color = '',
        isTab = true,
        isBreak = false;

  _Word.lineBreak()
      : text = '',
        fontRef = '',
        color = '',
        width = 0,
        isTab = false,
        isBreak = true;
}
