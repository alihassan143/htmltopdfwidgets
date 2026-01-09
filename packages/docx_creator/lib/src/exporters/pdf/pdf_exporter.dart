import 'dart:io';
import 'dart:math' show pi, cos, sin;
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

  /// Whether to compress content streams (reduces file size but makes text unreadable in raw bytes)
  final bool compressContent;

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
    this.compressContent = true,
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
        compress: compressContent,
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
    } else if (node is DocxShapeBlock) {
      return _renderShapeBlock(node, builder, x, y, layout);
    }
    return y;
  }

  double _renderShapeBlock(
    DocxShapeBlock shapeBlock,
    PdfContentBuilder builder,
    double startX,
    double startY,
    PdfLayoutEngine layout,
  ) {
    final shape = shapeBlock.shape;
    final maxWidth = layout.contentWidth;

    // Calculate X position based on alignment
    var x = startX;
    if (shapeBlock.align == DocxAlign.center) {
      x = startX + (maxWidth - shape.width) / 2;
    } else if (shapeBlock.align == DocxAlign.right) {
      x = startX + maxWidth - shape.width;
    }

    // Y position (PDF Y is from bottom)
    final y = startY - shape.height;

    _drawShape(builder, shape, x, y);

    return y - 10; // Return new cursor position with spacing
  }

  void _drawShape(
      PdfContentBuilder builder, DocxShape shape, double x, double y) {
    builder.saveState();

    // Set colors
    if (shape.fillColor != null) {
      builder.setFillColorHex(shape.fillColor!.hex);
    }
    if (shape.outlineColor != null) {
      builder.setStrokeColorHex(shape.outlineColor!.hex);
      builder.setLineWidth(shape.outlineWidth);
    }

    final w = shape.width;
    final h = shape.height;
    final hasFill = shape.fillColor != null;
    final hasStroke = shape.outlineColor != null;

    switch (shape.preset) {
      case DocxShapePreset.rect:
        builder.fillStrokeRect(x, y, w, h, lineWidth: shape.outlineWidth);

      case DocxShapePreset.roundRect:
        final r = (w < h ? w : h) * 0.15;
        builder.drawRoundedRect(x, y, w, h, r,
            stroke: hasStroke, fill: hasFill);

      case DocxShapePreset.ellipse:
        builder.drawEllipse(x + w / 2, y + h / 2, w / 2, h / 2,
            stroke: hasStroke, fill: hasFill);

      case DocxShapePreset.triangle:
        builder.drawPolygon([
          [x + w / 2, y + h], // Top
          [x, y], // Bottom left
          [x + w, y], // Bottom right
        ], stroke: hasStroke, fill: hasFill);

      case DocxShapePreset.diamond:
        builder.drawPolygon([
          [x + w / 2, y + h], // Top
          [x, y + h / 2], // Left
          [x + w / 2, y], // Bottom
          [x + w, y + h / 2], // Right
        ], stroke: hasStroke, fill: hasFill);

      case DocxShapePreset.rightArrow:
        _drawArrow(builder, x, y, w, h, 'right', hasFill, hasStroke);

      case DocxShapePreset.leftArrow:
        _drawArrow(builder, x, y, w, h, 'left', hasFill, hasStroke);

      case DocxShapePreset.upArrow:
        _drawArrow(builder, x, y, w, h, 'up', hasFill, hasStroke);

      case DocxShapePreset.downArrow:
        _drawArrow(builder, x, y, w, h, 'down', hasFill, hasStroke);

      case DocxShapePreset.star5:
        _drawStar(builder, x + w / 2, y + h / 2, w / 2, 5, hasFill, hasStroke);

      case DocxShapePreset.star4:
        _drawStar(builder, x + w / 2, y + h / 2, w / 2, 4, hasFill, hasStroke);

      case DocxShapePreset.star6:
        _drawStar(builder, x + w / 2, y + h / 2, w / 2, 6, hasFill, hasStroke);

      case DocxShapePreset.line:
        builder.drawLine(x, y + h / 2, x + w, y + h / 2,
            lineWidth: shape.outlineWidth);

      case DocxShapePreset.hexagon:
        _drawRegularPolygon(
            builder, x + w / 2, y + h / 2, w / 2, 6, hasFill, hasStroke);

      case DocxShapePreset.octagon:
        _drawRegularPolygon(
            builder, x + w / 2, y + h / 2, w / 2, 8, hasFill, hasStroke);

      case DocxShapePreset.pentagon:
        _drawRegularPolygon(
            builder, x + w / 2, y + h / 2, w / 2, 5, hasFill, hasStroke);

      default:
        // Fallback to rectangle for unsupported shapes
        builder.fillStrokeRect(x, y, w, h, lineWidth: shape.outlineWidth);
    }

    // Draw text inside shape if present
    if (shape.text != null && shape.text!.isNotEmpty) {
      builder.drawText(
        shape.text!,
        x + w / 2 - shape.text!.length * 3,
        y + h / 2 - 4,
        fontSize: 10,
        colorHex: '000000',
      );
    }

    builder.restoreState();
  }

  void _drawArrow(PdfContentBuilder builder, double x, double y, double w,
      double h, String direction, bool fill, bool stroke) {
    final points = <List<double>>[];
    final headSize = 0.4;
    final shaftWidth = 0.3;

    switch (direction) {
      case 'right':
        points.addAll([
          [x, y + h * (0.5 - shaftWidth / 2)],
          [x + w * (1 - headSize), y + h * (0.5 - shaftWidth / 2)],
          [x + w * (1 - headSize), y],
          [x + w, y + h / 2],
          [x + w * (1 - headSize), y + h],
          [x + w * (1 - headSize), y + h * (0.5 + shaftWidth / 2)],
          [x, y + h * (0.5 + shaftWidth / 2)],
        ]);
      case 'left':
        points.addAll([
          [x + w, y + h * (0.5 - shaftWidth / 2)],
          [x + w * headSize, y + h * (0.5 - shaftWidth / 2)],
          [x + w * headSize, y],
          [x, y + h / 2],
          [x + w * headSize, y + h],
          [x + w * headSize, y + h * (0.5 + shaftWidth / 2)],
          [x + w, y + h * (0.5 + shaftWidth / 2)],
        ]);
      case 'up':
        points.addAll([
          [x + w * (0.5 - shaftWidth / 2), y],
          [x + w * (0.5 - shaftWidth / 2), y + h * (1 - headSize)],
          [x, y + h * (1 - headSize)],
          [x + w / 2, y + h],
          [x + w, y + h * (1 - headSize)],
          [x + w * (0.5 + shaftWidth / 2), y + h * (1 - headSize)],
          [x + w * (0.5 + shaftWidth / 2), y],
        ]);
      case 'down':
        points.addAll([
          [x + w * (0.5 - shaftWidth / 2), y + h],
          [x + w * (0.5 - shaftWidth / 2), y + h * headSize],
          [x, y + h * headSize],
          [x + w / 2, y],
          [x + w, y + h * headSize],
          [x + w * (0.5 + shaftWidth / 2), y + h * headSize],
          [x + w * (0.5 + shaftWidth / 2), y + h],
        ]);
    }

    builder.drawPolygon(points, stroke: stroke, fill: fill);
  }

  void _drawStar(PdfContentBuilder builder, double cx, double cy, double r,
      int points, bool fill, bool stroke) {
    final innerR = r * 0.4;
    final vertices = <List<double>>[];

    for (var i = 0; i < points * 2; i++) {
      final angle = (i * pi / points) - pi / 2;
      final radius = i.isEven ? r : innerR;
      vertices.add([cx + radius * cos(angle), cy + radius * sin(angle)]);
    }

    builder.drawPolygon(vertices, stroke: stroke, fill: fill);
  }

  void _drawRegularPolygon(PdfContentBuilder builder, double cx, double cy,
      double r, int sides, bool fill, bool stroke) {
    final vertices = <List<double>>[];

    for (var i = 0; i < sides; i++) {
      final angle = (i * 2 * pi / sides) - pi / 2;
      vertices.add([cx + r * cos(angle), cy + r * sin(angle)]);
    }

    builder.drawPolygon(vertices, stroke: stroke, fill: fill);
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

        // Determine background color from highlight or shadingFill
        String? backgroundColor;
        if (child.highlight != DocxHighlight.none) {
          backgroundColor = _highlightToHex(child.highlight);
        } else if (child.shadingFill != null && child.shadingFill != 'auto') {
          backgroundColor = child.shadingFill;
        }

        // Decode HTML entities and handle newlines
        final decodedText = PdfContentBuilder.decodeHtmlEntities(child.content);

        // Split by newlines first to preserve line breaks in code blocks
        final lines = decodedText.split('\n');
        for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
          final line = lines[lineIdx];

          // Split each line segment by spaces for word wrapping
          for (final word in line.split(' ')) {
            if (word.isNotEmpty) {
              // Check for checkboxes
              bool isCheckbox = false;
              int? checkboxType;
              if (word == '\u2610') {
                isCheckbox = true;
                checkboxType = 0;
              } else if (word == '\u2611') {
                isCheckbox = true;
                checkboxType = 1;
              } else if (word == '\u2612') {
                isCheckbox = true;
                checkboxType = 2;
              }

              // Calculate width - handle custom font size and superscript/subscript
              var effFontSize = (child.fontSize ?? fontSize).toDouble();
              if (child.isSuperscript || child.isSubscript) {
                effFontSize *= 0.6;
              }
              // Use isBold for accurate text measurement
              final isBold = child.isBold || isHeading;
              final width = isCheckbox
                  ? effFontSize
                  : builder.measureText(word, effFontSize, isBold: isBold);

              words.add(_Word(
                word,
                fontRef,
                color,
                width,
                isUnderline: child.isUnderline,
                isStrike: child.isStrike,
                backgroundColor: backgroundColor,
                fontSize: child.fontSize,
                isSuperscript: child.isSuperscript,
                isSubscript: child.isSubscript,
                isCheckbox: isCheckbox,
                checkboxType: checkboxType,
              ));
            }
          }

          // Add line break between text lines (but not after the last one)
          if (lineIdx < lines.length - 1) {
            words.add(_Word.lineBreak());
          }
        }
      } else if (child is DocxLineBreak) {
        words.add(_Word.lineBreak());
      } else if (child is DocxTab) {
        words.add(_Word.tab(fontSize * 3));
      }
    }

    // Flow words into lines - use proper Helvetica space width (0.278)
    final spaceWidth = fontSize * 0.278;
    final lines = _flowWords(words, maxWidth, spaceWidth);

    // Track decoration positions for drawing after text
    final decorations = <_TextDecoration>[];

    // Calculate per-line heights based on max font size in each line
    final lineHeights = <double>[];
    for (final line in lines) {
      if (line.isEmpty) {
        lineHeights.add(lineHeight);
      } else {
        var maxFontInLine = fontSize.toDouble();
        for (final word in line) {
          final wordFontSize = (word.fontSize ?? fontSize).toDouble();
          if (wordFontSize > maxFontInLine) maxFontInLine = wordFontSize;
        }
        lineHeights.add(maxFontInLine * 1.4);
      }
    }

    // Calculate total height for paragraph background
    final totalParagraphHeight =
        lineHeights.fold<double>(0, (sum, h) => sum + h);

    // Draw paragraph background (use full width for code blocks etc.)
    if (paragraph.shadingFill != null && paragraph.shadingFill != 'auto') {
      builder.saveState();
      builder.setFillColorHex(paragraph.shadingFill!);
      final bgBottom = startY - totalParagraphHeight;
      builder.fillRect(
          startX + indent, bgBottom, maxWidth, totalParagraphHeight);
      builder.restoreState();
    }

    // Render lines
    var y = startY - fontSize * 0.3;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final currentLineHeight = lineHeights[i];

      if (line.isEmpty) {
        y -= currentLineHeight;
        continue;
      }

      // Calculate max font size for this line for proper baseline positioning
      var maxFontInLine = fontSize.toDouble();
      for (final word in line) {
        final wordFontSize = (word.fontSize ?? fontSize).toDouble();
        if (wordFontSize > maxFontInLine) maxFontInLine = wordFontSize;
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

      // First pass: draw text backgrounds
      var bgX = x;
      for (var k = 0; k < line.length; k++) {
        final word = line[k];
        if (!word.isTab && word.backgroundColor != null) {
          final wordFontSize = (word.fontSize ?? fontSize).toDouble();
          builder.saveState();
          builder.setFillColorHex(word.backgroundColor!);
          // Draw background rectangle behind word using word's font size
          builder.fillRect(
              bgX, y - wordFontSize * 0.2, word.width, wordFontSize * 1.2);
          builder.restoreState();
        }
        bgX += word.width;
        if (k < line.length - 1) bgX += spaceWidth + wordSpacing;
      }

      // Second pass: draw text with manual position tracking
      var textX = x;

      for (var k = 0; k < line.length; k++) {
        final word = line[k];

        if (word.isTab) {
          textX += word.width;
        } else if (word.isCheckbox) {
          // Draw checkbox manually
          builder.saveState();

          final boxSize = fontSize * 0.8;
          final boxY = y - boxSize * 0.1;

          builder.setStrokeColorHex(word.color);
          builder.setLineWidth(1);
          builder.strokeRect(textX, boxY, boxSize, boxSize);

          if (word.checkboxType == 1 || word.checkboxType == 2) {
            builder.moveTo(textX, boxY);
            builder.lineTo(textX + boxSize, boxY + boxSize);
            builder.moveTo(textX + boxSize, boxY);
            builder.lineTo(textX, boxY + boxSize);
            builder.strokePath();
          }

          builder.restoreState();
          textX += word.width;

          if (k < line.length - 1) {
            textX += spaceWidth + wordSpacing;
          }
        } else {
          // Normal text rendering with absolute positioning
          var effFontSize = (word.fontSize ?? fontSize).toDouble();
          var yPos = y;

          if (word.isSuperscript) {
            effFontSize *= 0.6;
            yPos = y + maxFontInLine * 0.4;
          } else if (word.isSubscript) {
            effFontSize *= 0.6;
            yPos = y - maxFontInLine * 0.2;
          }

          builder.beginText();
          builder.setTextMatrix(textX, yPos);
          builder.setFont(word.fontRef, effFontSize);
          builder.setFillColorHex(word.color);
          builder.showText(word.text);
          builder.endText();

          // Collect underline/strikethrough decorations
          if (word.isUnderline) {
            decorations.add(_TextDecoration(
              x: textX,
              y: yPos - effFontSize * 0.15,
              width: word.width,
              color: word.color,
              isStrike: false,
            ));
          }
          if (word.isStrike) {
            decorations.add(_TextDecoration(
              x: textX,
              y: yPos + effFontSize * 0.3,
              width: word.width,
              color: word.color,
              isStrike: true,
            ));
          }

          textX += word.width;

          if (k < line.length - 1) {
            textX += spaceWidth + wordSpacing;
          }
        }
      }

      y -= currentLineHeight;
    }

    // Draw decorations (underline, strikethrough)
    for (final dec in decorations) {
      builder.saveState();
      builder.setStrokeColorHex(dec.color);
      builder.drawLine(dec.x, dec.y, dec.x + dec.width, dec.y, lineWidth: 0.5);
      builder.restoreState();
    }

    if (lines.isEmpty) y = startY - lineHeight;

    // Add extra spacing after paragraphs (especially headings)
    final isHeading = paragraph.styleId?.startsWith('Heading') ?? false;
    final spacing = isHeading ? fontSize * 0.8 : fontSize * 0.5;
    return y - spacing;
  }

  /// Converts DocxHighlight enum to hex color
  String? _highlightToHex(DocxHighlight highlight) {
    switch (highlight) {
      case DocxHighlight.yellow:
        return 'FFFF00';
      case DocxHighlight.green:
        return '00FF00';
      case DocxHighlight.cyan:
        return '00FFFF';
      case DocxHighlight.magenta:
        return 'FF00FF';
      case DocxHighlight.red:
        return 'FF0000';
      case DocxHighlight.blue:
        return '0000FF';
      case DocxHighlight.darkBlue:
        return '00008B';
      case DocxHighlight.darkCyan:
        return '008B8B';
      case DocxHighlight.darkGreen:
        return '006400';
      case DocxHighlight.darkMagenta:
        return '8B008B';
      case DocxHighlight.darkRed:
        return '8B0000';
      case DocxHighlight.darkYellow:
        return '808000';
      case DocxHighlight.lightGray:
        return 'D3D3D3';
      case DocxHighlight.darkGray:
        return 'A9A9A9';
      case DocxHighlight.black:
        return '000000';
      case DocxHighlight.white:
        return 'FFFFFF';
      case DocxHighlight.none:
        return null;
    }
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
        final fontRef = PdfFontManager().selectFont(
          isBold: child.isBold,
          isItalic: child.isItalic,
        );
        final color = child.effectiveColorHex ?? '000000';

        String? backgroundColor;
        if (child.highlight != DocxHighlight.none) {
          backgroundColor = _highlightToHex(child.highlight);
        } else if (child.shadingFill != null && child.shadingFill != 'auto') {
          backgroundColor = child.shadingFill;
        }

        final decodedText = PdfContentBuilder.decodeHtmlEntities(child.content);
        final lines = decodedText.split('\n');

        for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
          final line = lines[lineIdx];

          for (final word in line.split(' ')) {
            if (word.isNotEmpty) {
              // Check for checkboxes
              bool isCheckbox = false;
              int? checkboxType;
              if (word == '\u2610') {
                isCheckbox = true;
                checkboxType = 0;
              } else if (word == '\u2611') {
                isCheckbox = true;
                checkboxType = 1;
              } else if (word == '\u2612') {
                isCheckbox = true;
                checkboxType = 2;
              }

              // Calculate width - handle custom font size and superscript/subscript
              var effFontSize = (child.fontSize ?? fontSize).toDouble();
              if (child.isSuperscript || child.isSubscript) {
                effFontSize *= 0.6;
              }
              final w = isCheckbox
                  ? effFontSize
                  : builder.measureText(word, effFontSize,
                      isBold: child.isBold);

              words.add(_Word(
                word,
                fontRef,
                color,
                w.toDouble(),
                isUnderline: child.isUnderline,
                isStrike: child.isStrike,
                backgroundColor: backgroundColor,
                fontSize: child.fontSize,
                isSuperscript: child.isSuperscript,
                isSubscript: child.isSubscript,
                isCheckbox: isCheckbox,
                checkboxType: checkboxType,
              ));
            }
          }

          if (lineIdx < lines.length - 1) {
            words.add(_Word.lineBreak());
          }
        }
      }
    }

    if (words.isEmpty) {
      return fontSize * 1.4; // Return default line height if empty
    }

    // 2. Flow words into lines based on cell width - use proper Helvetica space width (0.278)
    final spaceWidth = fontSize * 0.278;
    final lines = _flowWords(words, width, spaceWidth);
    final lineHeight = fontSize * 1.4;

    // 3. Render each line
    var currentY = y - fontSize * 0.3; // Align baseline
    for (final line in lines) {
      if (line.isEmpty) {
        currentY -= lineHeight;
        continue;
      }

      builder.beginText();
      builder.setTextMatrix(x, currentY);

      var textX = x;
      for (var k = 0; k < line.length; k++) {
        final word = line[k];

        // Background color
        if (word.backgroundColor != null) {
          builder.endText();
          builder.saveState();
          builder.setFillColorHex(word.backgroundColor!);
          builder.fillRect(
              textX, currentY - fontSize * 0.2, word.width, fontSize * 1.2);
          builder.restoreState();
          builder.beginText();
          builder.setTextMatrix(textX, currentY);
        }

        // Font calculation
        var effFontSize = word.fontSize ?? fontSize;
        var yOffset = 0.0;
        if (word.isSuperscript) {
          effFontSize *= 0.6;
          yOffset = fontSize * 0.4;
        } else if (word.isSubscript) {
          effFontSize *= 0.6;
          yOffset = -fontSize * 0.2;
        }

        if (word.isCheckbox) {
          builder.endText();
          builder.saveState();

          final boxSize = effFontSize * 0.8;
          final boxY = currentY + yOffset - boxSize * 0.1;

          builder.setStrokeColorHex(word.color);
          builder.setLineWidth(1);
          builder.strokeRect(textX, boxY, boxSize, boxSize);

          if (word.checkboxType == 1 || word.checkboxType == 2) {
            builder.moveTo(textX, boxY);
            builder.lineTo(textX + boxSize, boxY + boxSize);
            builder.moveTo(textX + boxSize, boxY);
            builder.lineTo(textX, boxY + boxSize);
            builder.strokePath();
          }

          builder.restoreState();
          builder.beginText();
          // Restore position for next word
          builder.setTextMatrix(textX + word.width, currentY);
        } else {
          builder.setFont(word.fontRef, effFontSize.toDouble());
          builder.setFillColorHex(word.color);
          builder.setTextMatrix(textX, currentY + yOffset);
          builder.showText(word.text);
          builder.setTextMatrix(textX + word.width, currentY);
        }

        if (k < line.length - 1) {
          builder.setTextMatrix(textX + word.width, currentY);
          builder.showText(' ');
          textX += spaceWidth;
        }
        textX += word.width;
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
          final fontRef = PdfFontManager().selectFont(
            isBold: child.isBold,
            isItalic: child.isItalic,
          );
          final color = child.effectiveColorHex ?? '000000';

          String? backgroundColor;
          if (child.highlight != DocxHighlight.none) {
            backgroundColor = _highlightToHex(child.highlight);
          } else if (child.shadingFill != null && child.shadingFill != 'auto') {
            backgroundColor = child.shadingFill;
          }

          // Decode HTML entities and handle newlines
          final decodedText =
              PdfContentBuilder.decodeHtmlEntities(child.content);
          final textLines = decodedText.split('\n');

          for (var lineIdx = 0; lineIdx < textLines.length; lineIdx++) {
            final line = textLines[lineIdx];
            final parts = line.split(' ');
            for (var i = 0; i < parts.length; i++) {
              final word = parts[i];
              if (word.isNotEmpty) {
                // Check for checkboxes
                bool isCheckbox = false;
                int? checkboxType;
                if (word == '\u2610') {
                  isCheckbox = true;
                  checkboxType = 0;
                } else if (word == '\u2611') {
                  isCheckbox = true;
                  checkboxType = 1;
                } else if (word == '\u2612') {
                  isCheckbox = true;
                  checkboxType = 2;
                }

                // Calculate width - handle superscript/subscript
                var effFontSize = (child.fontSize ?? fontSize).toDouble();
                if (child.isSuperscript || child.isSubscript) {
                  effFontSize *= 0.6;
                }
                final w = isCheckbox
                    ? effFontSize
                    : builder.measureText(word, effFontSize,
                        isBold: child.isBold);

                words.add(_Word(
                  word,
                  fontRef,
                  color,
                  w,
                  isUnderline: child.isUnderline,
                  isStrike: child.isStrike,
                  backgroundColor: backgroundColor,
                  fontSize: child.fontSize,
                  isSuperscript: child.isSuperscript,
                  isSubscript: child.isSubscript,
                  isCheckbox: isCheckbox,
                  checkboxType: checkboxType,
                ));
              }
            }

            if (lineIdx < textLines.length - 1) {
              words.add(_Word.lineBreak());
            }
          }
        }
      }

      if (words.isNotEmpty) {
        final spaceWidth = fontSize * 0.278;
        final lines = _flowWords(words, availableWidth, spaceWidth);

        // Render list item lines
        var currentY = y - fontSize * 0.3; // Align baseline (approx)
        for (final line in lines) {
          if (line.isEmpty) {
            currentY -= lineHeight;
            continue;
          }

          builder.beginText();
          builder.setTextMatrix(contentX, currentY);

          var textX = contentX;
          for (var k = 0; k < line.length; k++) {
            final word = line[k];

            // Background
            if (word.backgroundColor != null) {
              builder.endText();
              builder.saveState();
              builder.setFillColorHex(word.backgroundColor!);
              builder.fillRect(
                  textX, currentY - fontSize * 0.2, word.width, fontSize * 1.2);
              builder.restoreState();
              builder.beginText();
              builder.setTextMatrix(textX, currentY);
            }

            // Font & Style
            var effFontSize = word.fontSize ?? fontSize;
            var yOffset = 0.0;
            if (word.isSuperscript) {
              effFontSize *= 0.6;
              yOffset = fontSize * 0.4;
            } else if (word.isSubscript) {
              effFontSize *= 0.6;
              yOffset = -fontSize * 0.2;
            }

            if (word.isCheckbox) {
              builder.endText();
              builder.saveState();

              final boxSize = effFontSize * 0.8;
              final boxY = currentY + yOffset - boxSize * 0.1;

              builder.setStrokeColorHex(word.color);
              builder.setLineWidth(1);
              builder.strokeRect(textX, boxY, boxSize, boxSize);

              if (word.checkboxType == 1 || word.checkboxType == 2) {
                builder.moveTo(textX, boxY);
                builder.lineTo(textX + boxSize, boxY + boxSize);
                builder.moveTo(textX + boxSize, boxY);
                builder.lineTo(textX, boxY + boxSize);
                builder.strokePath();
              }

              builder.restoreState();
              builder.beginText();
              builder.setTextMatrix(textX + word.width, currentY);
            } else {
              builder.setFont(word.fontRef, effFontSize.toDouble());
              builder.setFillColorHex(word.color);
              builder.setTextMatrix(textX, currentY + yOffset);
              builder.showText(word.text);
              builder.setTextMatrix(textX + word.width, currentY);
            }

            if (k < line.length - 1) {
              builder.setTextMatrix(textX + word.width, currentY);
              builder.showText(' ');
              textX += spaceWidth;
            }
            textX += word.width;
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

  // Text decorations
  final bool isUnderline;
  final bool isStrike;

  // Background color (from highlight or shadingFill)
  final String? backgroundColor;

  // Font adjustments
  final double? fontSize;
  final bool isSuperscript;
  final bool isSubscript;

  // Custom rendering
  final bool isCheckbox;
  final int? checkboxType; // 0=unchecked, 1=checked, 2=crossed

  _Word(
    this.text,
    this.fontRef,
    this.color,
    this.width, {
    this.isUnderline = false,
    this.isStrike = false,
    this.backgroundColor,
    this.fontSize,
    this.isSuperscript = false,
    this.isSubscript = false,
    this.isCheckbox = false,
    this.checkboxType,
  })  : isTab = false,
        isBreak = false;

  _Word.tab(this.width)
      : text = '',
        fontRef = '',
        color = '',
        isTab = true,
        isBreak = false,
        isUnderline = false,
        isStrike = false,
        backgroundColor = null,
        fontSize = null,
        isSuperscript = false,
        isSubscript = false,
        isCheckbox = false,
        checkboxType = null;

  _Word.lineBreak()
      : text = '',
        fontRef = '',
        color = '',
        width = 0,
        isTab = false,
        isBreak = true,
        isUnderline = false,
        isStrike = false,
        backgroundColor = null,
        fontSize = null,
        isSuperscript = false,
        isSubscript = false,
        isCheckbox = false,
        checkboxType = null;
}

/// Helper class to track text decoration positions for underline/strikethrough
class _TextDecoration {
  final double x;
  final double y;
  final double width;
  final String color;
  final bool isStrike;

  const _TextDecoration({
    required this.x,
    required this.y,
    required this.width,
    required this.color,
    required this.isStrike,
  });
}
