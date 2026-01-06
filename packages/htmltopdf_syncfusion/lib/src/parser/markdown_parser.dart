import 'package:flutter/material.dart';
import 'package:htmltopdf_syncfusion/src/parser/css_style.dart';
import 'package:htmltopdf_syncfusion/src/parser/render_node.dart';
import 'package:markdown/markdown.dart' as md;

/// Parses Markdown content into [RenderNode] elements.
class MarkdownParser {
  final CSSStyle baseStyle;

  MarkdownParser({
    this.baseStyle = const CSSStyle(),
  });

  /// Parses Markdown string into a root [RenderNode].
  RenderNode parse(String markdown) {
    // Enable GFM (tables, strikethrough, autolinks, task lists)
    final document = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored);
    final nodes = document.parseLines(markdown.split('\n'));

    final children = _parseNodes(nodes);

    return RenderNode(
      tagName: 'body',
      style: baseStyle,
      children: children,
    );
  }

  List<RenderNode> _parseNodes(List<md.Node> nodes) {
    final results = <RenderNode>[];
    for (var node in nodes) {
      final parsed = _parseNode(node);
      if (parsed != null) results.add(parsed);
    }
    return results;
  }

  RenderNode? _parseNode(md.Node node) {
    if (node is md.Element) {
      return _parseElement(node);
    } else if (node is md.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return null;
      // Text at root level is treated as a paragraph block or just text?
      // markdown package usually wraps text in paragraphs if block.
      // But if it's direct text node in list or similar.
      return RenderNode(
        tagName: '#text',
        style: const CSSStyle(),
        text: node.text,
      );
    }
    return null;
  }

  RenderNode? _parseElement(md.Element element) {
    final tag = element.tag;
    final children = _parseNodes(element.children ?? []);

    // Helper to get text content
    // String? textContent;
    // if (children.isEmpty && element.textContent.isNotEmpty) {
    //   textContent = element.textContent;
    // }

    switch (tag) {
      case 'p':
        return RenderNode(
            tagName: 'p',
            style: const CSSStyle(
                display: Display.block, margin: EdgeInsets.only(bottom: 10)),
            children: children);
      // Headings
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        double fontSize = 24.0;
        if (tag == 'h1') fontSize = 32.0;
        if (tag == 'h2') fontSize = 24.0;
        if (tag == 'h3') fontSize = 18.72;
        if (tag == 'h4') fontSize = 16.0;
        if (tag == 'h5') fontSize = 13.28;
        if (tag == 'h6') fontSize = 10.72;
        return RenderNode(
            tagName: tag,
            style: CSSStyle(
                display: Display.block,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                margin: const EdgeInsets.only(top: 20, bottom: 10)),
            children: children);

      // Formatting
      case 'strong':
      case 'b':
        return RenderNode(
            tagName: 'strong',
            style: const CSSStyle(fontWeight: FontWeight.bold),
            children: children);
      case 'em':
      case 'i':
        return RenderNode(
            tagName: 'em',
            style: const CSSStyle(fontStyle: FontStyle.italic),
            children: children);
      case 'del':
      case 's':
      case 'strike':
        return RenderNode(
            tagName: 'del',
            style: const CSSStyle(textDecoration: TextDecoration.lineThrough),
            children: children);
      case 'code':
        return RenderNode(
            tagName: 'code',
            style: const CSSStyle(
                fontFamily: 'Courier', backgroundColor: Color(0xFFEEEEEE)),
            children: children);
      case 'pre': // Code block
        return RenderNode(
            tagName: 'pre',
            style: const CSSStyle(
                display: Display.block,
                fontFamily: 'Courier',
                backgroundColor: Color(0xFFF5F5F5),
                padding: EdgeInsets.all(8.0),
                margin: EdgeInsets.only(bottom: 10)),
            children: children);
      case 'a':
        final href = element.attributes['href'];
        // TODO: Handle links in RenderNode/PdfBuilder (needs support)
        // treating as text for now but maintaining tag
        return RenderNode(
            tagName: 'a',
            style: const CSSStyle(
                color: Colors.blue, textDecoration: TextDecoration.underline),
            children: children,
            attributes: href != null ? {'href': href} : {});
      case 'img':
        final src = element.attributes['src'];
        return RenderNode(
            tagName: 'img',
            style: const CSSStyle(display: Display.block),
            attributes: src != null ? {'src': src} : {});
      case 'br':
        return RenderNode(tagName: 'br', style: const CSSStyle());
      case 'hr':
        return RenderNode(
            tagName: 'hr',
            style: const CSSStyle(
                display: Display.block,
                borderBottom: BorderSide(width: 1, color: Colors.grey)));
      // Lists
      case 'ul':
        return RenderNode(
            tagName: 'ul',
            style: const CSSStyle(
                display: Display.block, margin: EdgeInsets.only(left: 20)),
            children: children);
      case 'ol':
        return RenderNode(
            tagName: 'ol',
            style: const CSSStyle(
                display: Display.block, margin: EdgeInsets.only(left: 20)),
            children: children);
      case 'li':
        return RenderNode(
            tagName: 'li',
            style: const CSSStyle(
                display: Display.block, margin: EdgeInsets.only(left: 20.0)),
            children: children);

      // Checkbox (GFM task list - represented as input type=checkbox in markdown package AST usually?)
      // markdown package uses <input type="checkbox"> for task lists if extension is enabled.
      case 'input':
        if (element.attributes['type'] == 'checkbox') {
          final isChecked = element.attributes.containsKey('checked');
          // Use our new 'checkbox' tag
          return RenderNode(
            tagName: 'checkbox',
            style: const CSSStyle(display: Display.inline), // Inline
            attributes: {'checked': isChecked.toString()},
            // Text not needed for native field logic but keeping consistent
            text: isChecked ? '\u2611' : '\u2610',
          );
        }
        break;

      // Tables
      case 'table':
        return RenderNode(
            tagName: 'table',
            style:
                CSSStyle(display: Display.block, border: Border.all(width: 1)),
            children: children);
      case 'thead':
      case 'tbody':
        return RenderNode(
            tagName: tag,
            style: const CSSStyle(display: Display.block),
            children: children);
      case 'tr':
        return RenderNode(
            tagName: 'tr',
            style: const CSSStyle(display: Display.block),
            children: children);
      case 'th':
        return RenderNode(
            tagName: 'th',
            style: CSSStyle(
                display: Display.block,
                fontWeight: FontWeight.bold,
                border: Border.all(width: 1),
                padding: const EdgeInsets.all(4)),
            children: children);
      case 'td':
        return RenderNode(
            tagName: 'td',
            style: CSSStyle(
                display: Display.block,
                border: Border.all(width: 1),
                padding: const EdgeInsets.all(4)),
            children: children);

      case 'blockquote':
        return RenderNode(
            tagName: 'blockquote',
            style: const CSSStyle(
                display: Display.block,
                margin: EdgeInsets.only(left: 10),
                fontStyle: FontStyle.italic,
                color: Colors.grey),
            children: children);
    }

    // Default fallback
    return RenderNode(
        tagName: tag, style: const CSSStyle(), children: children);
  }
}
