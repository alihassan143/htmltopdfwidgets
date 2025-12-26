import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';
import '../search/docx_search_controller.dart';
import '../theme/docx_view_theme.dart';
import 'image_builder.dart';
import 'list_builder.dart';
import 'paragraph_builder.dart';
import 'shape_builder.dart';
import 'table_builder.dart';

/// Generates Flutter widgets from [DocxNode] elements.
///
/// This is the core "brain" that maps OpenXML elements to Flutter widgets.
class DocxWidgetGenerator {
  final DocxViewConfig config;
  final DocxViewTheme theme;
  final DocxSearchController? searchController;

  final void Function(int id)? onFootnoteTap;
  final void Function(int id)? onEndnoteTap;

  /// Paragraph builder for text rendering.
  late final ParagraphBuilder _paragraphBuilder;

  /// Table builder for table rendering.
  late final TableBuilder _tableBuilder;

  /// List builder for list rendering.
  late final ListBuilder _listBuilder;

  /// Image builder for image rendering.
  late final ImageBuilder _imageBuilder;

  /// Shape builder for shape rendering.
  late final ShapeBuilder _shapeBuilder;

  DocxWidgetGenerator({
    required this.config,
    DocxViewTheme? theme,
    this.searchController,
    this.onFootnoteTap,
    this.onEndnoteTap,
  }) : theme = theme ?? DocxViewTheme.light() {
    _paragraphBuilder = ParagraphBuilder(
      theme: this.theme,
      config: config,
      searchController: searchController,
      onFootnoteTap: onFootnoteTap,
      onEndnoteTap: onEndnoteTap,
    );
    _tableBuilder = TableBuilder(
      theme: this.theme,
      config: config,
      paragraphBuilder: _paragraphBuilder,
    );
    _listBuilder = ListBuilder(
      theme: this.theme,
      config: config,
      paragraphBuilder: _paragraphBuilder,
    );
    _imageBuilder = ImageBuilder(config: config);
    _shapeBuilder = ShapeBuilder(config: config);
  }

  /// Generate a list of widgets from a parsed document.
  List<Widget> generateWidgets(DocxBuiltDocument doc) {
    final widgets = <Widget>[];

    // 1. Header
    if (doc.section?.header != null) {
      widgets.addAll(_generateBlockWidgets(doc.section!.header!.children));
      // Add visual separation for header
      widgets.add(const Divider(height: 32, thickness: 1, color: Colors.grey));
    }

    // 2. Body
    widgets.addAll(_generateBlockWidgets(doc.elements));

    // 3. Footnotes (Appended to end for continuous view)
    if (doc.footnotes != null && doc.footnotes!.isNotEmpty) {
      widgets.add(const Divider(height: 32, thickness: 1));
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text('Footnotes',
            style: theme.defaultTextStyle
                .copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
      ));

      for (var footnote in doc.footnotes!) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${footnote.footnoteId}. ',
                  style: theme.defaultTextStyle
                      .copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _generateBlockWidgets(footnote.content),
                ),
              ),
            ],
          ),
        ));
      }
    }

    // 4. Endnotes
    if (doc.endnotes != null && doc.endnotes!.isNotEmpty) {
      widgets.add(const Divider(height: 32, thickness: 1));
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text('Endnotes',
            style: theme.defaultTextStyle
                .copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
      ));

      for (var endnote in doc.endnotes!) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${endnote.endnoteId}. ',
                  style: theme.defaultTextStyle
                      .copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _generateBlockWidgets(endnote.content),
                ),
              ),
            ],
          ),
        ));
      }
    }

    // 5. Footer
    if (doc.section?.footer != null) {
      widgets.add(const Divider(height: 32, thickness: 1, color: Colors.grey));
      widgets.addAll(_generateBlockWidgets(doc.section!.footer!.children));
    }

    return widgets;
  }

  /// Generate widgets for a list of blocks.
  List<Widget> _generateBlockWidgets(List<DocxNode> elements) {
    final widgets = <Widget>[];
    int i = 0;

    while (i < elements.length) {
      final element = elements[i];

      // Check for floating table
      if (element is DocxTable && element.position != null) {
        // This is a floating table - group with following paragraphs
        final floatingTable = element;
        final followingParagraphs = <DocxNode>[];

        // Collect paragraphs that should wrap around this table
        // We take paragraphs until we hit another block-level element (table, list, image)
        // or until we've collected enough content (heuristic: ~5 paragraphs max)
        int j = i + 1;
        while (j < elements.length && followingParagraphs.length < 5) {
          final next = elements[j];
          if (next is DocxParagraph || next is DocxDropCap) {
            followingParagraphs.add(next);
            j++;
          } else {
            break; // Stop at non-paragraph block
          }
        }

        if (followingParagraphs.isNotEmpty) {
          // Build the floating Row layout
          final tableWidget = _tableBuilder.build(floatingTable);
          final paragraphWidgets = followingParagraphs.map((p) {
            if (p is DocxParagraph) {
              return _paragraphBuilder.build(p);
            } else if (p is DocxDropCap) {
              return _paragraphBuilder.buildDropCap(p);
            }
            return const SizedBox.shrink();
          }).toList();

          // Determine float side from table position
          final isRightFloat =
              floatingTable.position?.hAnchor == DocxTableHAnchor.margin &&
                  floatingTable.alignment == DocxAlign.right;

          Widget rowWidget;
          if (isRightFloat) {
            // Table on the right
            rowWidget = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: paragraphWidgets)),
                const SizedBox(width: 12),
                tableWidget,
              ],
            );
          } else {
            // Table on the left (default)
            rowWidget = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tableWidget,
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: paragraphWidgets)),
              ],
            );
          }

          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: rowWidget,
          ));
          i = j; // Skip to after grouped paragraphs
          continue;
        }
      }

      // Standard element processing
      final widget = generateWidget(element);
      if (widget != null) {
        widgets.add(widget);
      }
      i++;
    }

    return widgets;
  }

  /// Generate a single widget from a [DocxNode].
  Widget? generateWidget(DocxNode node) {
    if (node is DocxParagraph) {
      return _paragraphBuilder.build(node);
    } else if (node is DocxTable) {
      return _tableBuilder.build(node);
    } else if (node is DocxList) {
      return _listBuilder.build(node);
    } else if (node is DocxImage) {
      return _imageBuilder.buildBlockImage(node);
    } else if (node is DocxShapeBlock) {
      return _shapeBuilder.buildBlockShape(node);
    } else if (node is DocxDropCap) {
      return _paragraphBuilder.buildDropCap(node);
    } else if (node is DocxSectionBreakBlock) {
      // Render section breaks as horizontal dividers
      return const Divider(height: 24, thickness: 1);
    } else if (node is DocxRawXml) {
      // Fallback for unrecognized block elements - render as debug placeholder
      // In production, you might want to hide these or log them
      return config.showDebugInfo
          ? Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '[Unsupported element]',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          : const SizedBox.shrink();
    }
    return null;
  }

  /// Extract all text content for search indexing.
  List<String> extractTextForSearch(DocxBuiltDocument doc) {
    final texts = <String>[];

    // Header
    if (doc.section?.header != null) {
      for (var element in doc.section!.header!.children) {
        texts.add(_extractText(element));
      }
    }

    // Body
    for (final element in doc.elements) {
      final text = _extractText(element);
      texts.add(text);
    }

    // Footer
    if (doc.section?.footer != null) {
      for (var element in doc.section!.footer!.children) {
        texts.add(_extractText(element));
      }
    }

    return texts;
  }

  String _extractText(DocxNode node) {
    if (node is DocxParagraph) {
      return node.children.whereType<DocxText>().map((t) => t.content).join();
    } else if (node is DocxDropCap) {
      return node.letter +
          node.restOfParagraph
              .whereType<DocxText>()
              .map((t) => t.content)
              .join();
    } else if (node is DocxList) {
      return node.items
          .map((item) =>
              item.children.whereType<DocxText>().map((t) => t.content).join())
          .join(' ');
    } else if (node is DocxTable) {
      return node.rows
          .expand((row) => row.cells)
          .expand((cell) => cell.children)
          .whereType<DocxParagraph>()
          .expand((p) => p.children)
          .whereType<DocxText>()
          .map((t) => t.content)
          .join(' ');
    }
    return '';
  }
}
