import 'package:docx_creator/docx_creator.dart';

/// A simple service interface for translation.
abstract class TranslationService {
  Future<String> translate(String text, String targetLang);
}

/// A mock implementation that appends the language code.
class MockTranslationService implements TranslationService {
  @override
  Future<String> translate(String text, String targetLang) async {
    if (text.trim().isEmpty) return text;
    // Simulate async network call
    await Future.delayed(const Duration(milliseconds: 1));
    return '[$targetLang] $text';
  }
}

/// Traverses the document AST and translates all text nodes.
class DocumentTranslator {
  final TranslationService _service;

  DocumentTranslator(this._service);

  /// Translates the entire document to the target language.
  Future<DocxBuiltDocument> translateDocument(
    DocxBuiltDocument doc,
    String targetLang,
  ) async {
    final translatedElements = <DocxNode>[];
    for (var node in doc.elements) {
      translatedElements.add(await _translateNode(node, targetLang));
    }

    // Return a new document with translated content and preserved properties
    return DocxBuiltDocument(
      elements: translatedElements,
      section: doc.section, // Section props usually don't need translation
      stylesXml: doc.stylesXml,
      numberingXml: doc.numberingXml,
      settingsXml: doc.settingsXml,
      fontTableXml: doc.fontTableXml,
      contentTypesXml: doc.contentTypesXml,
      rootRelsXml: doc.rootRelsXml,
      headerBgXml: doc.headerBgXml,
      headerBgRelsXml: doc.headerBgRelsXml,
    );
  }

  Future<DocxNode> _translateNode(DocxNode node, String targetLang) async {
    if (node is DocxParagraph) {
      final children = <DocxInline>[];
      for (var child in node.children) {
        children.add(await _translateInline(child, targetLang));
      }
      return node.copyWith(children: children);
    } else if (node is DocxTable) {
      final rows = <DocxTableRow>[];
      for (var row in node.rows) {
        final cells = <DocxTableCell>[];
        for (var cell in row.cells) {
          final cellChildren = <DocxBlock>[];
          for (var child in cell.children) {
            // Recursively translate blocks inside cells
            cellChildren.add(
              await _translateNode(child, targetLang) as DocxBlock,
            );
          }
          cells.add(
            DocxTableCell(
              children: cellChildren,
              colSpan: cell.colSpan,
              rowSpan: cell.rowSpan,
              verticalAlign: cell.verticalAlign,
              shadingFill: cell.shadingFill,
              width: cell.width,
            ),
          );
        }
        rows.add(DocxTableRow(cells: cells, height: row.height));
      }
      return DocxTable(
        rows: rows,
        style: node.style,
        width: node.width,
        widthType: node.widthType,
        hasHeader: node.hasHeader,
      );
    } else if (node is DocxList) {
      final items = <DocxListItem>[];
      for (var item in node.items) {
        final inlines = <DocxInline>[];
        for (var child in item.children) {
          inlines.add(await _translateInline(child, targetLang));
        }
        items.add(DocxListItem(inlines, level: item.level));
      }
      final translatedList =
          DocxList(items: items, isOrdered: node.isOrdered, style: node.style);
      translatedList.numId = node.numId;
      return translatedList;
    }

    // Return other nodes as-is (Images, etc.)
    return node;
  }

  Future<DocxInline> _translateInline(
      DocxInline node, String targetLang) async {
    if (node is DocxText) {
      // Translate the content of text nodes
      final translatedText = await _service.translate(node.content, targetLang);
      return node.copyWith(content: translatedText);
    }
    // Return other inlines as-is (LineBreaks, Tabs, InlineImages)
    return node;
  }
}
