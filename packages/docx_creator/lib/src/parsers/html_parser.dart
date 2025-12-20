import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../ast/docx_block.dart';
import '../ast/docx_inline.dart';
import '../ast/docx_list.dart';
import '../ast/docx_node.dart';
import '../ast/docx_table.dart';
import '../core/enums.dart';
import '../core/exceptions.dart';
import 'markdown_parser.dart';

/// Parses HTML and Markdown content into [DocxNode] elements.
///
/// ## HTML Parsing
/// ```dart
/// final elements = DocxParser.fromHtml('<h1>Title</h1><p>Content</p>');
/// ```
///
/// ## Markdown Parsing
/// ```dart
/// final elements = DocxParser.fromMarkdown('# Title\nContent');
/// ```
class DocxParser {
  DocxParser._();

  /// Parses HTML string into DocxNode elements.
  static List<DocxNode> fromHtml(String html) {
    try {
      final document = html_parser.parse(html);
      final body = document.body;
      if (body == null) return [];
      return _parseChildren(body.nodes);
    } catch (e) {
      throw DocxParserException(
        'Failed to parse HTML: $e',
        sourceFormat: 'HTML',
      );
    }
  }

  /// Parses Markdown string into DocxNode elements.
  static List<DocxNode> fromMarkdown(String markdown) {
    try {
      return MarkdownParser.parse(markdown);
    } catch (e) {
      throw DocxParserException(
        'Failed to parse Markdown: $e',
        sourceFormat: 'Markdown',
      );
    }
  }

  static List<DocxNode> _parseChildren(List<dom.Node> nodes) {
    final results = <DocxNode>[];
    for (var node in nodes) {
      final parsed = _parseNode(node);
      if (parsed != null) results.add(parsed);
    }
    return results;
  }

  static DocxNode? _parseNode(dom.Node node) {
    if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return null;
      return DocxParagraph(children: [DocxText(text)]);
    }
    if (node is dom.Element) return _parseElement(node);
    return null;
  }

  static DocxNode? _parseElement(dom.Element element) {
    final tag = element.localName?.toLowerCase();
    if (tag == null) return null;

    switch (tag) {
      // Headings
      case 'h1':
        return DocxParagraph.heading1(_getText(element));
      case 'h2':
        return DocxParagraph.heading2(_getText(element));
      case 'h3':
        return DocxParagraph.heading3(_getText(element));
      case 'h4':
        return DocxParagraph.heading4(_getText(element));
      case 'h5':
        return DocxParagraph.heading5(_getText(element));
      case 'h6':
        return DocxParagraph.heading6(_getText(element));

      // Paragraph
      case 'p':
      case 'div':
        final inlines = _parseInlines(element.nodes);
        if (inlines.isEmpty) return null;
        return DocxParagraph(children: inlines);

      // Lists
      case 'ul':
        return _parseList(element, ordered: false);
      case 'ol':
        return _parseList(element, ordered: true);

      // Blockquote
      case 'blockquote':
        return DocxParagraph.quote(_getText(element));

      // Code block
      case 'pre':
        return DocxParagraph.code(_getText(element));

      // Table
      case 'table':
        return _parseTable(element);

      // Horizontal rule
      case 'hr':
        return DocxParagraph(borderBottom: DocxBorder.single, children: []);

      default:
        final inlines = _parseInlines(element.nodes);
        if (inlines.isEmpty) return null;
        return DocxParagraph(children: inlines);
    }
  }

  static List<DocxInline> _parseInlines(List<dom.Node> nodes) {
    final results = <DocxInline>[];
    for (var node in nodes) {
      results.addAll(_parseInline(node));
    }
    return results;
  }

  static List<DocxInline> _parseInline(dom.Node node) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.isEmpty) return [];
      return [DocxText(text)];
    }

    if (node is dom.Element) {
      final tag = node.localName?.toLowerCase();
      if (tag == null) return [];
      final text = _getText(node);
      final style = node.attributes['style'] ?? '';

      switch (tag) {
        case 'strong':
        case 'b':
          return [DocxText.bold(text)];
        case 'em':
        case 'i':
          return [DocxText.italic(text)];
        case 'u':
          return [DocxText.underline(text)];
        case 's':
        case 'del':
        case 'strike':
          return [DocxText.strike(text)];
        case 'a':
          final href = node.attributes['href'];
          return [DocxText.link(text, href: href ?? '#')];
        case 'code':
          return [DocxText.code(text)];
        case 'br':
          return [DocxLineBreak()];
        case 'sup':
          return [DocxText.superscript(text)];
        case 'sub':
          return [DocxText.subscript(text)];
        case 'mark':
          return [DocxText.highlighted(text)];
        case 'span':
          // Parse inline styles
          return [_parseStyledText(text, style)];
        default:
          return _parseInlines(node.nodes);
      }
    }
    return [];
  }

  static DocxText _parseStyledText(String text, String style) {
    bool isBold = style.contains('font-weight') &&
        (style.contains('bold') || style.contains('700'));
    bool isItalic = style.contains('font-style') && style.contains('italic');
    String? colorHex;
    double? fontSize;

    // Parse color
    final colorMatch = RegExp(r'color:\s*#([A-Fa-f0-9]{6})').firstMatch(style);
    if (colorMatch != null) colorHex = colorMatch.group(1);

    // Parse font-size
    final sizeMatch = RegExp(r'font-size:\s*(\d+)').firstMatch(style);
    if (sizeMatch != null) fontSize = double.tryParse(sizeMatch.group(1)!);

    return DocxText(
      text,
      fontWeight: isBold ? DocxFontWeight.bold : DocxFontWeight.normal,
      fontStyle: isItalic ? DocxFontStyle.italic : DocxFontStyle.normal,
      color: colorHex != null ? DocxColor(colorHex) : DocxColor.black,
      fontSize: fontSize,
    );
  }

  static DocxList _parseList(dom.Element element, {required bool ordered}) {
    final items = <DocxListItem>[];

    for (var child in element.children) {
      if (child.localName == 'li') {
        final text = _getText(child);
        if (text.isNotEmpty) {
          items.add(DocxListItem([DocxText(text)]));
        }
      }
    }

    return DocxList(items: items, isOrdered: ordered);
  }

  static DocxTable _parseTable(dom.Element element) {
    final rows = <DocxTableRow>[];
    final trElements = element.querySelectorAll('tr');

    for (var tr in trElements) {
      final cells = <DocxTableCell>[];
      final isHeader = tr.querySelectorAll('th').isNotEmpty;
      final tds = tr.querySelectorAll('td, th');

      for (var td in tds) {
        cells.add(
          DocxTableCell.text(
            _getText(td),
            isBold: isHeader,
            shadingFill: isHeader ? 'E0E0E0' : null,
          ),
        );
      }

      if (cells.isNotEmpty) rows.add(DocxTableRow(cells: cells));
    }

    return DocxTable(rows: rows, style: DocxTableStyle.headerHighlight);
  }

  static String _getText(dom.Node node) {
    if (node is dom.Text) return node.text;
    if (node is dom.Element) return node.text;
    return '';
  }
}
