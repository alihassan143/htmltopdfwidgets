import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';
import '../theme/docx_view_theme.dart';
import '../search/docx_search_controller.dart';
import 'paragraph_builder.dart';
import 'table_builder.dart';
import 'list_builder.dart';
import 'image_builder.dart';
import 'shape_builder.dart';

/// Generates Flutter widgets from [DocxNode] elements.
///
/// This is the core "brain" that maps OpenXML elements to Flutter widgets.
class DocxWidgetGenerator {
  final DocxViewConfig config;
  final DocxViewTheme theme;
  final DocxSearchController? searchController;

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
  }) : theme = theme ?? DocxViewTheme.light() {
    _paragraphBuilder = ParagraphBuilder(
      theme: this.theme,
      config: config,
      searchController: searchController,
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

  /// Generate a list of widgets from document elements.
  List<Widget> generateWidgets(List<DocxNode> elements) {
    final widgets = <Widget>[];

    for (final element in elements) {
      final widget = generateWidget(element);
      if (widget != null) {
        widgets.add(widget);
      }
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
    }
    return null;
  }

  /// Extract all text content for search indexing.
  List<String> extractTextForSearch(List<DocxNode> elements) {
    final texts = <String>[];

    for (final element in elements) {
      final text = _extractText(element);
      texts.add(text);
    }

    return texts;
  }

  String _extractText(DocxNode node) {
    if (node is DocxParagraph) {
      return node.children
          .whereType<DocxText>()
          .map((t) => t.content)
          .join();
    } else if (node is DocxList) {
      return node.items
          .map((item) => item.children
              .whereType<DocxText>()
              .map((t) => t.content)
              .join())
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
