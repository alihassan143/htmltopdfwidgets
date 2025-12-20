import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../ast/docx_block.dart';
import '../ast/docx_image.dart';
import '../ast/docx_inline.dart';
import '../ast/docx_list.dart';
import '../ast/docx_node.dart';
import '../ast/docx_table.dart';
import '../core/enums.dart';
import '../core/exceptions.dart';
import '../utils/document_builder.dart';
import '../utils/image_resolver.dart';
import 'markdown_parser.dart';

/// Parses HTML content into [DocxNode] elements.
///
/// ## HTML Parsing
/// ```dart
/// final elements = await DocxParser.fromHtml('<img src="https://..." />');
/// ```
class DocxParser {
  DocxParser._();

  /// Parses HTML string into DocxNode elements with async image fetching.
  ///
  /// This method properly handles:
  /// - Remote images (http/https URLs): fetched via HTTP
  /// - Base64/data URI images: decoded from inline data
  /// - Local images (if file path access allows)
  /// - Checkboxes (<input type="checkbox">)
  static Future<List<DocxNode>> fromHtml(String html) async {
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
  static Future<List<DocxNode>> fromMarkdown(String markdown) async {
    try {
      return await MarkdownParser.parse(markdown);
    } catch (e) {
      throw DocxParserException(
        'Failed to parse Markdown: $e',
        sourceFormat: 'Markdown',
      );
    }
  }

  // ============================================================
  // PARSING LOGIC
  // ============================================================

  static Future<List<DocxNode>> _parseChildren(List<dom.Node> nodes) async {
    final results = <DocxNode>[];
    for (var node in nodes) {
      final parsed = await _parseNode(node);
      if (parsed != null) results.add(parsed);
    }
    return results;
  }

  static Future<DocxNode?> _parseNode(dom.Node node) async {
    if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return null;
      return DocumentBuilder.buildBlockElement(
        tag: 'p',
        children: [DocxText(text)],
      );
    }
    if (node is dom.Element) return _parseElement(node);
    return null;
  }

  static Future<DocxNode?> _parseElement(dom.Element element) async {
    final tag = element.localName?.toLowerCase();
    if (tag == null) return null;

    // 1. Try Shared Builder for standard blocks
    final children = await _parseInlines(element.nodes);
    final built = DocumentBuilder.buildBlockElement(
      tag: tag,
      children: [], // Pass empty, we'll manually handle children if needed or pass them
      textContent: _getText(element),
    );

    if (built != null &&
        tag != 'p' &&
        tag != 'div' &&
        tag != 'pre' &&
        !tag.startsWith('h')) {
      // For headings, quotes, etc where text content is enough (as per current impl)
      // or simplistic mapping.
      // However, DocumentBuilder logic for headings takes text string.
      // If we want rich text headings, we might need to adjust DocumentBuilder or DocxParser.
      // Current DocxParagraph.headingX takes String.
      return built;
    }

    // Extract block styles early for override
    final blockStyles = _parseBlockStyles(element.attributes['style'] ?? '');

    switch (tag) {
      case 'p':
      case 'div':
        if (children.isEmpty) return null;

        // Propagate text color to children if present
        var finalChildren = children;
        if (blockStyles.colorHex != null) {
          finalChildren = children.map((child) {
            if (child is DocxText) {
              if (child.color == DocxColor.black || child.color == null) {
                return child.copyWith(color: DocxColor(blockStyles.colorHex!));
              }
            } else if (child is DocxCheckbox) {
              if (child.color == null) {
                return DocxCheckbox(
                  isChecked: child.isChecked,
                  fontSize: child.fontSize,
                  fontWeight: child.fontWeight,
                  fontStyle: child.fontStyle,
                  color: DocxColor(blockStyles.colorHex!),
                  id: child.id,
                );
              }
            }
            return child;
          }).toList();
        }

        return DocxParagraph(
          children: finalChildren,
          shadingFill: blockStyles.shadingFill,
          align: blockStyles.align,
        );

      case 'ul':
        return _parseList(element, ordered: false);
      case 'ol':
        return _parseList(element, ordered: true);

      case 'table':
        return _parseTable(element);

      case 'img':
        return _parseImage(element);

      case 'pre':
        // Handle code blocks: preserve newlines
        final text = _getText(element);
        final lines = text.split('\n');
        final codeChildren = <DocxInline>[];

        for (var i = 0; i < lines.length; i++) {
          codeChildren.add(DocxText.code(lines[i]));
          if (i < lines.length - 1) {
            codeChildren.add(DocxLineBreak());
          }
        }

        return DocxParagraph(
          shadingFill: 'F5F5F5',
          children: codeChildren,
          align: blockStyles.align,
        );

      case 'code':
        // Handle top-level code blocks (similar to pre)
        final text = _getText(element);
        final lines = text.split('\n');
        final codeChildren = <DocxInline>[];

        for (var i = 0; i < lines.length; i++) {
          codeChildren.add(DocxText.code(lines[i]));
          if (i < lines.length - 1) {
            codeChildren.add(DocxLineBreak());
          }
        }

        return DocxParagraph(
          shadingFill: 'F5F5F5',
          children: codeChildren,
          align: blockStyles.align,
        );

      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
      case 'blockquote':
      case 'hr':
        // DocumentBuilder handles basic creation, but we override styles here
        if (built is DocxParagraph) {
          return built.copyWith(
            shadingFill: blockStyles.shadingFill ?? built.shadingFill,
            align: blockStyles.align,
          );
        }
        return built;

      default:
        // Fallback for unknown tags - treat as paragraph
        if (children.isEmpty) return null;
        return DocxParagraph(
          children: children,
          shadingFill: blockStyles.shadingFill,
          align: blockStyles.align,
        );
    }
  }

  static Future<List<DocxInline>> _parseInlines(List<dom.Node> nodes) async {
    final results = <DocxInline>[];
    for (var node in nodes) {
      if (node is dom.Element && node.localName?.toLowerCase() == 'img') {
        final img = await _parseInlineImage(node);
        if (img != null) results.add(img);
      } else {
        results.addAll(_parseInline(node));
      }
    }
    return results;
  }

  static List<DocxInline> _parseInline(dom.Node node) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.isEmpty) return [];

      // Check for [ ] and [x] patterns at the start of text
      if (text.startsWith('[ ] ')) {
        return [
          DocumentBuilder.buildCheckbox(isChecked: false),
          DocxText(text.substring(4))
        ];
      } else if (text.startsWith('[x] ') || text.startsWith('[X] ')) {
        return [
          DocumentBuilder.buildCheckbox(isChecked: true),
          DocxText(text.substring(4))
        ];
      }

      return [DocxText(text)];
    }

    if (node is dom.Element) {
      final tag = node.localName?.toLowerCase();
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
          final lines = text.split('\n');
          final results = <DocxInline>[];
          for (var i = 0; i < lines.length; i++) {
            results.add(DocxText.code(lines[i]));
            if (i < lines.length - 1) {
              results.add(DocxLineBreak());
            }
          }
          return results;
        case 'br':
          return [DocxLineBreak()];
        case 'sup':
          return [DocxText.superscript(text)];
        case 'sub':
          return [DocxText.subscript(text)];
        case 'mark':
          return [DocxText.highlighted(text)];
        case 'span':
          return [_parseStyledText(text, style)];
        case 'input':
          final type = node.attributes['type']?.toLowerCase();
          if (type == 'checkbox') {
            final styles = _parseStyledText('', node.attributes['style'] ?? '');
            return [
              DocumentBuilder.buildCheckbox(
                isChecked: node.attributes.containsKey('checked'),
                fontSize: styles.fontSize,
                fontWeight: styles.fontWeight,
                fontStyle: styles.fontStyle,
                color: styles.color,
              )
            ];
          }
          return [];
        case 'label':
          // Pass style to children if label has it?
          // For now, recursively parse nodes
          return _parseInlinesSync(node.nodes);
        default:
          return _parseInlinesSync(node.nodes);
      }
    }
    return [];
  }

  // Helper for recursive synchronous inline parsing
  static List<DocxInline> _parseInlinesSync(List<dom.Node> nodes) {
    final results = <DocxInline>[];
    for (var node in nodes) {
      results.addAll(_parseInline(node));
    }
    return results;
  }

  static DocxText _parseStyledText(String text, String style) {
    bool isBold = style.contains('font-weight') &&
        (style.contains('bold') || style.contains('700'));
    bool isItalic = style.contains('font-style') && style.contains('italic');
    String? colorHex;
    double? fontSize;

    // Matches #RGB, #RRGGBB, or names (quoted or unquoted)
    // Using standard string regex to ensure proper escaping of quotes
    final colorMatch =
        RegExp("color:\\s*['\"]?(#[A-Fa-f0-9]{3,6}|[a-zA-Z]+)['\"]?")
            .firstMatch(style);

    if (colorMatch != null) {
      final val = colorMatch.group(1);
      if (val != null) colorHex = _parseColor(val);
    }

    final sizeMatch = RegExp(r"font-size:\s*(\d+)").firstMatch(style);
    if (sizeMatch != null) fontSize = double.tryParse(sizeMatch.group(1)!);

    // Highlight support (background-color)
    DocxHighlight highlight = DocxHighlight.none;
    final bgMatch =
        RegExp("background-color:\\s*['\"]?(#[A-Fa-f0-9]{3,6}|[a-zA-Z]+)['\"]?")
            .firstMatch(style);

    if (bgMatch != null) {
      final bgVal = bgMatch.group(1)?.toLowerCase();
      if (bgVal != null) {
        highlight = _mapColorToHighlight(bgVal);
      }
    }

    return DocxText(
      text,
      fontWeight: isBold ? DocxFontWeight.bold : DocxFontWeight.normal,
      fontStyle: isItalic ? DocxFontStyle.italic : DocxFontStyle.normal,
      color: colorHex != null ? DocxColor(colorHex) : DocxColor.black,
      fontSize: fontSize,
      highlight: highlight,
    );
  }

  static DocxHighlight _mapColorToHighlight(String color) {
    var c = color.toLowerCase();

    // Standardize hex
    if (c.startsWith('#') && c.length == 4) {
      c = '#${c[1]}${c[1]}${c[2]}${c[2]}${c[3]}${c[3]}';
    }

    if (c.startsWith('#')) {
      if (c == '#ffff00') return DocxHighlight.yellow;
      if (c == '#00ff00') return DocxHighlight.green;
      if (c == '#00ffff') return DocxHighlight.cyan;
      if (c == '#ff00ff') return DocxHighlight.magenta;
      if (c == '#0000ff') return DocxHighlight.blue;
      if (c == '#ff0000') return DocxHighlight.red;
      if (c == '#000080') return DocxHighlight.darkBlue;
      if (c == '#008080') return DocxHighlight.darkCyan;
      if (c == '#008000') return DocxHighlight.darkGreen;
      if (c == '#800080') return DocxHighlight.darkMagenta;
      if (c == '#800000') return DocxHighlight.darkRed;
      if (c == '#808000') return DocxHighlight.darkYellow;
      if (c == '#808080') return DocxHighlight.darkGray;
      if (c == '#c0c0c0' || c == '#d3d3d3') return DocxHighlight.lightGray;
      if (c == '#000000') return DocxHighlight.black;
      return DocxHighlight.none;
    }

    // Named colors
    switch (c) {
      case 'yellow':
        return DocxHighlight.yellow;
      case 'green':
        return DocxHighlight.green;
      case 'cyan':
        return DocxHighlight.cyan;
      case 'magenta':
        return DocxHighlight.magenta;
      case 'blue':
        return DocxHighlight.blue;
      case 'red':
        return DocxHighlight.red;
      case 'darkblue':
        return DocxHighlight.darkBlue;
      case 'darkcyan':
        return DocxHighlight.darkCyan;
      case 'darkgreen':
        return DocxHighlight.darkGreen;
      case 'darkmagenta':
        return DocxHighlight.darkMagenta;
      case 'darkred':
        return DocxHighlight.darkRed;
      case 'darkyellow':
        return DocxHighlight.darkYellow;
      case 'darkgray':
      case 'darkgrey':
        return DocxHighlight.darkGray;
      case 'lightgray':
      case 'lightgrey':
        return DocxHighlight.lightGray;
      case 'black':
        return DocxHighlight.black;
      default:
        return DocxHighlight.none;
    }
  }

  static _BlockStyles _parseBlockStyles(String style) {
    String? shadingFill;
    DocxAlign align = DocxAlign.left;

    final bgMatch =
        RegExp(r'background-color:\s*#?([A-Fa-f0-9]{6})').firstMatch(style);
    if (bgMatch != null) {
      shadingFill = bgMatch.group(1);
    }

    if (style.contains('text-align: center')) {
      align = DocxAlign.center;
    } else if (style.contains('text-align: right')) {
      align = DocxAlign.right;
    } else if (style.contains('text-align: justify')) {
      align = DocxAlign.justify;
    }

    String? colorHex;
    final colorMatch = RegExp(r'color:\s*#([A-Fa-f0-9]{6})').firstMatch(style);
    if (colorMatch != null) colorHex = colorMatch.group(1);

    return _BlockStyles(
        shadingFill: shadingFill, align: align, colorHex: colorHex);
  }

  static Future<DocxList> _parseList(
    dom.Element element, {
    required bool ordered,
    int level = 0,
  }) async {
    final items = <DocxListItem>[];

    for (var child in element.children) {
      if (child.localName == 'li') {
        // Collect inlines for this item
        final inlines = <DocxInline>[];
        final nestedLists = <DocxList>[];

        for (var node in child.nodes) {
          if (node is dom.Element) {
            if (node.localName == 'ul') {
              nestedLists.add(
                  await _parseList(node, ordered: false, level: level + 1));
              continue;
            } else if (node.localName == 'ol') {
              nestedLists
                  .add(await _parseList(node, ordered: true, level: level + 1));
              continue;
            }
          }
          // Use async inline parser
          inlines.addAll(_parseInline(node));
        }

        // Add current item
        if (inlines.isNotEmpty) {
          items.add(DocxListItem(inlines, level: level));
        } else if (nestedLists.isNotEmpty) {
          // Empty item (e.g. <li><ul>...</ul></li>) - add placeholder or attach to previous?
          // Word prefers text in list item.
          // We will just add empty item if there are nested lists.
          if (items.isEmpty && level == 0) {
            // Rare case: only nested list.
          }
        }

        // Flatten nested items into this list
        for (var nested in nestedLists) {
          items.addAll(nested.items);
        }
      }
    }

    return DocxList(items: items, isOrdered: ordered);
  }

  static Future<DocxTable> _parseTable(dom.Element element) async {
    final rows = <DocxTableRow>[];

    for (var child in element.children) {
      final childTag = child.localName?.toLowerCase();

      if (childTag == 'tbody' || childTag == 'thead' || childTag == 'tfoot') {
        for (var tr in child.children) {
          if (tr.localName?.toLowerCase() == 'tr') {
            final row = await _parseTableRow(tr);
            if (row != null) rows.add(row);
          }
        }
      } else if (childTag == 'tr') {
        final row = await _parseTableRow(child);
        if (row != null) rows.add(row);
      }
    }

    return DocxTable(rows: rows, style: DocxTableStyle.headerHighlight);
  }

  static Future<DocxTableRow?> _parseTableRow(dom.Element tr) async {
    final cells = <DocxTableCell>[];

    for (var child in tr.children) {
      final tag = child.localName?.toLowerCase();
      if (tag == 'td' || tag == 'th') {
        final cell = await _parseTableCell(child, isHeader: tag == 'th');
        cells.add(cell);
      }
    }

    if (cells.isEmpty) return null;
    return DocxTableRow(cells: cells);
  }

  static Future<DocxTableCell> _parseTableCell(dom.Element td,
      {bool isHeader = false}) async {
    final style = td.attributes['style'] ?? '';
    String? shadingFill;

    final bgMatch =
        RegExp(r'background-color:\s*#([A-Fa-f0-9]{6})').firstMatch(style);
    if (bgMatch != null) {
      shadingFill = bgMatch.group(1);
    } else if (isHeader) {
      shadingFill = 'E0E0E0';
    }

    final colSpan = int.tryParse(td.attributes['colspan'] ?? '1') ?? 1;
    final rowSpan = int.tryParse(td.attributes['rowspan'] ?? '1') ?? 1;

    final content = await _parseCellContent(td.nodes, isHeader: isHeader);

    return DocxTableCell(
      children: content,
      colSpan: colSpan,
      rowSpan: rowSpan,
      shadingFill: shadingFill,
    );
  }

  static Future<List<DocxBlock>> _parseCellContent(
    List<dom.Node> nodes, {
    bool isHeader = false,
  }) async {
    final blocks = <DocxBlock>[];
    final inlines = <DocxInline>[];

    void flushInlines() {
      if (inlines.isNotEmpty) {
        blocks.add(DocxParagraph(children: List.from(inlines)));
        inlines.clear();
      }
    }

    for (var node in nodes) {
      if (node is dom.Text) {
        final text = node.text.trim();
        if (text.isNotEmpty) {
          inlines.add(isHeader ? DocxText.bold(text) : DocxText(text));
        }
      } else if (node is dom.Element) {
        final tag = node.localName?.toLowerCase();

        if (_isBlockTag(tag)) {
          flushInlines();
          // Recursive async parse for nested blocks
          final block = await _parseElement(node);
          if (block is DocxBlock) {
            blocks.add(block);
          }
        } else {
          inlines.addAll(_parseInline(node));
        }
      }
    }

    flushInlines();

    if (blocks.isEmpty) {
      blocks.add(DocxParagraph(children: []));
    }

    return blocks;
  }

  static bool _isBlockTag(String? tag) {
    if (tag == null) return false;
    return [
      'p',
      'div',
      'table',
      // 'ul', 'ol', // Handled specially now? No, kept as block tags for _parseElement dispatch
      'ul',
      'ol',
      'blockquote',
      'pre',
      'hr',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'img'
    ].contains(tag);
  }

  static String _getText(dom.Node node) {
    if (node is dom.Text) return node.text;
    if (node is dom.Element) return node.text;
    return '';
  }

  // IMAGE HANDLING

  static Future<DocxNode?> _parseImage(dom.Element element) async {
    final src = element.attributes['src'];
    final alt = element.attributes['alt'];
    final widthStr = element.attributes['width'];
    final heightStr = element.attributes['height'];

    final width = _parseDimension(widthStr);
    final height = _parseDimension(heightStr);

    final result = await ImageResolver.resolve(
      src ?? '',
      width: width,
      height: height,
      alt: alt,
    );

    if (result != null) {
      return DocxImage(
        bytes: result.bytes,
        extension: result.extension,
        width: result.width,
        height: result.height,
        altText: result.altText,
        align: DocxAlign.center,
      );
    }

    // Fallback
    return _parseImagePlaceholder(element);
  }

  static Future<DocxInlineImage?> _parseInlineImage(dom.Element element) async {
    final src = element.attributes['src'];
    final alt = element.attributes['alt'];
    final widthStr = element.attributes['width'];
    final heightStr = element.attributes['height'];

    final width = _parseDimension(widthStr);
    final height = _parseDimension(heightStr);

    final result = await ImageResolver.resolve(
      src ?? '',
      width: width,
      height: height,
      alt: alt,
    );

    if (result != null) {
      return DocxInlineImage(
        bytes: result.bytes,
        extension: result.extension,
        width: result.width,
        height: result.height,
        altText: result.altText,
      );
    }
    return null;
  }

  static DocxNode? _parseImagePlaceholder(dom.Element element) {
    final src = element.attributes['src'];
    if (src == null || src.isEmpty) return null;
    final alt = element.attributes['alt'] ?? 'Image';
    return DocxParagraph(
      align: DocxAlign.center,
      children: [
        DocxText('[📷 '),
        DocxText.link(alt, href: src),
        DocxText(']'),
      ],
    );
  }

  static double? _parseDimension(String? value) {
    if (value == null) return null;
    final cleaned =
        value.replaceAll(RegExp(r'px\s*$', caseSensitive: false), '').trim();
    return double.tryParse(cleaned);
  }

  static String? _parseColor(String val) {
    final trimmed = val.trim().toLowerCase();

    // Handle hex colors
    if (trimmed.startsWith('#')) {
      var hex = trimmed.substring(1).toUpperCase();
      if (hex.length == 3) {
        hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
      }
      return hex.length == 6 ? hex : null;
    }

    // Handle rgb/rgba
    if (trimmed.startsWith('rgb')) {
      final match = RegExp(
              r'rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)')
          .firstMatch(trimmed);
      if (match != null) {
        final r = int.tryParse(match.group(1) ?? '0') ?? 0;
        final g = int.tryParse(match.group(2) ?? '0') ?? 0;
        final b = int.tryParse(match.group(3) ?? '0') ?? 0;
        // Ignore alpha for DocxColor as standard
        return '${_toHex(r)}${_toHex(g)}${_toHex(b)}';
      }
    }

    // Handle named colors
    switch (trimmed) {
      case 'red':
        return 'FF0000';
      case 'green':
        return '008000';
      case 'blue':
        return '0000FF';
      case 'black':
        return '000000';
      case 'white':
        return 'FFFFFF';
      case 'grey':
      case 'gray':
        return '808080';
      case 'yellow':
        return 'FFFF00';
      case 'cyan':
        return '00FFFF';
      case 'magenta':
      case 'purple':
        return '800080';
      case 'orange':
        return 'FFA500';
      case 'pink':
        return 'FFC0CB';
      case 'brown':
        return 'A52A2A';
      case 'lime':
        return '00FF00';
      case 'teal':
        return '008080';
      case 'indigo':
        return '4B0082';
      case 'navy':
        return '000080';
      case 'maroon':
        return '800000';
      case 'olive':
        return '808000';
      case 'aqua':
        return '00FFFF';
      case 'fuchsia':
        return 'FF00FF';
      case 'silver':
        return 'C0C0C0';
      case 'transparent':
        return null;
      default:
        return null;
    }
  }

  static String _toHex(int val) {
    return val.toRadixString(16).padLeft(2, '0').toUpperCase();
  }
}

class _BlockStyles {
  final String? shadingFill;
  final String? colorHex;
  final DocxAlign align;
  _BlockStyles({this.shadingFill, this.colorHex, this.align = DocxAlign.left});
}
