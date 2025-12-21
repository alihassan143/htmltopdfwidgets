import 'package:markdown/markdown.dart' as md;

import '../../docx_creator.dart';
import '../utils/document_builder.dart';
import '../utils/image_resolver.dart';

/// Parses Markdown content into [DocxNode] elements.
class MarkdownParser {
  MarkdownParser._();

  /// Parses Markdown string into DocxNode elements.
  static Future<List<DocxNode>> parse(String markdown) async {
    // Enable GFM (tables, strikethrough, autolinks, task lists)
    final document = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored);
    final nodes = document.parseLines(markdown.split('\n'));
    return _parseNodes(nodes);
  }

  static Future<List<DocxNode>> _parseNodes(List<md.Node> nodes) async {
    final results = <DocxNode>[];
    for (var node in nodes) {
      final parsed = await _parseNode(node);
      if (parsed != null) results.add(parsed);
    }
    return results;
  }

  static Future<DocxNode?> _parseNode(md.Node node) async {
    if (node is md.Element) {
      return _parseElement(node);
    } else if (node is md.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return null;
      return DocumentBuilder.buildBlockElement(
        tag: 'p',
        children: [DocxText(text)],
      );
    }
    return null;
  }

  static Future<DocxNode?> _parseElement(md.Element element) async {
    final tag = element.tag;
    final inlines = await _parseInlines(element.children ?? []);

    // 1. Try Shared Builder
    final built = DocumentBuilder.buildBlockElement(
      tag: tag,
      children: inlines, // Pass parsed inlines!
      textContent: await _extractText(element),
    );

    // If built is a heading/quote/pre/hr, return it.
    if (built != null && !['p', 'div'].contains(tag)) {
      return built;
    }

    switch (tag) {
      // Paragraph
      case 'p':
        if (inlines.isEmpty) return null;
        return DocumentBuilder.buildBlockElement(tag: 'p', children: inlines);

      // Lists
      case 'ul':
        return _parseList(element, ordered: false);
      case 'ol':
        return _parseList(element, ordered: true);

      // Table
      case 'table':
        return _parseTable(element);

      // Explicit handling if DocumentBuilder didn't catch or we need specific logic
      default:
        // Fallback
        if (inlines.isNotEmpty) {
          return DocumentBuilder.buildBlockElement(tag: 'p', children: inlines);
        }
        return null;
    }
  }

  static Future<List<DocxInline>> _parseInlines(List<md.Node> nodes) async {
    final results = <DocxInline>[];
    for (var node in nodes) {
      results.addAll(await _parseInline(node));
    }
    return results;
  }

  static Future<List<DocxInline>> _parseInline(md.Node node) async {
    if (node is md.Text) {
      return [DocxText(node.text)];
    }

    if (node is md.Element) {
      final text = await _extractText(node);

      switch (node.tag) {
        case 'strong':
        case 'b':
          return [DocxText.bold(text)];
        case 'em':
        case 'i':
          return [DocxText.italic(text)];
        case 'del':
        case 's':
        case 'strike':
          return [DocxText.strike(text)];
        case 'code':
          return [DocxText.code(text)];
        case 'a':
          final href = node.attributes['href'] ?? '#';
          return [DocxText.link(text, href: href)];
        case 'br':
          return [DocxLineBreak()];
        case 'img':
          // Async Image Resolution
          final src = node.attributes['src'] ?? '';
          final alt = node.attributes['alt'] ?? text;
          final result = await ImageResolver.resolve(src, alt: alt);

          if (result != null) {
            return [
              DocxInlineImage(
                bytes: result.bytes,
                extension: result.extension,
                width: result.width,
                height: result.height,
                altText: result.altText,
              )
            ];
          }
          // Fallback
          return [
            DocxText('[📷 '),
            DocxText.link(alt.isEmpty ? 'Image' : alt, href: src),
            DocxText(']'),
          ];

        case 'input':
          // GFM task list checkbox
          if (node.attributes['type'] == 'checkbox') {
            final isChecked = node.attributes.containsKey('checked');
            return [DocumentBuilder.buildCheckbox(isChecked: isChecked)];
          }
          return [];

        default:
          return _parseInlines(node.children ?? []);
      }
    }

    return [];
  }

  static Future<DocxList> _parseList(
    md.Element element, {
    required bool ordered,
    int level = 0,
  }) async {
    final items = <DocxListItem>[];

    for (var child in element.children ?? []) {
      if (child is md.Element && child.tag == 'li') {
        final inlines = <DocxInline>[];
        final nestedLists = <DocxList>[];

        // Process children of LI
        for (var node in child.children ?? []) {
          if (node is md.Element && (node.tag == 'ul' || node.tag == 'ol')) {
            // Found nested list
            nestedLists.add(await _parseList(node,
                ordered: node.tag == 'ol', level: level + 1));
          } else {
            // Regular inline content
            inlines.addAll(await _parseInline(node));
          }
        }

        if (inlines.isNotEmpty) {
          items.add(DocxListItem(inlines, level: level));
        }

        // Flatten nested items
        for (var nested in nestedLists) {
          items.addAll(nested.items);
        }
      }
    }

    return DocxList(items: items, isOrdered: ordered);
  }

  static DocxTable _parseTable(md.Element element) {
    final rows = <DocxTableRow>[];

    // Find thead and tbody
    for (var child in element.children ?? []) {
      if (child is md.Element) {
        if (child.tag == 'thead' || child.tag == 'tbody') {
          for (var tr in child.children ?? []) {
            if (tr is md.Element && tr.tag == 'tr') {
              rows.add(_parseTableRow(tr, isHeader: child.tag == 'thead'));
            }
          }
        } else if (child.tag == 'tr') {
          rows.add(_parseTableRow(child, isHeader: false));
        }
      }
    }

    return DocxTable(rows: rows, style: DocxTableStyle.headerHighlight);
  }

  static DocxTableRow _parseTableRow(md.Element tr, {required bool isHeader}) {
    final cells = <DocxTableCell>[];

    for (var child in tr.children ?? []) {
      if (child is md.Element && (child.tag == 'td' || child.tag == 'th')) {
        cells.add(
          DocxTableCell.text(
            _extractTextSync(child), // Table cells textual for now
            isBold: isHeader,
            shadingFill: isHeader ? 'E0E0E0' : null,
          ),
        );
      }
    }

    return DocxTableRow(cells: cells);
  }

  static Future<String> _extractText(md.Node node) async {
    if (node is md.Text) return node.text;
    if (node is md.Element) {
      final buffer = StringBuffer();
      for (var child in node.children ?? []) {
        buffer.write(await _extractText(child));
      }
      return buffer.toString();
    }
    return '';
  }

  static String _extractTextSync(md.Node node) {
    if (node is md.Text) return node.text;
    if (node is md.Element) {
      return (node.children ?? []).map(_extractTextSync).join();
    }
    return '';
  }
}
