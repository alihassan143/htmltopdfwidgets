import 'package:docx_creator/docx_creator.dart';
import 'package:html/dom.dart' as dom;

import '../../utils/document_builder.dart';
import 'color_utils.dart';
import 'image_parser.dart';
import 'parser_context.dart';

/// Parses HTML inline elements (text, links, formatting).
class HtmlInlineParser {
  final HtmlParserContext context;
  final HtmlImageParser _imageParser = HtmlImageParser();

  HtmlInlineParser(this.context);

  /// Parse inline children with async image support.
  Future<List<DocxInline>> parseInlines(List<dom.Node> nodes,
      {HtmlStyleContext? context}) async {
    final results = <DocxInline>[];
    for (var node in nodes) {
      if (node is dom.Element && node.localName?.toLowerCase() == 'img') {
        final img = await _imageParser.parseInlineImage(node);
        if (img != null) results.add(img);
      } else {
        results.addAll(parseInline(node, context: context));
      }
    }
    return results;
  }

  /// Parse inline content synchronously (no async image fetching).
  List<DocxInline> parseInlinesSync(List<dom.Node> nodes,
      {HtmlStyleContext? context}) {
    final results = <DocxInline>[];
    for (var node in nodes) {
      results.addAll(parseInline(node, context: context));
    }
    return results;
  }

  /// Parse a single inline node.
  List<DocxInline> parseInline(dom.Node node, {HtmlStyleContext? context}) {
    final ctx = context ?? const HtmlStyleContext();

    if (node is dom.Text) {
      final text = node.text;
      if (text.isEmpty) return [];

      // Check for checkbox patterns
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
      final combinedStyle =
          this.context.mergeStyles(node.attributes['style'], node.classes);
      final newCtx = ctx.mergeWith(tag, combinedStyle, ColorUtils.parseColor);

      switch (tag) {
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
          return _parseCode(node, newCtx);
        default:
          return parseInlinesSync(node.nodes, context: newCtx);
      }
    }
    return [];
  }

  List<DocxInline> _parseCode(dom.Element node, HtmlStyleContext ctx) {
    final text = _getText(node);
    final lines = text.split('\n');
    final results = <DocxInline>[];

    for (var i = 0; i < lines.length; i++) {
      results.add(DocxText.code(lines[i],
          fontSize: ctx.fontSize,
          shadingFill: ctx.shadingFill,
          color: ctx.colorHex != null
              ? DocxColor(ctx.colorHex!)
              : DocxColor.black));
      if (i < lines.length - 1) {
        results.add(DocxLineBreak());
      }
    }
    return results;
  }

  DocxText _createText(String text, HtmlStyleContext ctx) {
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

  String _getText(dom.Node node) {
    if (node is dom.Text) return node.text;
    if (node is dom.Element) return node.text;
    return '';
  }
}
