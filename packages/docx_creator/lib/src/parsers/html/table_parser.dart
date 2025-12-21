import 'package:docx_creator/docx_creator.dart';
import 'package:html/dom.dart' as dom;

import 'color_utils.dart';
import 'inline_parser.dart';
import 'parser_context.dart';

/// Parses HTML table elements.
class HtmlTableParser {
  final HtmlParserContext context;
  final HtmlInlineParser inlineParser;

  HtmlTableParser(this.context, this.inlineParser);

  /// Parse a table element.
  Future<DocxTable> parseTable(dom.Element element) async {
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

    // Parse table style (borders)
    final styleStr =
        context.mergeStyles(element.attributes['style'], element.classes);

    DocxBorder border = DocxBorder.none;
    if (styleStr.contains('border')) {
      if (styleStr.contains('solid')) border = DocxBorder.single;
    }
    if (element.attributes.containsKey('border')) {
      if (element.attributes['border'] != '0') border = DocxBorder.single;
    }

    return DocxTable(
      rows: rows,
      style: DocxTableStyle(
        borderTop: ColorUtils.parseCssBorderProperty(styleStr, 'border-top') ??
            ColorUtils.parseCssBorderProperty(styleStr, 'border') ??
            (border != DocxBorder.none ? DocxBorderSide(style: border) : null),
        borderBottom: ColorUtils.parseCssBorderProperty(
                styleStr, 'border-bottom') ??
            ColorUtils.parseCssBorderProperty(styleStr, 'border') ??
            (border != DocxBorder.none ? DocxBorderSide(style: border) : null),
        borderLeft: ColorUtils.parseCssBorderProperty(
                styleStr, 'border-left') ??
            ColorUtils.parseCssBorderProperty(styleStr, 'border') ??
            (border != DocxBorder.none ? DocxBorderSide(style: border) : null),
        borderRight: ColorUtils.parseCssBorderProperty(
                styleStr, 'border-right') ??
            ColorUtils.parseCssBorderProperty(styleStr, 'border') ??
            (border != DocxBorder.none ? DocxBorderSide(style: border) : null),
      ),
    );
  }

  Future<DocxTableRow?> _parseTableRow(dom.Element tr) async {
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

  Future<DocxTableCell> _parseTableCell(dom.Element td,
      {bool isHeader = false}) async {
    final style = context.mergeStyles(td.attributes['style'], td.classes);

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

  Future<List<DocxBlock>> _parseCellContent(List<dom.Node> nodes,
      {bool isHeader = false}) async {
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

        if (tag == 'table') {
          flushInlines();
          // Recursively parse nested table
          final nestedTable = await parseTable(node);
          blocks.add(nestedTable);
        } else if (_isBlockTag(tag)) {
          flushInlines();
          // Parse as paragraph
          final nodeInlines = inlineParser.parseInlinesSync(node.nodes);
          if (nodeInlines.isNotEmpty) {
            blocks.add(DocxParagraph(children: nodeInlines));
          }
        } else {
          inlines.addAll(inlineParser.parseInline(node));
        }
      }
    }

    flushInlines();

    if (blocks.isEmpty) {
      blocks.add(DocxParagraph(children: []));
    }

    return blocks;
  }

  bool _isBlockTag(String? tag) {
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
