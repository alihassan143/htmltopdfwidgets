import 'dart:io';

import '../../docx_creator.dart';

/// Exports [DocxBuiltDocument] to HTML format.
class HtmlExporter {
  Future<void> exportToFile(DocxBuiltDocument doc, String filePath) async {
    try {
      final bytes = export(doc);
      final file = File(filePath);
      await file.writeAsString(bytes);
    } catch (e) {
      throw DocxExportException(
        'Failed to write file: $e',
        targetFormat: 'HTML',
        context: filePath,
      );
    }
  }

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
    if (node is DocxImage) return _convertBlockImage(node);
    return '';
  }

  String _convertParagraph(DocxParagraph para) {
    String tag = 'p';
    if (para.styleId != null && para.styleId!.startsWith('Heading')) {
      tag = 'h${para.styleId!.replaceAll('Heading', '')}';
    }

    final styles = <String>[];
    if (para.align.name != 'left') styles.add('text-align: ${para.align.name}');

    // Indentation
    if (para.indentLeft != null) {
      styles.add('margin-left: ${para.indentLeft! / 20}pt');
    }
    if (para.indentRight != null) {
      styles.add('margin-right: ${para.indentRight! / 20}pt');
    }
    if (para.indentFirstLine != null) {
      styles.add('text-indent: ${para.indentFirstLine! / 20}pt');
    }

    // Spacing
    if (para.spacingBefore != null) {
      styles.add('margin-top: ${para.spacingBefore! / 20}pt');
    }
    if (para.spacingAfter != null) {
      styles.add('margin-bottom: ${para.spacingAfter! / 20}pt');
    }
    if (para.lineSpacing != null) {
      // Word line spacing 240 = 1 line. CSS line-height unitless usually 1.0, 1.5 etc.
      // or explicit pt.
      // lineSpacing 240 = 12pt approx? No, 240 is 240/240 lines.
      // Let's assume standard multiple rule for now.
      styles.add('line-height: ${para.lineSpacing! / 240}');
    }

    // Shading
    if (para.shadingFill != null) {
      styles.add('background-color: #${para.shadingFill}');
    }

    final styleAttr = styles.isNotEmpty ? ' style="${styles.join(';')}"' : '';
    final content = para.children.map(_convertInline).join();

    return '<$tag$styleAttr>$content</$tag>';
  }

  String _convertBlockImage(DocxImage image) {
    // Block image is wrapped in a div/p with alignment
    final styles = <String>[];
    if (image.align != DocxAlign.left) {
      styles.add('text-align: ${image.align.name}');
    }

    final content = _convertInlineImage(image.asInline);
    final styleAttr = styles.isNotEmpty ? ' style="${styles.join(';')}"' : '';

    return '<div$styleAttr>$content</div>';
  }

  String _convertInline(DocxInline inline) {
    if (inline is DocxText) return _convertText(inline);
    if (inline is DocxLineBreak) return '<br>';
    if (inline is DocxInlineImage) return _convertInlineImage(inline);
    if (inline is DocxPageNumber) {
      return '<span class="page-number">[Page]</span>';
    }
    if (inline is DocxPageCount) {
      return '<span class="page-count">[Total]</span>';
    }
    return '';
  }

  String _convertInlineImage(DocxInlineImage image) {
    // Use Base64 for images in HTML export for portability
    final base64 =
        Uri.dataFromBytes(image.bytes, mimeType: 'image/${image.extension}')
            .toString();

    final styles = <String>[];
    styles.add('width: ${image.width}pt');
    styles.add('height: ${image.height}pt');

    return '<img src="$base64" alt="${image.altText ?? ''}" style="${styles.join(';')}" />';
  }

  String _convertText(DocxText text) {
    var content = _escapeHtml(text.content);
    if (text.isBold) content = '<strong>$content</strong>';
    if (text.isItalic) content = '<em>$content</em>';
    if (text.isUnderline) content = '<u>$content</u>';
    if (text.isStrike || text.isDoubleStrike) content = '<del>$content</del>';
    if (text.isSuperscript) content = '<sup>$content</sup>';
    if (text.isSubscript) content = '<sub>$content</sub>';

    final styles = <String>[];
    if (text.effectiveColorHex != null) {
      styles.add('color: #${text.effectiveColorHex}');
    }
    if (text.fontSize != null) {
      styles.add('font-size: ${text.fontSize}pt');
    }
    if (text.fontFamily != null) {
      styles.add("font-family: '${text.fontFamily}'");
    }

    // Highlight
    if (text.highlight != DocxHighlight.none) {
      // Simple mapping for standard highlight colors
      styles.add('background-color: ${text.highlight.name}');
    } else if (text.shadingFill != null) {
      styles.add('background-color: #${text.shadingFill}');
    }

    // Effects
    if (text.isAllCaps) styles.add('text-transform: uppercase');
    if (text.isSmallCaps) styles.add('font-variant: small-caps');
    if (text.isShadow) styles.add('text-shadow: 1px 1px 2px grey');

    if (styles.isNotEmpty) {
      content = '<span style="${styles.join(';')}">$content</span>';
    }
    if (text.href != null) {
      content = '<a href="${text.href}">$content</a>';
    }
    return content;
  }

  String _convertTable(DocxTable table) {
    final buffer = StringBuffer('<table>');
    for (var row in table.rows) {
      buffer.write('<tr>');
      for (var cell in row.cells) {
        buffer.write('<td');
        if (cell.colSpan > 1) buffer.write(' colspan="${cell.colSpan}"');
        if (cell.shadingFill != null) {
          buffer.write(' style="background-color: #${cell.shadingFill}"');
        }
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
    if (list.items.isEmpty) return '';

    final buffer = StringBuffer();
    final stack = <String>[]; // Stack of closing tags </ol> or </ul>
    int currentLevel = -1;

    void openLevel(int targetLevel, bool ordered) {
      while (currentLevel < targetLevel) {
        final tag = ordered ? 'ol' : 'ul';
        buffer.write('<$tag>');
        stack.add('</$tag>');
        currentLevel++;
      }
    }

    void closeLevel(int targetLevel) {
      while (currentLevel > targetLevel) {
        buffer.write(stack.removeLast());
        currentLevel--;
      }
    }

    for (var item in list.items) {
      if (item.level > currentLevel) {
        openLevel(item.level, list.isOrdered);
      } else if (item.level < currentLevel) {
        closeLevel(item.level);
      }

      buffer.write('<li>${item.children.map(_convertInline).join()}</li>');
    }

    closeLevel(-1); // Close all
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
    td, th { border: 1px solid #ddd; padding: 8px; vertical-align: top; }
    ul, ol { margin: 1em 0; padding-left: 2em; }
    li { margin-bottom: 0.5em; }
    a { color: #0563C1; }
    img { max-width: 100%; height: auto; }
  ''';
}
