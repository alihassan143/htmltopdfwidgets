import 'package:html/dom.dart' as dom;

import '../../../docx_creator.dart';
import '../../utils/document_builder.dart';
import 'color_utils.dart';
import 'image_parser.dart';
import 'inline_parser.dart';
import 'list_parser.dart';
import 'parser_context.dart';
import 'style_context.dart';
import 'table_parser.dart';

/// Parses HTML block-level elements.
class HtmlBlockParser {
  final HtmlParserContext context;
  late final HtmlInlineParser _inlineParser;
  late final HtmlTableParser _tableParser;
  late final HtmlListParser _listParser;
  late final HtmlImageParser _imageParser;

  HtmlBlockParser(this.context) {
    _inlineParser = HtmlInlineParser(context);
    _tableParser = HtmlTableParser(context, _inlineParser);
    _listParser = HtmlListParser(context, _inlineParser);
    _imageParser = HtmlImageParser();
  }

  /// Parse child nodes into DocxNode elements.
  Future<List<DocxNode>> parseChildren(List<dom.Node> nodes) async {
    final results = <DocxNode>[];
    for (var node in nodes) {
      final parsed = await parseNode(node);
      if (parsed != null) results.add(parsed);
    }
    return results;
  }

  /// Parse a single DOM node.
  Future<DocxNode?> parseNode(dom.Node node) async {
    if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return null;
      return DocumentBuilder.buildBlockElement(
        tag: 'p',
        children: [DocxText(text)],
      );
    }
    if (node is dom.Element) return parseElement(node);
    return null;
  }

  /// Parse an HTML element.
  Future<DocxNode?> parseElement(dom.Element element) async {
    final tag = element.localName?.toLowerCase();
    if (tag == null) return null;

    final styleStr =
        context.mergeStyles(element.attributes['style'], element.classes);

    final initialContext = const HtmlStyleContext()
        .mergeWith(tag, styleStr, ColorUtils.parseColor);
    final blockContext = initialContext.resetBackground();

    // Parse inline children
    final children =
        await _inlineParser.parseInlines(element.nodes, context: blockContext);

    final built = DocumentBuilder.buildBlockElement(
      tag: tag,
      children: [],
      textContent: _getText(element),
    );

    if (built != null &&
        tag != 'p' &&
        tag != 'div' &&
        tag != 'pre' &&
        !tag.startsWith('h')) {
      return built;
    }

    final blockStyles = _parseBlockStyles(styleStr);

    switch (tag) {
      case 'p':
      case 'div':
        if (children.isEmpty) return null;
        return DocxParagraph(
          children: children,
          shadingFill: blockStyles.shadingFill,
          align: blockStyles.align,
          borderTop: blockStyles.borderTop,
          borderBottomSide: blockStyles.borderBottom,
          borderLeft: blockStyles.borderLeft,
          borderRight: blockStyles.borderRight,
        );

      case 'ul':
        return _listParser.parseList(element, ordered: false);
      case 'ol':
        return _listParser.parseList(element, ordered: true);

      case 'table':
        return _tableParser.parseTable(element);

      case 'img':
        return _imageParser.parseBlockImage(element);

      case 'pre':
      case 'code':
        return _parseCodeBlock(element, blockStyles.align);

      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
      case 'blockquote':
      case 'hr':
        if (built is DocxParagraph) {
          return built.copyWith(
            shadingFill: blockStyles.shadingFill ?? built.shadingFill,
            align: blockStyles.align,
            borderTop: blockStyles.borderTop,
            borderBottomSide: blockStyles.borderBottom,
            borderLeft: blockStyles.borderLeft,
            borderRight: blockStyles.borderRight,
          );
        }
        return built;

      default:
        if (children.isEmpty) return null;
        return DocxParagraph(
          children: children,
          shadingFill: blockStyles.shadingFill,
          align: blockStyles.align,
        );
    }
  }

  DocxParagraph _parseCodeBlock(dom.Element element, DocxAlign align) {
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
      align: align,
    );
  }

  HtmlBlockStyles _parseBlockStyles(String style) {
    String? shadingFill;
    DocxAlign align = DocxAlign.left;

    final bgMatch = RegExp(
            r"background-color:\s*['\x22]?(#[A-Fa-f0-9]{3,6}|rgb\([0-9,\s]+\)|rgba\([0-9.,\s]+\)|[a-zA-Z]+)['\x22]?")
        .firstMatch(style);
    if (bgMatch != null) {
      final val = bgMatch.group(1);
      if (val != null) {
        shadingFill = ColorUtils.parseColor(val);
      }
    }

    if (style.contains('text-align: center')) {
      align = DocxAlign.center;
    } else if (style.contains('text-align: right')) {
      align = DocxAlign.right;
    } else if (style.contains('text-align: justify')) {
      align = DocxAlign.justify;
    }

    return HtmlBlockStyles(
      shadingFill: shadingFill,
      align: align,
      borderTop: ColorUtils.parseCssBorderProperty(style, 'border-top') ??
          ColorUtils.parseCssBorderProperty(style, 'border'),
      borderBottom: ColorUtils.parseCssBorderProperty(style, 'border-bottom') ??
          ColorUtils.parseCssBorderProperty(style, 'border'),
      borderLeft: ColorUtils.parseCssBorderProperty(style, 'border-left') ??
          ColorUtils.parseCssBorderProperty(style, 'border'),
      borderRight: ColorUtils.parseCssBorderProperty(style, 'border-right') ??
          ColorUtils.parseCssBorderProperty(style, 'border'),
    );
  }

  String _getText(dom.Node node) {
    if (node is dom.Text) return node.text;
    if (node is dom.Element) return node.text;
    return '';
  }

  /// Check if a tag is a block-level element.
  static bool isBlockTag(String? tag) {
    if (tag == null) return false;
    return [
      'p',
      'div',
      'table',
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
}
