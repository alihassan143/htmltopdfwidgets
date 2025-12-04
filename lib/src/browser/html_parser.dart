import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:pdf/widgets.dart'; // For FontWeight, etc.
import 'package:pdf/pdf.dart'; // For PdfColors

import 'css_style.dart';
import 'render_node.dart';

import '../htmltagstyles.dart';

/// [HtmlParser] parses HTML strings into a tree of [RenderNode]s.
///
/// It handles:
/// - Parsing HTML using the `html` package.
/// - Applying default styles for HTML tags (e.g., h1, p, b).
/// - Parsing inline CSS styles (e.g., `style="color: red"`).
/// - Parsing legacy HTML attributes (e.g., `width="100"`, `align="center"`).
/// - Merging custom [HtmlTagStyle] provided by the user.
class HtmlParser {
  /// The HTML string to parse.
  final String htmlString;

  /// The base style to apply to the root of the document.
  final CSSStyle baseStyle;

  /// Custom styles for specific HTML tags provided by the user.
  final HtmlTagStyle tagStyle;

  /// Creates an instance of [HtmlParser].
  ///
  /// [htmlString] is the HTML content to parse.
  /// [baseStyle] is the default style for the document root.
  /// [tagStyle] allows overriding default styles for specific tags.
  HtmlParser({
    required this.htmlString,
    this.baseStyle = const CSSStyle(
      fontSize: 12.0,
      color: PdfColors.black,
      fontFamily: 'Roboto',
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,
      textDecoration: TextDecoration.none,
    ),
    this.tagStyle = const HtmlTagStyle(),
  });

  /// Parses the HTML string and returns the root [RenderNode].
  RenderNode parse() {
    final document = html_parser.parse(htmlString);
    final body = document.body;

    if (body == null) {
      return RenderNode(tagName: 'body', style: baseStyle);
    }

    return _parseElement(body, baseStyle);
  }

  /// Recursively parses a DOM element into a [RenderNode].
  ///
  /// [element] is the DOM element to parse.
  /// [parentStyle] is the computed style of the parent node, used for inheritance.
  RenderNode _parseElement(dom.Element element, CSSStyle parentStyle) {
    // 1. Get default style for this tag
    final tagDefaultStyle = _getDefaultStyleForTag(element.localName ?? '');
    
    // 2. Parse inline style
    final inlineStyleString = element.attributes['style'] ?? '';
    final inlineStyle = CSSStyle.parse(inlineStyleString);

    // 3. Compute final style: parent -> tagDefault -> inline
    var computedStyle = parentStyle.inheritFrom(parentStyle);
    computedStyle = computedStyle.merge(tagDefaultStyle);

    // 2.1 Map HTML attributes to CSS styles (Legacy compatibility)
    final attributeStyle = _parseAttributesToStyle(element.attributes);
    computedStyle = computedStyle.merge(attributeStyle);

    computedStyle = computedStyle.merge(inlineStyle);

    final children = <RenderNode>[];

    for (var node in element.nodes) {
      if (node is dom.Element) {
        children.add(_parseElement(node, computedStyle));
      } else if (node is dom.Text) {
        final text = node.text.trim();
        if (text.isNotEmpty) {
          children.add(RenderNode(
            tagName: '#text',
            style: computedStyle,
            text: node.text, 
          ));
        }
      }
    }

    return RenderNode(
      tagName: element.localName ?? 'div',
      style: computedStyle,
      attributes: element.attributes.map((key, value) => MapEntry(key.toString(), value)),
      children: children,
    );
  }

  /// Returns the default [CSSStyle] for a given HTML tag.
  ///
  /// This method also applies overrides from [tagStyle].
  CSSStyle _getDefaultStyleForTag(String tagName) {
    CSSStyle style;
    switch (tagName.toLowerCase()) {
      case 'h1':
        style = const CSSStyle(fontSize: 24.0, fontWeight: FontWeight.bold, display: Display.block, margin: EdgeInsets.only(bottom: 8.0));
        if (tagStyle.h1Style != null) style = style.merge(_convertTextStyleToCSSStyle(tagStyle.h1Style!));
        if (tagStyle.headingMargins != null && tagStyle.headingMargins!.containsKey(1)) {
           style = style.merge(CSSStyle(margin: tagStyle.headingMargins![1]));
        }
        return style;
      case 'h2':
        style = const CSSStyle(fontSize: 18.0, fontWeight: FontWeight.bold, display: Display.block, margin: EdgeInsets.only(bottom: 6.0));
        if (tagStyle.h2Style != null) style = style.merge(_convertTextStyleToCSSStyle(tagStyle.h2Style!));
        if (tagStyle.headingMargins != null && tagStyle.headingMargins!.containsKey(2)) {
           style = style.merge(CSSStyle(margin: tagStyle.headingMargins![2]));
        }
        return style;
      case 'h3':
        style = const CSSStyle(fontSize: 16.0, fontWeight: FontWeight.bold, display: Display.block, margin: EdgeInsets.only(bottom: 5.0));
        if (tagStyle.h3Style != null) style = style.merge(_convertTextStyleToCSSStyle(tagStyle.h3Style!));
        if (tagStyle.headingMargins != null && tagStyle.headingMargins!.containsKey(3)) {
           style = style.merge(CSSStyle(margin: tagStyle.headingMargins![3]));
        }
        return style;
      case 'h4':
        style = const CSSStyle(fontSize: 14.0, fontWeight: FontWeight.bold, display: Display.block, margin: EdgeInsets.only(bottom: 4.0));
        if (tagStyle.h4Style != null) style = style.merge(_convertTextStyleToCSSStyle(tagStyle.h4Style!));
        if (tagStyle.headingMargins != null && tagStyle.headingMargins!.containsKey(4)) {
           style = style.merge(CSSStyle(margin: tagStyle.headingMargins![4]));
        }
        return style;
      case 'h5':
        style = const CSSStyle(fontSize: 12.0, fontWeight: FontWeight.bold, display: Display.block, margin: EdgeInsets.only(bottom: 3.0));
        if (tagStyle.h5Style != null) style = style.merge(_convertTextStyleToCSSStyle(tagStyle.h5Style!));
        if (tagStyle.headingMargins != null && tagStyle.headingMargins!.containsKey(5)) {
           style = style.merge(CSSStyle(margin: tagStyle.headingMargins![5]));
        }
        return style;
      case 'h6':
        style = const CSSStyle(fontSize: 10.0, fontWeight: FontWeight.bold, display: Display.block, margin: EdgeInsets.only(bottom: 2.0));
        if (tagStyle.h6Style != null) style = style.merge(_convertTextStyleToCSSStyle(tagStyle.h6Style!));
        if (tagStyle.headingMargins != null && tagStyle.headingMargins!.containsKey(6)) {
           style = style.merge(CSSStyle(margin: tagStyle.headingMargins![6]));
        }
        return style;
      case 'p':
        style = const CSSStyle(display: Display.block, margin: EdgeInsets.only(bottom: 4.0));
        if (tagStyle.paragraphStyle != null) style = style.merge(_convertTextStyleToCSSStyle(tagStyle.paragraphStyle!));
        if (tagStyle.paragraphMargin != null) style = style.merge(CSSStyle(margin: tagStyle.paragraphMargin));
        return style;
      case 'b':
      case 'strong':
        style = const CSSStyle(fontWeight: FontWeight.bold, display: Display.inline);
        if (tagStyle.boldStyle != null) style = style.merge(_convertTextStyleToCSSStyle(tagStyle.boldStyle!));
        return style;
      case 'i':
      case 'em':
        style = const CSSStyle(fontStyle: FontStyle.italic, display: Display.inline);
        if (tagStyle.italicStyle != null) style = style.merge(_convertTextStyleToCSSStyle(tagStyle.italicStyle!));
        return style;
      case 'u':
        return const CSSStyle(textDecoration: TextDecoration.underline, display: Display.inline);
      case 'a':
        style = const CSSStyle(textDecoration: TextDecoration.underline, color: PdfColors.blue, display: Display.inline);
        if (tagStyle.linkStyle != null) style = style.merge(_convertTextStyleToCSSStyle(tagStyle.linkStyle!));
        return style;
      case 'ul':
      case 'ol':
        style = const CSSStyle(display: Display.block, margin: EdgeInsets.only(bottom: 4.0), padding: EdgeInsets.only(left: 20.0));
        if (tagStyle.listMargin != null) style = style.merge(CSSStyle(margin: tagStyle.listMargin));
        return style;
      case 'li':
        return const CSSStyle(display: Display.block);
      case 'div':
        return const CSSStyle(display: Display.block);
      case 'span':
        return const CSSStyle(display: Display.inline);
      case 'blockquote':
        style = const CSSStyle(display: Display.block, margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 20.0), fontStyle: FontStyle.italic);
        if (tagStyle.quoteBarColor != null) {
             // We can't easily pass quoteBarColor to CSSStyle as it's specific to the blockquote border
             // But we can use it for border color if we map it
             style = style.merge(CSSStyle(borderLeft: Border(left: BorderSide(color: tagStyle.quoteBarColor!, width: 3))));
        }
        return style;
      case 'pre':
        style = const CSSStyle(display: Display.block, fontFamily: 'Courier', margin: EdgeInsets.only(bottom: 4.0), backgroundColor: PdfColors.grey200, padding: EdgeInsets.all(8.0));
        if (tagStyle.codeBlockBackgroundColor != null) style = style.merge(CSSStyle(backgroundColor: tagStyle.codeBlockBackgroundColor));
        return style;
      case 'code':
        style = const CSSStyle(display: Display.inline, fontFamily: 'Courier', backgroundColor: PdfColors.grey200);
        if (tagStyle.codeStyle != null) style = style.merge(_convertTextStyleToCSSStyle(tagStyle.codeStyle!));
        if (tagStyle.codeBlockBackgroundColor != null) style = style.merge(CSSStyle(backgroundColor: tagStyle.codeBlockBackgroundColor));
        return style;
      case 'hr':
        style = const CSSStyle(display: Display.block, margin: EdgeInsets.symmetric(vertical: 4.0), borderBottom: Border(bottom: BorderSide(width: 1.0, color: PdfColors.grey400)));
        if (tagStyle.dividerColor != null) style = style.merge(CSSStyle(borderBottom: Border(bottom: BorderSide(width: tagStyle.dividerthickness, color: tagStyle.dividerColor))));
        return style;
      case 'del':
      case 's':
      case 'strike':
        style = const CSSStyle(textDecoration: TextDecoration.lineThrough, display: Display.inline);
        if (tagStyle.strikeThrough != null) style = style.merge(_convertTextStyleToCSSStyle(tagStyle.strikeThrough!));
        return style;
      case 'mark':
        return const CSSStyle(backgroundColor: PdfColors.yellow, display: Display.inline);
      case 'br':
        return const CSSStyle(display: Display.inline); // Handled specially in builder/text
      default:
        return const CSSStyle();
    }
  }

  /// Converts a [TextStyle] to a [CSSStyle].
  CSSStyle _convertTextStyleToCSSStyle(TextStyle textStyle) {
    return CSSStyle(
      color: textStyle.color,
      fontSize: textStyle.fontSize,
      fontWeight: textStyle.fontWeight,
      fontStyle: textStyle.fontStyle,
      textDecoration: textStyle.decoration,
      // fontFamily: textStyle.fontFamily, // Not available in pdf package TextStyle
      // TextStyle doesn't have margin/padding/display, so we only map text properties
    );
  }

  /// Parses HTML attributes (width, height, align, border, bgcolor, color) into CSSStyle.
  /// This provides compatibility with legacy HTML that uses attributes instead of CSS.
  CSSStyle _parseAttributesToStyle(Map<Object, String> attributes) {
    double? width;
    double? height;
    TextAlign? textAlign;
    Border? border;
    PdfColor? backgroundColor;
    PdfColor? color;

    // Parse width attribute
    final widthAttr = attributes['width'];
    if (widthAttr != null) {
      // Handle percentage widths (we'll just parse the number for now)
      final widthValue = widthAttr.replaceAll('%', '').replaceAll('px', '');
      width = double.tryParse(widthValue);
    }

    // Parse height attribute
    final heightAttr = attributes['height'];
    if (heightAttr != null) {
      final heightValue = heightAttr.replaceAll('%', '').replaceAll('px', '');
      height = double.tryParse(heightValue);
    }

    // Parse align attribute
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

    // Parse border attribute (used in tables)
    final borderAttr = attributes['border'];
    if (borderAttr != null) {
      final borderWidth = double.tryParse(borderAttr) ?? 1.0;
      if (borderWidth > 0) {
        border = Border.all(width: borderWidth, color: PdfColors.black);
      }
    }

    // Parse bgcolor attribute
    final bgcolorAttr = attributes['bgcolor'];
    if (bgcolorAttr != null) {
      backgroundColor = _parseColorValue(bgcolorAttr);
    }

    // Parse color attribute
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

  /// Parses a color value (hex, named colors, rgb/rgba)
  PdfColor? _parseColorValue(String value) {
    final trimmed = value.trim().toLowerCase();
    
    // Handle hex colors
    if (trimmed.startsWith('#')) {
      return PdfColor.fromHex(trimmed);
    }
    
    // Handle rgb/rgba
    if (trimmed.startsWith('rgb')) {
      final match = RegExp(r'rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)').firstMatch(trimmed);
      if (match != null) {
        final r = int.tryParse(match.group(1) ?? '0') ?? 0;
        final g = int.tryParse(match.group(2) ?? '0') ?? 0;
        final b = int.tryParse(match.group(3) ?? '0') ?? 0;
        final a = double.tryParse(match.group(4) ?? '1') ?? 1.0;
        return PdfColor(r / 255, g / 255, b / 255, a);
      }
    }
    
    // Handle named colors
    switch (trimmed) {
      case 'red': return PdfColors.red;
      case 'green': return PdfColors.green;
      case 'blue': return PdfColors.blue;
      case 'black': return PdfColors.black;
      case 'white': return PdfColors.white;
      case 'grey': case 'gray': return PdfColors.grey;
      case 'yellow': return PdfColors.yellow;
      case 'cyan': return PdfColors.cyan;
      case 'magenta': case 'purple': return PdfColors.purple;
      case 'orange': return PdfColors.orange;
      case 'pink': return PdfColors.pink;
      case 'brown': return PdfColors.brown;
      case 'lime': return PdfColors.lime;
      case 'teal': return PdfColors.teal;
      case 'indigo': return PdfColors.indigo;
      case 'navy': return PdfColors.blueGrey800;
      case 'maroon': return PdfColors.red800;
      case 'olive': return PdfColors.lime800;
      case 'aqua': return PdfColors.cyan;
      case 'fuchsia': return PdfColors.pink;
      case 'silver': return PdfColors.grey400;
      default: return null;
    }
  }
}
