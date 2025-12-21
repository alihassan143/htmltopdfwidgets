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

      // Extract CSS classes from <style> tags
      final cssMap = _parseCssClasses(document);

      final body = document.body;
      if (body == null) return [];
      return _parseChildren(body.nodes, cssMap: cssMap);
    } catch (e) {
      throw DocxParserException(
        'Failed to parse HTML: $e',
        sourceFormat: 'HTML',
      );
    }
  }

  static Map<String, String> _parseCssClasses(dom.Document document) {
    final cssMap = <String, String>{};
    final styles = document.querySelectorAll('style');
    for (var style in styles) {
      final text = style.text;
      // Simple regex for .className { ... }
      final matches =
          RegExp(r'\.([a-zA-Z0-9_-]+)\s*\{([^}]+)\}').allMatches(text);
      for (var match in matches) {
        final className = match.group(1);
        final styleBody = match.group(2);
        if (className != null && styleBody != null) {
          cssMap[className] = styleBody.trim();
        }
      }
    }
    return cssMap;
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

  static Future<List<DocxNode>> _parseChildren(List<dom.Node> nodes,
      {Map<String, String>? cssMap}) async {
    final results = <DocxNode>[];
    for (var node in nodes) {
      final parsed = await _parseNode(node, cssMap: cssMap);
      if (parsed != null) results.add(parsed);
    }
    return results;
  }

  static Future<DocxNode?> _parseNode(dom.Node node,
      {Map<String, String>? cssMap}) async {
    if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return null;
      return DocumentBuilder.buildBlockElement(
        tag: 'p',
        children: [DocxText(text)],
      );
    }
    if (node is dom.Element) return _parseElement(node, cssMap: cssMap);
    return null;
  }

  static Future<DocxNode?> _parseElement(dom.Element element,
      {Map<String, String>? cssMap}) async {
    final tag = element.localName?.toLowerCase();
    if (tag == null) return null;

    // Extract block styles early
    final styleStr =
        _mergeStyles(element.attributes['style'], element.classes, cssMap);

    // Create context for this block (inheritance)
    final initialContext = const DocxStyleContext().mergeWith(tag, styleStr);

    // Background color (shading) is NOT inherited in CSS.
    // We remove it from the context passed to children so they don't get 'run shading'.
    // The block itself will still have shading applied via _parseBlockStyles below.
    final blockContext = initialContext.resetBackground();

    // 1. Try Shared Builder for standard blocks
    final children = await _parseInlines(element.nodes,
        context: blockContext, cssMap: cssMap);

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
      // For simple standard blocks
      return built;
    }

    // Still parse block styles for DocxParagraph properties (align, shading)
    // which are not part of DocxStyleContext (which focuses on text/inline properties)
    final blockStyles = _parseBlockStyles(styleStr);

    switch (tag) {
      case 'p':
      case 'div':
        if (children.isEmpty) return null;

        return DocxParagraph(
          children: children,
          shadingFill: blockStyles.shadingFill,
          align: blockStyles.align,
        );

      case 'ul':
        return _parseList(element, ordered: false, cssMap: cssMap);
      case 'ol':
        return _parseList(element, ordered: true, cssMap: cssMap);

      case 'table':
        return _parseTable(element, cssMap: cssMap);

      case 'img':
        return _parseImage(element);

      case 'pre':
        // Handle code blocks: preserve newlines
        final text = _getText(element);
        final lines = text.split('\n');
        final codeChildren = <DocxInline>[];

        for (var i = 0; i < lines.length; i++) {
          codeChildren.add(DocxText.code(lines[i], color: DocxColor.black));
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
          codeChildren.add(DocxText.code(lines[i], color: DocxColor.black));
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

  static Future<List<DocxInline>> _parseInlines(List<dom.Node> nodes,
      {DocxStyleContext? context, Map<String, String>? cssMap}) async {
    final results = <DocxInline>[];
    for (var node in nodes) {
      if (node is dom.Element && node.localName?.toLowerCase() == 'img') {
        final img = await _parseInlineImage(node);
        if (img != null) results.add(img);
      } else {
        results.addAll(_parseInline(node, context: context, cssMap: cssMap));
      }
    }
    return results;
  }

  static List<DocxInline> _parseInline(dom.Node node,
      {DocxStyleContext? context, Map<String, String>? cssMap}) {
    final ctx = context ?? const DocxStyleContext();

    if (node is dom.Text) {
      final text = node.text;
      if (text.isEmpty) return [];

      // Check for [ ] and [x] patterns at the start of text
      if (text.startsWith('[ ] ')) {
        return [
          DocumentBuilder.buildCheckbox(
            isChecked: false,
            fontSize: ctx.fontSize,
            fontWeight: ctx.fontWeight,
            fontStyle: ctx.fontStyle,
            color: ctx.colorHex != null ? DocxColor(ctx.colorHex!) : null,
          ),
          _createText(text.substring(4), ctx)
        ];
      } else if (text.startsWith('[x] ') || text.startsWith('[X] ')) {
        return [
          DocumentBuilder.buildCheckbox(
            isChecked: true,
            fontSize: ctx.fontSize,
            fontWeight: ctx.fontWeight,
            fontStyle: ctx.fontStyle,
            color: ctx.colorHex != null ? DocxColor(ctx.colorHex!) : null,
          ),
          _createText(text.substring(4), ctx)
        ];
      }

      return [_createText(text, ctx)];
    }

    if (node is dom.Element) {
      final tag = node.localName?.toLowerCase();
      // Update context based on tag and style
      final combinedStyle =
          _mergeStyles(node.attributes['style'], node.classes, cssMap);
      final newCtx = ctx.mergeWith(tag, combinedStyle);

      switch (tag) {
        // Tag-specific handling that produces non-text inlines
        case 'br':
          return [DocxLineBreak()];
        case 'a':
          final href = node.attributes['href'];
          return [
            _createText(_getText(node),
                newCtx.copyWith(href: href ?? '#', isLink: true))
          ];
        case 'input':
          final type = node.attributes['type']?.toLowerCase();
          if (type == 'checkbox') {
            return [
              DocumentBuilder.buildCheckbox(
                isChecked: node.attributes.containsKey('checked'),
                fontSize: newCtx.fontSize,
                fontWeight: newCtx.fontWeight,
                fontStyle: newCtx.fontStyle,
                color: newCtx.colorHex != null
                    ? DocxColor(newCtx.colorHex!)
                    : null,
              )
            ];
          }
          return [];
        case 'code':
          // Preserving existing logic for code splitting lines
          final text = _getText(node);
          final lines = text.split('\n');
          final results = <DocxInline>[];
          // Code typically monospaced, maybe gray bg?
          // Using existing DocxText.code behavior but with inheritance?
          // DocxText.code hardcodes font family.
          for (var i = 0; i < lines.length; i++) {
            // Pass color from context, default to black if not set
            results.add(DocxText.code(lines[i],
                fontSize: newCtx.fontSize,
                shadingFill: newCtx.shadingFill,
                color: newCtx.colorHex != null
                    ? DocxColor(newCtx.colorHex!)
                    : DocxColor.black));
            if (i < lines.length - 1) {
              results.add(DocxLineBreak());
            }
          }
          return results;

        default:
          return _parseInlinesSync(node.nodes, context: newCtx, cssMap: cssMap);
      }
    }
    return [];
  }

  // Helper for recursive synchronous inline parsing
  static List<DocxInline> _parseInlinesSync(List<dom.Node> nodes,
      {DocxStyleContext? context, Map<String, String>? cssMap}) {
    final results = <DocxInline>[];
    for (var node in nodes) {
      results.addAll(_parseInline(node, context: context, cssMap: cssMap));
    }
    return results;
  }

  static DocxText _createText(String text, DocxStyleContext ctx) {
    return DocxText(
      text,
      fontWeight: ctx.fontWeight,
      fontStyle: ctx.fontStyle,
      decoration: ctx.decoration,
      color: ctx.colorHex != null ? DocxColor(ctx.colorHex!) : DocxColor.black,
      fontSize: ctx.fontSize,
      highlight: ctx.highlight,
      shadingFill: ctx.shadingFill,
      href: ctx.href,
      isSuperscript: ctx.isSuperscript,
      isSubscript: ctx.isSubscript,
      isAllCaps: ctx.isAllCaps,
      isSmallCaps: ctx.isSmallCaps,
      isDoubleStrike: ctx.isDoubleStrike,
      isOutline: ctx.isOutline,
      isShadow: ctx.isShadow,
      isEmboss: ctx.isEmboss,
      isImprint: ctx.isImprint,
    );
  }

  static _BlockStyles _parseBlockStyles(String style) {
    String? shadingFill;
    DocxAlign align = DocxAlign.left;

    final bgMatch = RegExp(
            r"background-color:\s*['\x22]?(#[A-Fa-f0-9]{3,6}|rgb\([0-9,\s]+\)|rgba\([0-9.,\s]+\)|[a-zA-Z]+)['\x22]?")
        .firstMatch(style);
    if (bgMatch != null) {
      final val = bgMatch.group(1);
      if (val != null) {
        shadingFill = _parseColor(val);
      }
    }

    if (style.contains('text-align: center')) {
      align = DocxAlign.center;
    } else if (style.contains('text-align: right')) {
      align = DocxAlign.right;
    } else if (style.contains('text-align: justify')) {
      align = DocxAlign.justify;
    }

    String? colorHex;
    final colorMatch = RegExp(
            r"color:\s*['\x22]?(#[A-Fa-f0-9]{3,6}|rgb\([0-9,\s]+\)|rgba\([0-9.,\s]+\)|[a-zA-Z]+)['\x22]?")
        .firstMatch(style);

    if (colorMatch != null) {
      final val = colorMatch.group(1);
      if (val != null) colorHex = _parseColor(val);
    }

    return _BlockStyles(
        shadingFill: shadingFill, align: align, colorHex: colorHex);
  }

  static Future<DocxList> _parseList(
    dom.Element element, {
    required bool ordered,
    int level = 0,
    Map<String, String>? cssMap,
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
              nestedLists.add(await _parseList(node,
                  ordered: false, level: level + 1, cssMap: cssMap));
              continue;
            } else if (node.localName == 'ol') {
              nestedLists.add(await _parseList(node,
                  ordered: true, level: level + 1, cssMap: cssMap));
              continue;
            }
          }
          // Use async inline parser
          inlines.addAll(_parseInline(node, cssMap: cssMap));
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

  static Future<DocxTable> _parseTable(dom.Element element,
      {Map<String, String>? cssMap}) async {
    final rows = <DocxTableRow>[];

    for (var child in element.children) {
      final childTag = child.localName?.toLowerCase();

      if (childTag == 'tbody' || childTag == 'thead' || childTag == 'tfoot') {
        for (var tr in child.children) {
          if (tr.localName?.toLowerCase() == 'tr') {
            final row = await _parseTableRow(tr, cssMap: cssMap);
            if (row != null) rows.add(row);
          }
        }
      } else if (childTag == 'tr') {
        final row = await _parseTableRow(child, cssMap: cssMap);
        if (row != null) rows.add(row);
      }
    }

    // Parse table style (borders)
    final styleStr =
        _mergeStyles(element.attributes['style'], element.classes, cssMap);

    DocxBorder border = DocxBorder.none;
    if (styleStr.contains('border')) {
      // Simple check
      // TODO: robust parsing of border: 1px solid black
      if (styleStr.contains('solid')) border = DocxBorder.single;
    }
    if (element.attributes.containsKey('border')) {
      if (element.attributes['border'] != '0') border = DocxBorder.single;
    }

    return DocxTable(
      rows: rows,
      style: border != DocxBorder.none
          ? DocxTableStyle(border: border)
          : DocxTableStyle.headerHighlight,
    );
  }

  static Future<DocxTableRow?> _parseTableRow(dom.Element tr,
      {Map<String, String>? cssMap}) async {
    final cells = <DocxTableCell>[];

    for (var child in tr.children) {
      final tag = child.localName?.toLowerCase();
      if (tag == 'td' || tag == 'th') {
        final cell =
            await _parseTableCell(child, isHeader: tag == 'th', cssMap: cssMap);
        cells.add(cell);
      }
    }

    if (cells.isEmpty) return null;
    return DocxTableRow(cells: cells);
  }

  static Future<DocxTableCell> _parseTableCell(dom.Element td,
      {bool isHeader = false, Map<String, String>? cssMap}) async {
    final style = _mergeStyles(td.attributes['style'], td.classes, cssMap);

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

    final content =
        await _parseCellContent(td.nodes, isHeader: isHeader, cssMap: cssMap);

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
    Map<String, String>? cssMap,
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
          final block = await _parseElement(node, cssMap: cssMap);
          if (block is DocxBlock) {
            blocks.add(block);
          }
        } else {
          inlines.addAll(_parseInline(node, cssMap: cssMap));
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
    // Support spaces in regex more flexibly
    if (trimmed.startsWith('rgb')) {
      final match = RegExp(
              r'rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*[\d.]+)?\s*\)')
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
      case 'lightgray':
      case 'lightgrey':
        return 'D3D3D3';
      case 'darkgray':
      case 'darkgrey':
        return 'A9A9A9';

      case 'transparent':
        return null;
      default:
        // Try to see if it is a valid hex without #?
        // But CSS usually requires # for hex.
        // Some users might pass raw hex.
        if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(trimmed)) {
          return trimmed.toUpperCase();
        }
        return null;
    }
  }

  static String _toHex(int val) {
    return val.toRadixString(16).padLeft(2, '0').toUpperCase();
  }

  static String _mergeStyles(String? inlineStyle, Iterable<String> classes,
      Map<String, String>? cssMap) {
    var combined = inlineStyle ?? '';
    // Append class styles AFTER inline styles so that 'firstMatch' logic
    // (which assumes simple parsing) works if we want Inline to have priority?
    // WAIT. If we look for the FIRST "color:"...
    // String: "color: blue; color: red;"
    // firstMatch finds "color: blue".
    // If Inline is Blue and Class is Red.
    // If we want Inline to Win, Inline must be First.
    // So "Inline; Class" is correct.

    if (cssMap != null && classes.isNotEmpty) {
      for (var cls in classes) {
        if (cssMap.containsKey(cls)) {
          // Append class style
          combined = '$combined;${cssMap[cls]}';
        }
      }
    }
    return combined;
  }
}

class _BlockStyles {
  final String? shadingFill;
  final String? colorHex;
  final DocxAlign align;
  _BlockStyles({this.shadingFill, this.colorHex, this.align = DocxAlign.left});
}

class DocxStyleContext {
  final String? colorHex;
  final double? fontSize;
  final DocxFontWeight fontWeight;
  final DocxFontStyle fontStyle;
  final DocxTextDecoration decoration;
  final DocxHighlight highlight;
  final String? shadingFill;
  final String? href;
  final bool isLink;
  final bool isSuperscript;
  final bool isSubscript;
  final bool isAllCaps;
  final bool isSmallCaps;
  final bool isDoubleStrike;
  final bool isOutline;
  final bool isShadow;
  final bool isEmboss;
  final bool isImprint;

  const DocxStyleContext({
    this.colorHex,
    this.fontSize,
    this.fontWeight = DocxFontWeight.normal,
    this.fontStyle = DocxFontStyle.normal,
    this.decoration = DocxTextDecoration.none,
    this.highlight = DocxHighlight.none,
    this.shadingFill,
    this.href,
    this.isLink = false,
    this.isSuperscript = false,
    this.isSubscript = false,
    this.isAllCaps = false,
    this.isSmallCaps = false,
    this.isDoubleStrike = false,
    this.isOutline = false,
    this.isShadow = false,
    this.isEmboss = false,
    this.isImprint = false,
  });

  DocxStyleContext copyWith({
    String? colorHex,
    double? fontSize,
    DocxFontWeight? fontWeight,
    DocxFontStyle? fontStyle,
    DocxTextDecoration? decoration,
    DocxHighlight? highlight,
    String? shadingFill,
    String? href,
    bool? isLink,
    bool? isSuperscript,
    bool? isSubscript,
    bool? isAllCaps,
    bool? isSmallCaps,
    bool? isDoubleStrike,
    bool? isOutline,
    bool? isShadow,
    bool? isEmboss,
    bool? isImprint,
  }) {
    return DocxStyleContext(
      colorHex: colorHex ?? this.colorHex,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      decoration: decoration ?? this.decoration,
      highlight: highlight ?? this.highlight,
      shadingFill: shadingFill ?? this.shadingFill,
      href: href ?? this.href,
      isLink: isLink ?? this.isLink,
      isSuperscript: isSuperscript ?? this.isSuperscript,
      isSubscript: isSubscript ?? this.isSubscript,
      isAllCaps: isAllCaps ?? this.isAllCaps,
      isSmallCaps: isSmallCaps ?? this.isSmallCaps,
      isDoubleStrike: isDoubleStrike ?? this.isDoubleStrike,
      isOutline: isOutline ?? this.isOutline,
      isShadow: isShadow ?? this.isShadow,
      isEmboss: isEmboss ?? this.isEmboss,
      isImprint: isImprint ?? this.isImprint,
    );
  }

  DocxStyleContext mergeWith(String? tag, String style) {
    if ((tag == null || tag.isEmpty) && style.isEmpty) return this;

    var ctx = this;

    // Tag based updates
    if (tag != null) {
      switch (tag) {
        case 'b':
        case 'strong':
          ctx = ctx.copyWith(fontWeight: DocxFontWeight.bold);
          break;
        case 'i':
        case 'em':
          ctx = ctx.copyWith(fontStyle: DocxFontStyle.italic);
          break;
        case 'u':
          ctx = ctx.copyWith(decoration: DocxTextDecoration.underline);
          break;
        case 's':
        case 'del':
        case 'strike':
          ctx = ctx.copyWith(decoration: DocxTextDecoration.strikethrough);
          break;
        case 'sup':
          ctx = ctx.copyWith(isSuperscript: true);
          break;
        case 'sub':
          ctx = ctx.copyWith(isSubscript: true);
          break;
        case 'mark':
          ctx = ctx.copyWith(highlight: DocxHighlight.yellow);
          break;
      }
    }

    // Style attribute based updates
    if (style.isNotEmpty) {
      if (style.contains('font-weight') &&
          (style.contains('bold') || style.contains('700'))) {
        ctx = ctx.copyWith(fontWeight: DocxFontWeight.bold);
      }

      if (style.contains('font-style') && style.contains('italic')) {
        ctx = ctx.copyWith(fontStyle: DocxFontStyle.italic);
      }

      if (style.contains('text-decoration') && style.contains('underline')) {
        ctx = ctx.copyWith(decoration: DocxTextDecoration.underline);
      }

      if (style.contains('text-decoration') && style.contains('line-through')) {
        ctx = ctx.copyWith(decoration: DocxTextDecoration.strikethrough);
      }

      final sizeMatch = RegExp(r"font-size:\s*(\d+)").firstMatch(style);
      if (sizeMatch != null) {
        final fs = double.tryParse(sizeMatch.group(1)!);
        if (fs != null) ctx = ctx.copyWith(fontSize: fs);
      }

      // Color parsing and normalization
      // Use negative lookbehind (?<!-) to prevent matching 'color:' inside 'background-color:'
      final colorMatch = RegExp(
              r"(?<!-)color:\s*['\x22]?(#[A-Fa-f0-9]{3,6}|rgb\([0-9,\s]+\)|rgba\([0-9.,\s]+\)|[a-zA-Z]+)['\x22]?")
          .firstMatch(style);
      if (colorMatch != null) {
        final val = colorMatch.group(1);
        if (val != null) {
          final hex = DocxParser._parseColor(val);
          if (hex != null) ctx = ctx.copyWith(colorHex: hex);
        }
      }

      // Background Color (Shading)
      final bgMatch = RegExp(
              r"background-color:\s*['\x22]?(#[A-Fa-f0-9]{3,6}|rgb\([0-9,\s]+\)|rgba\([0-9.,\s]+\)|[a-zA-Z]+)['\x22]?")
          .firstMatch(style);
      if (bgMatch != null) {
        final bgVal = bgMatch.group(1)?.toLowerCase();
        if (bgVal != null) {
          final hex = DocxParser._parseColor(bgVal);
          if (hex != null) ctx = ctx.copyWith(shadingFill: hex);
        }
      }
    }

    return ctx;
  }

  DocxStyleContext resetBackground() {
    return DocxStyleContext(
      colorHex: colorHex,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: decoration,
      highlight: highlight,
      shadingFill: null, // Reset
      href: href,
      isLink: isLink,
      isSuperscript: isSuperscript,
      isSubscript: isSubscript,
      isAllCaps: isAllCaps,
      isSmallCaps: isSmallCaps,
      isDoubleStrike: isDoubleStrike,
      isOutline: isOutline,
      isShadow: isShadow,
      isEmboss: isEmboss,
      isImprint: isImprint,
    );
  }
}
