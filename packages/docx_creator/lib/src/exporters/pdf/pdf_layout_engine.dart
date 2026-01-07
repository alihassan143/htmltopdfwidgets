import '../../../docx_creator.dart';
import 'pdf_font_manager.dart';

/// Handles document layout, measurement, and pagination.
///
/// Uses a two-pass approach: measure blocks first, then render.
class PdfLayoutEngine {
  final double pageWidth;
  final double pageHeight;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final double baseFontSize;

  PdfLayoutEngine({
    required this.pageWidth,
    required this.pageHeight,
    this.marginTop = 72,
    this.marginBottom = 72,
    this.marginLeft = 72,
    this.marginRight = 72,
    this.baseFontSize = 12,
  });

  /// Content area dimensions
  double get contentWidth => pageWidth - marginLeft - marginRight;
  double get contentHeight => pageHeight - marginTop - marginBottom;
  double get contentTop => pageHeight - marginTop;
  double get contentBottom => marginBottom;

  /// Paginates document nodes into pages.
  ///
  /// Returns a list of pages, where each page is a list of nodes.
  List<List<DocxNode>> paginate(List<DocxNode> nodes) {
    final pages = <List<DocxNode>>[];
    var currentPage = <DocxNode>[];
    var remainingHeight = contentHeight;

    for (final node in nodes) {
      // Handle explicit page breaks
      if (node is DocxSectionBreakBlock) {
        if (currentPage.isNotEmpty) {
          pages.add(currentPage);
          currentPage = [];
        }
        remainingHeight = contentHeight;
        continue;
      }

      final height = measureNode(node);

      // Check if node fits on current page
      if (remainingHeight - height < 0 && currentPage.isNotEmpty) {
        pages.add(currentPage);
        currentPage = [];
        remainingHeight = contentHeight;
      }

      currentPage.add(node);
      remainingHeight -= height;
    }

    if (currentPage.isNotEmpty) {
      pages.add(currentPage);
    }

    if (pages.isEmpty) {
      pages.add([]);
    }

    return pages;
  }

  /// Measures the height of a node.
  double measureNode(DocxNode node) {
    if (node is DocxParagraph) {
      return measureParagraph(node);
    } else if (node is DocxTable) {
      return measureTable(node);
    } else if (node is DocxList) {
      return measureList(node);
    } else if (node is DocxImage) {
      return node.height + 10;
    }
    return baseFontSize * 1.5;
  }

  /// Measures paragraph height including line wrapping.
  double measureParagraph(DocxParagraph paragraph) {
    final fontSize = getFontSize(paragraph.styleId);
    final lineHeight = fontSize * 1.4;
    final indent = (paragraph.indentLeft ?? 0) / 20.0;
    final availableWidth = contentWidth - indent;

    if (paragraph.children.isEmpty) {
      return lineHeight + fontSize * 0.5;
    }

    // Collect text
    final textBuffer = StringBuffer();
    for (final child in paragraph.children) {
      if (child is DocxText) {
        textBuffer.write(child.content);
      } else if (child is DocxLineBreak) {
        textBuffer.write('\n');
      } else if (child is DocxTab) {
        textBuffer.write('    ');
      }
    }

    final text = textBuffer.toString();
    final lines = _wrapText(text, availableWidth, fontSize);

    return lines * lineHeight + fontSize * 0.5;
  }

  /// Measures table height.
  double measureTable(DocxTable table) {
    if (table.rows.isEmpty) return 0;

    final cols = table.rows.first.cells.length;
    final colWidth = contentWidth / cols;

    double totalHeight = 0;
    for (final row in table.rows) {
      double maxRowHeight = 0;
      for (final cell in row.cells) {
        final cellHeight = measureCell(cell, colWidth - 4);
        if (cellHeight > maxRowHeight) maxRowHeight = cellHeight;
      }
      totalHeight += maxRowHeight < 20 ? 20 : maxRowHeight;
    }
    return totalHeight + 10;
  }

  /// Measures cell height.
  double measureCell(DocxTableCell cell, double width) {
    double height = 0;
    for (final block in cell.children) {
      if (block is DocxParagraph) {
        height += measureParagraphInWidth(block, width);
      } else if (block is DocxTable) {
        height += measureTableInWidth(block, width);
      } else if (block is DocxList) {
        height += block.items.length * baseFontSize * 1.5;
      }
    }
    return height + 10;
  }

  /// Measures paragraph in specific width.
  double measureParagraphInWidth(DocxParagraph paragraph, double width) {
    final fontSize = getFontSize(paragraph.styleId);
    final lineHeight = fontSize * 1.4;

    if (paragraph.children.isEmpty) return lineHeight;

    final textBuffer = StringBuffer();
    for (final child in paragraph.children) {
      if (child is DocxText) textBuffer.write(child.content);
    }

    final lines = _wrapText(textBuffer.toString(), width, fontSize);
    return lines * lineHeight;
  }

  /// Measures table in specific width.
  double measureTableInWidth(DocxTable table, double width) {
    if (table.rows.isEmpty) return 0;

    final cols = table.rows.first.cells.length;
    final colWidth = width / cols;

    double totalHeight = 0;
    for (final row in table.rows) {
      double maxRowHeight = 20;
      for (final cell in row.cells) {
        final cellHeight = measureCell(cell, colWidth - 4);
        if (cellHeight > maxRowHeight) maxRowHeight = cellHeight;
      }
      totalHeight += maxRowHeight;
    }
    return totalHeight + 10;
  }

  /// Measures list height.
  double measureList(DocxList list) {
    double height = 0;
    for (final item in list.items) {
      height += measureListItem(item, list.style);
    }
    return height + 10;
  }

  /// Measures list item height.
  double measureListItem(DocxListItem item, DocxListStyle listStyle) {
    final fontSize =
        item.overrideStyle?.fontSize ?? listStyle.fontSize ?? baseFontSize;
    // contentWidth includes margins.
    // List indentation: ~36pt (0.5 inch) per level + hanging indent
    final indent = (item.level + 1) * 36.0;
    final availableWidth = contentWidth - indent;

    final lineHeight = fontSize * 1.4;

    if (item.children.isEmpty) {
      return lineHeight + fontSize * 0.5;
    }

    final textBuffer = StringBuffer();
    for (final child in item.children) {
      if (child is DocxText) {
        textBuffer.write(child.content);
      } else if (child is DocxLineBreak) {
        textBuffer.write('\n');
      } else if (child is DocxTab) {
        textBuffer.write('    ');
      }
    }

    final text = textBuffer.toString();
    final lines = _wrapText(text, availableWidth, fontSize);

    return lines * lineHeight + fontSize * 0.5;
  }

  /// Gets font size for a style.
  double getFontSize(String? styleId) {
    if (styleId == null) return baseFontSize.toDouble();
    if (styleId.startsWith('Heading1')) return baseFontSize * 2.0;
    if (styleId.startsWith('Heading2')) return baseFontSize * 1.5;
    if (styleId.startsWith('Heading')) return baseFontSize * 1.3;
    return baseFontSize.toDouble();
  }

  /// Counts lines needed for text in given width.
  int _wrapText(String text, double availableWidth, double fontSize) {
    final charWidth = fontSize * PdfFontManager.avgCharWidth;
    final charsPerLine = (availableWidth / charWidth).floor();
    if (charsPerLine <= 0) return 1;

    // Split by explicit newlines first
    final paragraphs = text.split('\n');
    int totalLines = 0;

    for (final para in paragraphs) {
      if (para.isEmpty) {
        totalLines++;
        continue;
      }

      final words = para.split(' ');
      var currentLineLen = 0;
      var lines = 1;

      for (final word in words) {
        final wordLen = word.length + 1; // +1 for space
        if (currentLineLen + wordLen > charsPerLine && currentLineLen > 0) {
          lines++;
          currentLineLen = word.length;
        } else {
          currentLineLen += wordLen;
        }
      }
      totalLines += lines;
    }

    return totalLines > 0 ? totalLines : 1;
  }
}
