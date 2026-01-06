import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart' as css;
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../htmltagstyles.dart';
import 'css_style.dart';
import 'render_node.dart';

/// [HtmlParser] parses HTML strings into a tree of [RenderNode]s.
class HtmlParser {
  /// The HTML string to parse.
  final String htmlString;

  /// The base style to apply to the root of the document.
  final CSSStyle baseStyle;

  /// Custom styles for specific HTML tags provided by the user.
  final HtmlTagStyle tagStyle;

  /// Parsed CSS rules from <style> tags
  final List<css.RuleSet> _styleRules = [];

  HtmlParser({
    required this.htmlString,
    this.baseStyle = const CSSStyle(
      fontSize: 12.0,
      fontFamily: 'Roboto',
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,
      textDecoration: TextDecoration.none,
    ),
    this.tagStyle = const HtmlTagStyle(),
  });

  RenderNode parse() {
    final document = html_parser.parse(htmlString);
    _parseStyleTags(document);

    final body = document.body;
    if (body == null) {
      return RenderNode(tagName: 'body', style: baseStyle);
    }

    return _parseElement(body, baseStyle);
  }

  void _parseStyleTags(dom.Document document) {
    final styleTags = document.getElementsByTagName('style');
    for (var styleTag in styleTags) {
      if (styleTag.text.isNotEmpty) {
        try {
          final stylesheet = css_parser.parse(styleTag.text);
          for (var rule in stylesheet.topLevels) {
            if (rule is css.RuleSet) {
              _styleRules.add(rule);
            }
          }
        } catch (e) {
          debugPrint('Error parsing CSS: $e');
        }
      }
    }
  }

  RenderNode _parseElement(dom.Element element, CSSStyle parentStyle) {
    // Check for table first as it requires specific parsing
    if (element.localName == 'table') {
      return _parseTable(element, parentStyle);
    }

    // 1. Get default style for this tag
    final tagDefaultStyle = _getDefaultStyleForTag(element.localName ?? '');

    // 2. Parse inline style
    final inlineStyleString = element.attributes['style'] ?? '';
    final inlineStyle = CSSStyle.parse(inlineStyleString);

    // 3. Compute final style
    var computedStyle = parentStyle.inheritFrom(parentStyle);
    computedStyle = computedStyle.merge(tagDefaultStyle);

    // 3.1 Apply matched CSS rules
    final matchedRules = _matchRules(element);
    for (var declarationGroup in matchedRules) {
      final ruleStyle = _styleFromDeclaration(declarationGroup);
      computedStyle = computedStyle.merge(ruleStyle);
    }

    // 3.2 Map HTML attributes to CSS styles
    final attributeStyle = _parseAttributesToStyle(element.attributes);
    computedStyle = computedStyle.merge(attributeStyle);
    computedStyle = computedStyle.merge(inlineStyle);

    final children = <RenderNode>[];

    // Create inherited style for children (only keeping inheritable properties)
    final inheritedStyle = _getInheritedStyle(computedStyle);

    for (var node in element.nodes) {
      if (node is dom.Element) {
        if (node.localName == 'br') {
          // br should be inline
          // We can merge a specific style for br if needed, but inherited is fine + RenderNode default is inline
          // Actually br has no text, so inherited style matters less, but display should NOT be block.
          children.add(RenderNode(tagName: 'br', style: inheritedStyle));
        } else if (node.localName == 'input' &&
            node.attributes['type'] == 'checkbox') {
          // Handle checkbox
          // Force inline display
          var checkboxStyle =
              inheritedStyle.merge(const CSSStyle(display: Display.inline));
          final isChecked = node.attributes.containsKey('checked');
          children.add(RenderNode(
            tagName: 'checkbox', // Custom tag for renderer to handle
            style: checkboxStyle,
            attributes: {'checked': isChecked.toString()},
            text: isChecked ? '\u2611' : '\u2610', // Unicode checkboxes
          ));
        } else {
          // For other elements, recursively parse with inherited style
          children.add(_parseElement(node, inheritedStyle));
        }
      } else if (node is dom.Text) {
        var text = node.text;
        if (text.isNotEmpty) {
          // Don't sanitize rigorously here if we want to preserve whitespace for 'pre' tags
          // But 'pre' style should handle whitespace display.
          // For now, simple sanitization
          text = _sanitizeText(text);
          children.add(RenderNode(
            tagName: '#text',
            style:
                inheritedStyle, // Use inherited style, so it doesn't get parent's border/block
            text: text,
          ));
        }
      }
    }

    return RenderNode(
      tagName: element.localName ?? 'div',
      style: computedStyle,
      attributes: element.attributes
          .map((key, value) => MapEntry(key.toString(), value)),
      children: children,
    );
  }

  RenderNode _parseTable(dom.Element element, CSSStyle parentStyle) {
    // Base style for table
    var style = parentStyle.merge(_getDefaultStyleForTag('table'));

    // Parse style attribute
    final inlineStyleString = element.attributes['style'] ?? '';
    final inlineStyle = CSSStyle.parse(inlineStyleString);
    style = style.merge(inlineStyle);

    // Handle border attribute on table
    if (element.attributes.containsKey('border')) {
      final borderVal =
          double.tryParse(element.attributes['border'] ?? '0') ?? 0;
      if (borderVal > 0) {
        style = style.merge(CSSStyle(border: Border.all(width: borderVal)));
      }
    }

    final children = <RenderNode>[];

    // Helper to process rows
    void processRows(dom.Element section) {
      for (var row in section.children) {
        if (row.localName == 'tr') {
          children.add(_parseTableRow(row, style));
        }
      }
    }

    for (final child in element.children) {
      if (child.localName == 'thead' ||
          child.localName == 'tbody' ||
          child.localName == 'tfoot') {
        processRows(child);
      } else if (child.localName == 'tr') {
        children.add(_parseTableRow(child, style));
      }
    }

    return RenderNode(
      tagName: 'table',
      style: style,
      attributes: element.attributes
          .map((key, value) => MapEntry(key.toString(), value)),
      children: children,
    );
  }

  RenderNode _parseTableRow(dom.Element row, CSSStyle tableStyle) {
    // Row style
    var style = tableStyle;
    final inlineStyleString = row.attributes['style'] ?? '';
    style = style.merge(CSSStyle.parse(inlineStyleString));

    final children = <RenderNode>[];

    for (var cell in row.children) {
      if (cell.localName == 'td' || cell.localName == 'th') {
        children.add(
            _parseTableCell(cell, style, isHeader: cell.localName == 'th'));
      }
    }

    return RenderNode(
      tagName: 'tr',
      style: style,
      attributes:
          row.attributes.map((key, value) => MapEntry(key.toString(), value)),
      children: children,
    );
  }

  RenderNode _parseTableCell(dom.Element cell, CSSStyle rowStyle,
      {bool isHeader = false}) {
    var style = rowStyle;
    if (isHeader) {
      style = style.merge(const CSSStyle(fontWeight: FontWeight.bold));
    }

    final inlineStyleString = cell.attributes['style'] ?? '';
    final inlineStyle = CSSStyle.parse(inlineStyleString);
    style = style.merge(inlineStyle);

    // Handle properties like colspan/rowspan via attributes map
    final attributes =
        cell.attributes.map((key, value) => MapEntry(key.toString(), value));

    // Parse children normally
    final children = <RenderNode>[];
    for (var node in cell.nodes) {
      if (node is dom.Element) {
        if (node.localName == 'br') {
          children.add(RenderNode(tagName: 'br', style: style));
        } else {
          children.add(_parseElement(node, style));
        }
      } else if (node is dom.Text) {
        var text = node.text;
        if (text.isNotEmpty) {
          text = _sanitizeText(text);
          children.add(RenderNode(tagName: '#text', style: style, text: text));
        }
      }
    }

    return RenderNode(
      tagName: isHeader ? 'th' : 'td',
      style: style,
      attributes: attributes,
      children: children,
    );
  }

  String _sanitizeText(String text) {
    return text
        .replaceAll('\u2011', '-')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u200B', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\u202F', ' ')
        .replaceAll('\uFEFF', '');
  }

  CSSStyle _getDefaultStyleForTag(String tagName) {
    CSSStyle style;
    switch (tagName.toLowerCase()) {
      case 'h1':
        style = const CSSStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
            display: Display.block,
            margin: EdgeInsets.only(bottom: 8.0));
        if (tagStyle.h1Style != null) {
          style = style.merge(_convertTextStyleToCSSStyle(tagStyle.h1Style!));
        }
        return style;
      case 'h2':
        style = const CSSStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            display: Display.block,
            margin: EdgeInsets.only(bottom: 6.0));
        if (tagStyle.h2Style != null) {
          style = style.merge(_convertTextStyleToCSSStyle(tagStyle.h2Style!));
        }
        return style;
      case 'h3':
        style = const CSSStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            display: Display.block,
            margin: EdgeInsets.only(bottom: 5.0));
        if (tagStyle.h3Style != null) {
          style = style.merge(_convertTextStyleToCSSStyle(tagStyle.h3Style!));
        }
        return style;
      case 'h4':
        style = const CSSStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
            display: Display.block,
            margin: EdgeInsets.only(bottom: 4.0));
        if (tagStyle.h4Style != null) {
          style = style.merge(_convertTextStyleToCSSStyle(tagStyle.h4Style!));
        }
        return style;
      case 'h5':
        style = const CSSStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            display: Display.block,
            margin: EdgeInsets.only(bottom: 3.0));
        if (tagStyle.h5Style != null) {
          style = style.merge(_convertTextStyleToCSSStyle(tagStyle.h5Style!));
        }
        return style;
      case 'h6':
        style = const CSSStyle(
            fontSize: 10.0,
            fontWeight: FontWeight.bold,
            display: Display.block,
            margin: EdgeInsets.only(bottom: 2.0));
        if (tagStyle.h6Style != null) {
          style = style.merge(_convertTextStyleToCSSStyle(tagStyle.h6Style!));
        }
        return style;
      case 'p':
        style = const CSSStyle(
            display: Display.block, margin: EdgeInsets.only(bottom: 4.0));
        if (tagStyle.paragraphStyle != null) {
          style = style
              .merge(_convertTextStyleToCSSStyle(tagStyle.paragraphStyle!));
        }
        return style;
      case 'b':
      case 'strong':
        style = const CSSStyle(
            fontWeight: FontWeight.bold, display: Display.inline);
        if (tagStyle.boldStyle != null) {
          style = style.merge(_convertTextStyleToCSSStyle(tagStyle.boldStyle!));
        }
        return style;
      case 'i':
      case 'em':
        style = const CSSStyle(
            fontStyle: FontStyle.italic, display: Display.inline);
        if (tagStyle.italicStyle != null) {
          style =
              style.merge(_convertTextStyleToCSSStyle(tagStyle.italicStyle!));
        }
        return style;
      case 'u':
        return const CSSStyle(
            textDecoration: TextDecoration.underline, display: Display.inline);
      case 'a':
        style = const CSSStyle(
            textDecoration: TextDecoration.underline,
            color: Colors.blue,
            display: Display.inline);
        if (tagStyle.linkStyle != null) {
          style = style.merge(_convertTextStyleToCSSStyle(tagStyle.linkStyle!));
        }
        return style;
      case 'ul':
      case 'ol':
        style = const CSSStyle(
            display: Display.block,
            margin: EdgeInsets.only(bottom: 4.0),
            padding: EdgeInsets.only(left: 20.0));
        return style;
      case 'li':
        return const CSSStyle(display: Display.block);
      case 'div':
      case 'header':
      case 'footer':
      case 'main':
      case 'nav':
      case 'section':
      case 'article':
      case 'aside':
        return const CSSStyle(display: Display.block);
      case 'span':
        return const CSSStyle(display: Display.inline);
      case 'blockquote':
        style = const CSSStyle(
            display: Display.block,
            margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 20.0),
            fontStyle: FontStyle.italic);
        return style;
      case 'pre':
        style = const CSSStyle(
            display: Display.block,
            fontFamily: 'Courier',
            margin: EdgeInsets.only(bottom: 4.0),
            backgroundColor: Color(0xFFEEEEEE),
            padding: EdgeInsets.all(8.0));
        return style;
      case 'code':
        return const CSSStyle(
            display: Display.inline,
            fontFamily: 'Courier',
            backgroundColor: Color(0xFFEEEEEE));
      case 'hr':
        return const CSSStyle(
            display: Display.block,
            margin: EdgeInsets.symmetric(vertical: 4.0),
            borderBottom: BorderSide(width: 1.0, color: Color(0xFFBDBDBD)));
      case 'del':
      case 's':
      case 'strike':
        return const CSSStyle(
            textDecoration: TextDecoration.lineThrough,
            display: Display.inline);
      case 'img':
        return const CSSStyle(
            display: Display.block, margin: EdgeInsets.only(bottom: 4.0));
      case 'sup':
        return const CSSStyle(
          fontSize: 10.0, // Slightly smaller
          display: Display.inline,
          verticalAlign: VerticalAlign
              .top, // Logic to be handled in renderer for superscripts
        );
      case 'sub':
        return const CSSStyle(
          fontSize: 10.0,
          display: Display.inline,
          verticalAlign: VerticalAlign.bottom,
        );
      case 'mark':
        return const CSSStyle(
            backgroundColor: Colors.yellow, display: Display.inline);
      default:
        return const CSSStyle();
    }
  }

  CSSStyle _convertTextStyleToCSSStyle(TextStyle textStyle) {
    return CSSStyle(
      color: textStyle.color,
      fontSize: textStyle.fontSize,
      fontWeight: textStyle.fontWeight,
      fontStyle: textStyle.fontStyle,
      textDecoration: textStyle.decoration,
    );
  }

  CSSStyle _parseAttributesToStyle(Map<Object, String> attributes) {
    double? width;
    double? height;
    TextAlign? textAlign;
    Border? border;
    Color? backgroundColor;
    Color? color;

    final widthAttr = attributes['width'];
    if (widthAttr != null) {
      final widthValue = widthAttr.replaceAll('%', '').replaceAll('px', '');
      width = double.tryParse(widthValue);
    }

    final heightAttr = attributes['height'];
    if (heightAttr != null) {
      final heightValue = heightAttr.replaceAll('%', '').replaceAll('px', '');
      height = double.tryParse(heightValue);
    }

    final alignAttr = attributes['align'];
    if (alignAttr != null) {
      switch (alignAttr.toLowerCase()) {
        case 'left':
          textAlign = TextAlign.left;
          break;
        case 'right':
          textAlign = TextAlign.right;
          break;
        case 'center':
          textAlign = TextAlign.center;
          break;
        case 'justify':
          textAlign = TextAlign.justify;
          break;
      }
    }

    final borderAttr = attributes['border'];
    if (borderAttr != null) {
      final borderWidth = double.tryParse(borderAttr) ?? 1.0;
      if (borderWidth > 0) {
        border = Border.all(width: borderWidth, color: Colors.black);
      }
    }

    final bgcolorAttr = attributes['bgcolor'];
    if (bgcolorAttr != null) {
      backgroundColor = _parseColorValue(bgcolorAttr);
    }

    final colorAttr = attributes['color'];
    if (colorAttr != null) {
      color = _parseColorValue(colorAttr);
    }

    return CSSStyle(
      width: width,
      height: height,
      textAlign: textAlign,
      border: border,
      backgroundColor: backgroundColor,
      color: color,
    );
  }

  // Delegating to CSSStyle.parse logic internally or just using a helper
  // Since CSSStyle._parseColor is private, and I can't easily change it to public without re-reading the file (I already did, but it's private in the file I just wrote),
  // I will just use CSSStyle.parse for colors by constructing a fake CSS string or just accept that attributes are legacy.
  // Actually, I can duplicate the color parsing logic or just rely on CSSStyle.parse("color: $value").color
  Color? _parseColorValue(String value) {
    return CSSStyle.parse('color: $value').color;
  }

  List<css.DeclarationGroup> _matchRules(dom.Element element) {
    final matchedDeclarations = <css.DeclarationGroup>[];
    for (var ruleSet in _styleRules) {
      for (var selectorGroup in ruleSet.selectorGroup!.selectors) {
        if (_matchesSelector(element, selectorGroup)) {
          matchedDeclarations.add(ruleSet.declarationGroup);
          break;
        }
      }
    }
    return matchedDeclarations;
  }

  bool _matchesSelector(dom.Element element, css.Selector selector) {
    for (var simpleSelector in selector.simpleSelectorSequences) {
      if (!_matchesSimpleSelector(element, simpleSelector.simpleSelector)) {
        return false;
      }
    }
    return true;
  }

  bool _matchesSimpleSelector(
      dom.Element element, css.SimpleSelector selector) {
    if (selector is css.ElementSelector) {
      return selector.name.toLowerCase() == element.localName?.toLowerCase();
    } else if (selector is css.ClassSelector) {
      return element.classes.contains(selector.name);
    } else if (selector is css.IdSelector) {
      return element.id == selector.name;
    }
    return false;
  }

  CSSStyle _styleFromDeclaration(css.DeclarationGroup declarationGroup) {
    var style = const CSSStyle();
    for (var declaration in declarationGroup.declarations) {
      if (declaration is css.Declaration) {
        final property = declaration.property;
        final value = declaration.expression;
        if (value is css.Expressions) {
          style = style.merge(_cssPropertyToStyle(property, value));
        }
      }
    }
    return style;
  }

  CSSStyle _cssPropertyToStyle(String property, css.Expressions value) {
    String getValueText() {
      return value.expressions.map((e) {
        if (e is css.LiteralTerm) return e.text;
        if (e is css.NumberTerm) return e.text;
        if (e is css.HexColorTerm) return '#${e.text}';
        return e.toString();
      }).join(' ');
    }

    final textValue = getValueText();
    return CSSStyle.parse('$property: $textValue');
  }

  CSSStyle _getInheritedStyle(CSSStyle style) {
    return CSSStyle(
      color: style.color,
      fontFamily: style.fontFamily,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      textAlign: style.textAlign,
      textDecoration: style.textDecoration,
      textDirection: style.textDirection,
      verticalAlign: style.verticalAlign,
    );
  }
}
