import 'package:docx_creator/docx_creator.dart';
import 'package:html/dom.dart' as dom;

import 'inline_parser.dart';
import 'parser_context.dart';

/// Parses HTML list elements (ul, ol).
class HtmlListParser {
  final HtmlParserContext context;
  final HtmlInlineParser inlineParser;

  HtmlListParser(this.context, this.inlineParser);

  /// Parse a list element (ul or ol).
  Future<DocxList> parseList(
    dom.Element element, {
    required bool ordered,
    int level = 0,
  }) async {
    final items = <DocxListItem>[];

    for (var child in element.children) {
      if (child.localName == 'li') {
        final inlines = <DocxInline>[];
        final nestedLists = <DocxList>[];

        for (var node in child.nodes) {
          if (node is dom.Element) {
            if (node.localName == 'ul') {
              nestedLists
                  .add(await parseList(node, ordered: false, level: level + 1));
              continue;
            } else if (node.localName == 'ol') {
              nestedLists
                  .add(await parseList(node, ordered: true, level: level + 1));
              continue;
            }
          }
          inlines.addAll(inlineParser.parseInline(node));
        }

        // Add current item
        if (inlines.isNotEmpty) {
          items.add(DocxListItem(inlines, level: level));
        }

        // Flatten nested items into this list
        for (var nested in nestedLists) {
          items.addAll(nested.items);
        }
      }
    }

    return DocxList(items: items, isOrdered: ordered);
  }
}
