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
  final PdfFontManager fontManager;

  PdfLayoutEngine({
    required this.pageWidth,
    required this.pageHeight,
    this.marginTop = 72,
    this.marginBottom = 72,
    this.marginLeft = 72,
    this.marginRight = 72,
    this.baseFontSize = 12,
    PdfFontManager? fontManager,
  }) : fontManager = fontManager ?? PdfFontManager();

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
      if (remainingHeight - height < 0) {
        // If it fits on a clean page, and we aren't empty, just break page
        if (height <= contentHeight && currentPage.isNotEmpty) {
          pages.add(currentPage);
          currentPage = [];
          remainingHeight = contentHeight;
          currentPage.add(node);
          remainingHeight -= height;
        } else if (node is DocxParagraph) {
          // It does not fit or is huge. Split it.
          if (currentPage.isNotEmpty && remainingHeight < baseFontSize * 2) {
            // Too little space left, just move to next page to start clean
            pages.add(currentPage);
            currentPage = [];
            remainingHeight = contentHeight;
          }

          final splitResult = _splitParagraph(node, remainingHeight);
          final fittedPart = splitResult.first;
          final remainderPart = splitResult.last;

          if (fittedPart.children.isEmpty) {
            // Did not fit at all on current page (or remainingHeight was tiny)
            if (currentPage.isNotEmpty) {
              pages.add(currentPage);
              currentPage = [];
              remainingHeight = contentHeight;

              // Retry on new page
              final splitResult2 = _splitParagraph(node, remainingHeight);
              if (splitResult2.first.children.isNotEmpty) {
                currentPage.add(splitResult2.first);
                remainingHeight -= measureParagraph(splitResult2.first);

                var currentRemainder = splitResult2.last;
                while (currentRemainder.children.isNotEmpty) {
                  if (remainingHeight < baseFontSize) {
                    pages.add(currentPage);
                    currentPage = [];
                    remainingHeight = contentHeight;
                  }

                  final remHeight = measureParagraph(currentRemainder);
                  if (remHeight <= remainingHeight) {
                    currentPage.add(currentRemainder);
                    remainingHeight -= remHeight;
                    break;
                  }

                  final nextSplit =
                      _splitParagraph(currentRemainder, remainingHeight);
                  if (nextSplit.first.children.isNotEmpty) {
                    currentPage.add(nextSplit.first);
                    remainingHeight -= measureParagraph(nextSplit.first);
                    currentRemainder = nextSplit.last;
                  } else {
                    // Should not happen if logic is sound, but safe guard
                    pages.add(currentPage);
                    currentPage = [];
                    remainingHeight = contentHeight;
                  }
                }
              } else {
                // Huge single line?
                currentPage.add(node);
                remainingHeight -= height;
              }
            } else {
              currentPage.add(node);
              remainingHeight -= height;
            }
          } else {
            currentPage.add(fittedPart);
            remainingHeight -= measureParagraph(fittedPart);

            var currentRemainder = remainderPart;
            while (currentRemainder.children.isNotEmpty) {
              if (remainingHeight < baseFontSize) {
                pages.add(currentPage);
                currentPage = [];
                remainingHeight = contentHeight;
              }

              final remHeight = measureParagraph(currentRemainder);
              if (remHeight <= remainingHeight) {
                currentPage.add(currentRemainder);
                remainingHeight -= remHeight;
                break;
              }

              final nextSplit =
                  _splitParagraph(currentRemainder, remainingHeight);
              if (nextSplit.first.children.isNotEmpty) {
                currentPage.add(nextSplit.first);
                remainingHeight -= measureParagraph(nextSplit.first);
                currentRemainder = nextSplit.last;
              } else {
                pages.add(currentPage);
                currentPage = [];
                remainingHeight = contentHeight;
              }
            }
          }
        } else {
          // Not a paragraph (e.g. table/image)
          if (currentPage.isNotEmpty) {
            pages.add(currentPage);
            currentPage = [];
            remainingHeight = contentHeight;
          }
          currentPage.add(node);
          remainingHeight -= height;
        }
      } else {
        currentPage.add(node);
        remainingHeight -= height;
      }
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

  // ... (previous code)

  /// Splits a paragraph into two parts: one that fits in availableHeight, and the remainder.
  /// Returns a list of two DocxParagraphs. The second one is null if everything fits.
  List<DocxParagraph> _splitParagraph(
      DocxParagraph paragraph, double availableHeight) {
    final fontSize = getFontSize(paragraph.styleId);
    final lineHeight = fontSize * 1.4;
    final indent = (paragraph.indentLeft ?? 0) / 20.0;
    final availableWidth = contentWidth - indent;

    // 1. Calculate max lines
    // We remove some padding/margins from available height to be safe
    final maxLines = ((availableHeight - fontSize * 0.5) / lineHeight).floor();

    if (maxLines <= 0) {
      // Can't fit anything substantial
      return [_createParagraph(paragraph, []), paragraph];
    }

    final fittedChildren = <DocxInline>[];
    final remainingChildren = <DocxInline>[];

    var currentLine = 1;
    var currentLineWidth = 0.0;
    var splitOccurred = false;
    final spaceWidth = fontManager.measureText(' ', fontSize);

    // Iterate children
    for (var i = 0; i < paragraph.children.length; i++) {
      final child = paragraph.children[i];

      if (splitOccurred) {
        remainingChildren.add(child);
        continue;
      }

      if (child is DocxText) {
        final text = child.content;
        final lines = text.split('\n');

        // We might need to split this text node
        final fittedTextBuffer = StringBuffer();
        final remainingTextBuffer = StringBuffer();
        var nodeSplit = false;

        for (var l = 0; l < lines.length; l++) {
          final line = lines[l];

          if (nodeSplit) {
            if (l > 0) remainingTextBuffer.write('\n');
            remainingTextBuffer.write(line);
            continue;
          }

          if (l > 0) {
            // Newline in source means new line in output
            currentLine++;
            currentLineWidth = 0;
            if (currentLine > maxLines) {
              // Split at this newline
              nodeSplit = true;
              if (l > 0) remainingTextBuffer.write('\n');
              remainingTextBuffer.write(line);
              continue;
            }
            fittedTextBuffer.write('\n');
          }

          if (line.isEmpty) continue; // Empty line (just newline handled above)

          final words = line.split(' ');
          for (var w = 0; w < words.length; w++) {
            final word = words[w];
            final wordWidth = fontManager.measureText(word, fontSize);

            if (currentLineWidth + wordWidth > availableWidth &&
                currentLineWidth > 0) {
              currentLine++;
              currentLineWidth = wordWidth + spaceWidth;
            } else {
              currentLineWidth += wordWidth + spaceWidth;
            }

            if (currentLine > maxLines) {
              // Split here
              nodeSplit = true;
              // Add this word and rest of line to remainder
              for (var k = w; k < words.length; k++) {
                if (k > w) remainingTextBuffer.write(' ');
                remainingTextBuffer.write(words[k]);
              }
              break;
            } else {
              if (w > 0) fittedTextBuffer.write(' ');
              fittedTextBuffer.write(word);
            }
          }
        }

        if (fittedTextBuffer.isNotEmpty) {
          fittedChildren.add(_cloneText(child, fittedTextBuffer.toString()));
        }
        if (remainingTextBuffer.isNotEmpty) {
          remainingChildren
              .add(_cloneText(child, remainingTextBuffer.toString()));
          splitOccurred = true;
        } else if (nodeSplit) {
          splitOccurred = true;
        }
      } else if (child is DocxLineBreak) {
        currentLine++;
        currentLineWidth = 0;
        if (currentLine > maxLines) {
          splitOccurred = true;
          remainingChildren.add(child);
        } else {
          fittedChildren.add(child);
        }
      } else {
        // Tab or others
        if (child is DocxTab) {
          currentLineWidth += fontSize * 3; // Approx tab width
          if (currentLineWidth > availableWidth) {
            currentLine++;
            currentLineWidth = fontSize * 3;
          }
        }

        if (currentLine > maxLines) {
          splitOccurred = true;
          remainingChildren.add(child);
        } else {
          fittedChildren.add(child);
        }
      }
    }

    return [
      _createParagraph(paragraph, fittedChildren),
      remainingChildren.isEmpty
          ? _createParagraph(paragraph, [])
          : _createParagraph(paragraph, remainingChildren)
    ];
  }

  DocxParagraph _createParagraph(
      DocxParagraph original, List<DocxInline> newChildren) {
    return original.copyWith(children: newChildren);
  }

  DocxText _cloneText(DocxText original, String newContent) {
    return original.copyWith(content: newContent);
  }

  /// Counts lines needed for text in given width.
  int _wrapText(String text, double availableWidth, double fontSize) {
    // 1. Split by explicit newlines
    final paragraphs = text.split('\n');
    int totalLines = 0;

    for (final para in paragraphs) {
      if (para.isEmpty) {
        totalLines++;
        continue;
      }

      // 2. Measure words and wrap
      final words = para.split(' ');
      var currentLineWidth = 0.0;
      var lines = 1;
      final spaceWidth = fontManager.measureText(' ', fontSize);

      for (final word in words) {
        final wordWidth = fontManager.measureText(word, fontSize);

        if (currentLineWidth + wordWidth > availableWidth &&
            currentLineWidth > 0) {
          lines++;
          currentLineWidth = wordWidth + spaceWidth;
        } else {
          currentLineWidth += wordWidth + spaceWidth;
        }
      }
      totalLines += lines;
    }

    return totalLines > 0 ? totalLines : 1;
  }
}
