import '../ast/docx_block.dart';
import '../ast/docx_inline.dart';
import '../ast/docx_list.dart';
import '../ast/docx_node.dart';
import '../ast/docx_section.dart';
import '../ast/docx_table.dart';
import '../builder/docx_document_builder.dart';

/// Exports [DocxBuiltDocument] to HTML format.
class HtmlExporter {
  /// Exports to HTML string.
  String export(DocxBuiltDocument doc) {
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html><head><meta charset="UTF-8">');
    buffer.writeln('<style>$_defaultStyles</style>');
    buffer.writeln('</head><body>');

    for (var element in doc.elements) {
      buffer.writeln(_convertNode(element));
    }

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  String _convertNode(DocxNode node) {
    if (node is DocxParagraph) return _convertParagraph(node);
    if (node is DocxTable) return _convertTable(node);
    if (node is DocxList) return _convertList(node);
    return '';
  }

  String _convertParagraph(DocxParagraph para) {
    String tag = 'p';
    if (para.styleId != null && para.styleId!.startsWith('Heading')) {
      tag = 'h${para.styleId!.replaceAll('Heading', '')}';
    }

    final styles = <String>[];
    if (para.align.name != 'left') styles.add('text-align: ${para.align.name}');
    if (para.indentLeft != null)
      styles.add('margin-left: ${para.indentLeft! / 20}px');
    if (para.shadingFill != null)
      styles.add('background-color: #${para.shadingFill}');

    final styleAttr = styles.isNotEmpty ? ' style="${styles.join(';')}"' : '';
    final content = para.children.map(_convertInline).join();

    return '<$tag$styleAttr>$content</$tag>';
  }

  String _convertInline(DocxInline inline) {
    if (inline is DocxText) return _convertText(inline);
    if (inline is DocxLineBreak) return '<br>';
    if (inline is DocxPageNumber)
      return '<span class="page-number">[Page]</span>';
    if (inline is DocxPageCount)
      return '<span class="page-count">[Total]</span>';
    return '';
  }

  String _convertText(DocxText text) {
    var content = _escapeHtml(text.content);
    if (text.isBold) content = '<strong>$content</strong>';
    if (text.isItalic) content = '<em>$content</em>';
    if (text.isUnderline) content = '<u>$content</u>';
    if (text.isStrike) content = '<del>$content</del>';

    final styles = <String>[];
    if (text.effectiveColorHex != null)
      styles.add('color: #${text.effectiveColorHex}');
    if (text.fontSize != null) styles.add('font-size: ${text.fontSize}pt');
    if (text.fontFamily != null) styles.add('font-family: ${text.fontFamily}');

    if (styles.isNotEmpty)
      content = '<span style="${styles.join(';')}">$content</span>';
    if (text.href != null) content = '<a href="${text.href}">$content</a>';
    return content;
  }

  String _convertTable(DocxTable table) {
    final buffer = StringBuffer('<table>');
    for (var row in table.rows) {
      buffer.write('<tr>');
      for (var cell in row.cells) {
        buffer.write('<td');
        if (cell.colSpan > 1) buffer.write(' colspan="${cell.colSpan}"');
        if (cell.shadingFill != null)
          buffer.write(' style="background-color: #${cell.shadingFill}"');
        buffer.write('>');
        for (var child in cell.children) {
          buffer.write(_convertNode(child));
        }
        buffer.write('</td>');
      }
      buffer.write('</tr>');
    }
    buffer.write('</table>');
    return buffer.toString();
  }

  String _convertList(DocxList list) {
    final tag = list.isOrdered ? 'ol' : 'ul';
    final buffer = StringBuffer('<$tag>');
    for (var item in list.items) {
      buffer.write('<li>${item.children.map(_convertInline).join()}</li>');
    }
    buffer.write('</$tag>');
    return buffer.toString();
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static const String _defaultStyles = '''
    body { font-family: Calibri, sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; }
    h1 { font-size: 24pt; color: #2E74B5; }
    h2 { font-size: 18pt; color: #2E74B5; }
    h3 { font-size: 14pt; }
    table { border-collapse: collapse; width: 100%; margin: 1em 0; }
    td, th { border: 1px solid #ddd; padding: 8px; }
    ul, ol { margin: 1em 0; padding-left: 2em; }
    a { color: #0563C1; }
  ''';
}
