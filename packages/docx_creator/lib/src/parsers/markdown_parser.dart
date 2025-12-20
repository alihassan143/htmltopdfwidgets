import 'package:markdown/markdown.dart' as md;

import '../ast/docx_block.dart';
import '../ast/docx_inline.dart';
import '../ast/docx_list.dart';
import '../ast/docx_node.dart';
import '../ast/docx_table.dart';
import '../core/enums.dart';

/// Parses Markdown content into [DocxNode] elements.
///
/// ## Usage
/// ```dart
/// final elements = DocxParser.fromMarkdown('''
/// # Heading 1
/// This is **bold** and *italic*.
///
/// - Item 1
/// - Item 2
///
/// | A | B |
/// |---|---|
/// | 1 | 2 |
/// ''');
/// ```
class MarkdownParser {
  MarkdownParser._();

  /// Parses Markdown string into DocxNode elements.
  static List<DocxNode> parse(String markdown) {
    final document = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored);
    final nodes = document.parseLines(markdown.split('\n'));
    return _parseNodes(nodes);
  }

  static List<DocxNode> _parseNodes(List<md.Node> nodes) {
    final results = <DocxNode>[];
    for (var node in nodes) {
      final parsed = _parseNode(node);
      if (parsed != null) results.add(parsed);
    }
    return results;
  }

  static DocxNode? _parseNode(md.Node node) {
    if (node is md.Element) {
      return _parseElement(node);
    } else if (node is md.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return null;
      return DocxParagraph(children: [DocxText(text)]);
    }
    return null;
  }

  static DocxNode? _parseElement(md.Element element) {
    switch (element.tag) {
      // Headings
      case 'h1':
        return DocxParagraph.heading1(_extractText(element));
      case 'h2':
        return DocxParagraph.heading2(_extractText(element));
      case 'h3':
        return DocxParagraph.heading3(_extractText(element));
      case 'h4':
        return DocxParagraph.heading4(_extractText(element));
      case 'h5':
        return DocxParagraph.heading5(_extractText(element));
      case 'h6':
        return DocxParagraph.heading6(_extractText(element));

      // Paragraph
      case 'p':
        final inlines = _parseInlines(element.children ?? []);
        if (inlines.isEmpty) return null;
        return DocxParagraph(children: inlines);

      // Lists
      case 'ul':
        return _parseList(element, ordered: false);
      case 'ol':
        return _parseList(element, ordered: true);

      // Blockquote
      case 'blockquote':
        return DocxParagraph.quote(_extractText(element));

      // Code block
      case 'pre':
        return DocxParagraph.code(_extractText(element));

      // Table
      case 'table':
        return _parseTable(element);

      // Horizontal rule
      case 'hr':
        return DocxParagraph(borderBottom: DocxBorder.single, children: []);

      default:
        // Try as paragraph
        final inlines = _parseInlines(element.children ?? []);
        if (inlines.isEmpty) return null;
        return DocxParagraph(children: inlines);
    }
  }

  static List<DocxInline> _parseInlines(List<md.Node> nodes) {
    final results = <DocxInline>[];
    for (var node in nodes) {
      results.addAll(_parseInline(node));
    }
    return results;
  }

  static List<DocxInline> _parseInline(md.Node node) {
    if (node is md.Text) {
      return [DocxText(node.text)];
    }

    if (node is md.Element) {
      final text = _extractText(node);

      switch (node.tag) {
        case 'strong':
        case 'b':
          return [DocxText.bold(text)];
        case 'em':
        case 'i':
          return [DocxText.italic(text)];
        case 'del':
        case 's':
          return [DocxText.strike(text)];
        case 'code':
          return [DocxText.code(text)];
        case 'a':
          final href = node.attributes['href'] ?? '#';
          return [DocxText.link(text, href: href)];
        case 'br':
          return [DocxLineBreak()];
        case 'sup':
          return [DocxText.superscript(text)];
        case 'sub':
          return [DocxText.subscript(text)];
        default:
          // Recursively parse children
          return _parseInlines(node.children ?? []);
      }
    }

    return [];
  }

  static DocxList _parseList(md.Element element, {required bool ordered}) {
    final items = <DocxListItem>[];

    for (var child in element.children ?? []) {
      if (child is md.Element && child.tag == 'li') {
        final inlines = _parseInlines(child.children ?? []);
        if (inlines.isNotEmpty) {
          items.add(DocxListItem(inlines));
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
            _extractText(child),
            isBold: isHeader,
            shadingFill: isHeader ? 'E0E0E0' : null,
          ),
        );
      }
    }

    return DocxTableRow(cells: cells);
  }

  static String _extractText(md.Node node) {
    if (node is md.Text) return node.text;
    if (node is md.Element) {
      return (node.children ?? []).map(_extractText).join();
    }
    return '';
  }
}
