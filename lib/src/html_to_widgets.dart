import 'dart:collection';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:htmltopdfwidgets/src/attributes.dart';
import 'package:htmltopdfwidgets/src/extension/int_extensions.dart';
import 'package:http/http.dart';

import '../htmltopdfwidgets.dart';
import 'extension/color_extension.dart';
import 'html_tags.dart';
import 'pdfwidgets/bullet_list.dart';
import 'pdfwidgets/number_list.dart';
import 'pdfwidgets/quote_widget.dart';

//html deocoder that deocde html and convert it into pdf widgets
class WidgetsHTMLDecoder {
  //default font font the pdf if it not provided custo
  // Constructor for the HTML decoder
  final Font? font; // Font for the PDF, if not provided, use default
  final HtmlTagStyle customStyles; // Custom styles for HTML tags
  final List<Font> fontFallback; // Fallback fonts
  const WidgetsHTMLDecoder({
    this.font,
    required this.fontFallback,
    this.customStyles = const HtmlTagStyle(),
  });

  /// The class takes an HTML string as input and returns a list of Widgets. The Widgets
  /// are created based on the tags and attributes in the HTML string.
  Future<List<Widget>> convert(String html) async {
    // Parse the HTML document using the html package
    final document = parse(html);
    final body = document.body;
    if (body == null) {
      return [];
    }
    // Call the private _parseElement function to process the HTML nodes
    List<Widget> nodes = await _parseElement(body.nodes);

    return nodes;
  }

  /// Converts the given HTML string to a list of Widgets.
  /// and returns the list of widgets

  Future<List<Widget>> _parseElement(
    Iterable<dom.Node> domNodes,
  ) async {
    final List<Widget> delta = [];
    final result = <Widget>[];
    //find dom node in and check if its element or not than convert it according to its specs
    for (final domNode in domNodes) {
      if (domNode is dom.Element) {
        final localName = domNode.localName;
        // Check if the element is a simple formatting element like <span>, <bold>, or <italic>
        if (HTMLTags.formattingElements.contains(localName)) {
          final attributes = await _parserFormattingElementAttributes(domNode);

          result.add(Text(domNode.text, style: attributes));
        } else if (HTMLTags.specialElements.contains(localName)) {
          // Handle special elements (e.g., headings, lists, images)
          result.addAll(
            await _parseSpecialElements(
              domNode,
              type: BuiltInAttributeKey.bulletedList,
            ),
          );
        }
      } else if (domNode is dom.Text) {
        // Process text nodes and add them to delta
        delta.add(Text(domNode.text,
            style: TextStyle(font: font, fontFallback: fontFallback)));
      } else {
        assert(false, 'Unknown node type: $domNode');
      }
    }
    // If there are text nodes in delta, wrap them in a Wrap widget and add to the result
    if (delta.isNotEmpty) {
      result.add(Wrap(children: delta));
    }
    return result;
  }

  // Function to parse special HTML elements (e.g., headings, lists, images)
  Future<Iterable<Widget>> _parseSpecialElements(
    dom.Element element, {
    required String type,
  }) async {
    final localName = element.localName;
    switch (localName) {
      // Handle heading level 1
      case HTMLTags.h1:
        return [await _parseHeadingElement(element, level: 1)];
      // Handle heading level 2
      case HTMLTags.h2:
        return [await _parseHeadingElement(element, level: 2)];
      // Handle heading level 3
      case HTMLTags.h3:
        return [await _parseHeadingElement(element, level: 3)];
      // Handle heading level 4
      case HTMLTags.h4:
        return [await _parseHeadingElement(element, level: 4)];
      // Handle heading level 5
      case HTMLTags.h5:
        return [await _parseHeadingElement(element, level: 5)];
      // Handle heading level 6
      case HTMLTags.h6:
        return [await _parseHeadingElement(element, level: 6)];
      // Handle unorder list
      case HTMLTags.unorderedList:
        return await _parseUnOrderListElement(element);
      // Handle ordered list and converts its childrens to widgets
      case HTMLTags.orderedList:
        return await _parseOrderListElement(element);
      case HTMLTags.table:
        return await _parseTable(element);
      //if simple list is found it will handle accoridingly
      case HTMLTags.list:
        return await _parseListElement(
          element,
          type: type,
        );
      // it handles the simple paragraph element
      case HTMLTags.paragraph:
        return [await _parseParagraphElement(element)];
      // Handle block quote tag
      case HTMLTags.blockQuote:
        return await _parseBlockQuoteElement(element);
      // Handle the image tag
      case HTMLTags.image:
        return [await _parseImageElement(element)];
      // Handle the line break tag
      case HTMLTags.br:
        return [Text("\n")];
      // if no special element is found it treated as simple parahgraph
      default:
        return [await _parseParagraphElement(element)];
    }
  }

  Text paragraphNode({required String text}) {
    return Text(text);
  }

  /// Parses the attributes of a formatting element and returns a TextStyle.
  Future<TextStyle> _parserFormattingElementAttributes(
      dom.Element element) async {
    final localName = element.localName;

    TextStyle attributes = TextStyle(fontFallback: fontFallback, font: font);
    final List<TextDecoration> decoration = [];
    switch (localName) {
      // Handle <bold> element
      case HTMLTags.bold:
        attributes = attributes.copyWith(fontWeight: FontWeight.bold)
          ..merge(customStyles.boldStyle);
        break;
      // Handle <strong> element
      case HTMLTags.strong:
        attributes = attributes.copyWith(fontWeight: FontWeight.bold)
          ..merge(customStyles.boldStyle);
        break;
      // Handle <em> element
      case HTMLTags.em:
        attributes = attributes.copyWith(fontStyle: FontStyle.italic)
          ..merge(customStyles.italicStyle);
        break;
      // Handle <italic> element
      case HTMLTags.italic:
        attributes = attributes.copyWith(fontStyle: FontStyle.italic)
          ..merge(customStyles.italicStyle);
        break;
      // Handle <u> element
      case HTMLTags.underline:
        decoration.add(TextDecoration.underline);
        break;
      // Handle <del> element
      case HTMLTags.del:
        decoration.add(TextDecoration.lineThrough);

        break;
      // Handle <span> element
      case HTMLTags.span:
        final deltaAttributes = _getDeltaAttributesFromHtmlAttributes(
          element.attributes,
        );
        attributes = attributes.merge(deltaAttributes);
        if (deltaAttributes.decoration != null) {
          decoration.add(deltaAttributes.decoration!);
        }
        break;
      // Handle <a> element
      case HTMLTags.anchor:
        final href = element.attributes['href'];
        if (href != null) {
          decoration.add(
            TextDecoration.underline,
          );
          attributes = attributes.copyWith(color: PdfColors.blue)
            ..merge(customStyles.linkStyle);
        }
        break;
      // Handle <p> element for additional safety
      case HTMLTags.paragraph:
        attributes = attributes..merge(customStyles.paragraphStyle);
        break;
      // Handle <code> element
      case HTMLTags.code:
        attributes = attributes.copyWith(
            background: const BoxDecoration(color: PdfColors.red))
          ..merge(customStyles.codeStyle);
        break;
      default:
        break;
    }

    for (final child in element.children) {
      final nattributes = await _parserFormattingElementAttributes(child);
      attributes = attributes.merge(nattributes);
      if (nattributes.decoration != null) {
        decoration.add(nattributes.decoration!);
      }
    }
//will combine style get from the children
    return attributes.copyWith(decoration: TextDecoration.combine(decoration));
  }

  Future<Iterable<Widget>> _parseTable(dom.Element element) async {
    final List<TableRow> tablenodes = [];

    for (final data in element.children) {
      final rwdata = await _parsetableRows(data);

      tablenodes.addAll(rwdata);
    }

    return [
      Table(
          border: TableBorder.all(color: PdfColors.black),
          children: tablenodes),
    ];
  }

  Future<List<TableRow>> _parsetableRows(dom.Element element) async {
    final List<TableRow> nodes = [];

    for (final data in element.children) {
      final tabledata = await _parsetableData(data);

      nodes.add(tabledata);
    }
    return nodes;
  }

  Future<TableRow> _parsetableData(
    dom.Element element,
  ) async {
    final List<Widget> nodes = [];

    for (final data in element.children) {
      if (data.children.isEmpty) {
        final node = paragraphNode(text: data.text);

        nodes.add(node);
      } else {
        final newnodes = await _parseTableSpecialNodes(data);

        nodes.addAll(newnodes);
      }
    }

    return TableRow(
        decoration: BoxDecoration(border: Border.all(color: PdfColors.black)),
        children: nodes);
  }

  Future<Iterable<Widget>> _parseTableSpecialNodes(dom.Element element) async {
    final List<Widget> nodes = [];

    if (element.children.isNotEmpty) {
      for (final childrens in element.children) {
        nodes.addAll(await _parseTableDataElementsData(childrens));
      }
    } else {
      nodes.addAll(await _parseTableDataElementsData(element));
    }
    return nodes;
  }

  Future<List<Widget>> _parseTableDataElementsData(dom.Element element) async {
    final List<Widget> delta = [];
    final result = <Widget>[];
    //find dom node in and check if its element or not than convert it according to its specs

    final localName = element.localName;
    // Check if the element is a simple formatting element like <span>, <bold>, or <italic>
    if (HTMLTags.formattingElements.contains(localName)) {
      final attributes = await _parserFormattingElementAttributes(element);

      result.add(Text(element.text, style: attributes));
    } else if (HTMLTags.specialElements.contains(localName)) {
      // Handle special elements (e.g., headings, lists, images)
      result.addAll(
        await _parseSpecialElements(
          element,
          type: BuiltInAttributeKey.bulletedList,
        ),
      );
    } else if (element is dom.Text) {
      // Process text nodes and add them to delta
      delta.add(Text(element.text,
          style: TextStyle(font: font, fontFallback: fontFallback)));
    } else {
      assert(false, 'Unknown node type: $element');
    }

    // If there are text nodes in delta, wrap them in a Wrap widget and add to the result
    if (delta.isNotEmpty) {
      result.add(Wrap(children: delta));
    }
    return result;
  }

  // Function to parse a heading element and return a RichText widget
  Future<Widget> _parseHeadingElement(
    dom.Element element, {
    required int level,
  }) async {
    final delta = <TextSpan>[];
    final children = element.nodes.toList();
    for (final child in children) {
      if (child is dom.Element) {
        final attributes = await _parserFormattingElementAttributes(child);
        delta.add(TextSpan(text: child.text, style: attributes));
      } else {
        delta.add(TextSpan(
            text: child.text,
            style: TextStyle(font: font, fontFallback: fontFallback)));
      }
    }
    // Return a RichText widget with the parsed text and styles
    return RichText(
        text: TextSpan(
            children: delta,
            style: TextStyle(
                fontSize: level.getHeadingSize, fontWeight: FontWeight.bold)
              ..merge(level.getHeadingStyle(customStyles))));
  }

// Function to parse a block quote element and return a list of widgets
  Future<List<Widget>> _parseBlockQuoteElement(dom.Element element) async {
    final result = <Widget>[];
    for (final child in element.children) {
      result.addAll(
          await _parseListElement(child, type: BuiltInAttributeKey.quote));
    }
    return result;
  }

// Function to parse an unordered list element and return a list of widgets
  Future<Iterable<Widget>> _parseUnOrderListElement(dom.Element element) async {
    final result = <Widget>[];
    for (final child in element.children) {
      result.addAll(await _parseListElement(child,
          type: BuiltInAttributeKey.bulletedList));
    }
    return result;
  }

  // Function to parse an ordered list element and return a list of widgets
  Future<Iterable<Widget>> _parseOrderListElement(dom.Element element) async {
    final result = <Widget>[];
    for (var i = 0; i < element.children.length; i++) {
      final child = element.children[i];
      result.addAll(await _parseListElement(child,
          type: BuiltInAttributeKey.numberList, index: i + 1));
    }
    return result;
  }

  // Function to parse a list element (unordered or ordered) and return a list of widgets
  Future<Iterable<Widget>> _parseListElement(
    dom.Element element, {
    required String type,
    int? index,
  }) async {
    final delta = await _parseDeltaElement(element);
    // Build a bullet list widget
    if (type == BuiltInAttributeKey.bulletedList) {
      return [buildBulletwidget(delta, customStyles: customStyles)];
      // Build a numbered list widget
    } else if (type == BuiltInAttributeKey.numberList) {
      return [
        buildNumberwdget(delta,
            index: index!,
            customStyles: customStyles,
            font: font,
            fontFallback: fontFallback)
      ];
      // Build a quote  widget
    } else if (type == BuiltInAttributeKey.quote) {
      return [buildQuotewidget(delta, customStyles: customStyles)];
    } else {
      return [delta];
    }
  }

  // Function to parse a paragraph element and return a widget
  Future<Widget> _parseParagraphElement(dom.Element element) async {
    final delta = await _parseDeltaElement(element);
    return delta;
  }

// Function to parse an image element and download image as bytes  and return an Image widget
  Future<Widget> _parseImageElement(dom.Element element) async {
    final src = element.attributes["src"];
    try {
      if (src != null) {
        final netImage = await _saveImage(src);
        return Image(MemoryImage(netImage),
            alignment: customStyles.imageAlignment);
      } else {
        return Text("");
      }
    } catch (e) {
      return Text("");
    }
  }

// Function to download and save an image from a URL
  Future<Uint8List> _saveImage(String url) async {
    try {
      // Download image
      final Response response = await get(Uri.parse(url));

      // Get temporary directory

      return response.bodyBytes;
    } catch (e) {
      throw Exception(e);
    }
  }

  // Function to parse a complex HTML element and return a widget
  Future<Widget> _parseDeltaElement(dom.Element element) async {
    final delta = <Widget>[];
    final children = element.nodes.toList();
    final childNodes = <Widget>[];
    for (final child in children) {
      // Recursively parse child elements
      if (child is dom.Element) {
        if (child.children.isNotEmpty) {
          childNodes.addAll(await _parseElement(child.children));
        } else {
          // Handle special elements (e.g., headings, lists) within a paragraph
          if (HTMLTags.specialElements.contains(child.localName)) {
            childNodes.addAll(
              await _parseSpecialElements(
                child,
                type: BuiltInAttributeKey.bulletedList,
              ),
            );
          } else {
            // Parse text and attributes within the paragraph
            final attributes = await _parserFormattingElementAttributes(child)
              ..merge(customStyles.paragraphStyle);
            delta.add(Text(child.text, style: attributes));
          }
        }
      } else {
        // Process text nodes and add them to delta variable
        delta.add(Text(child.text ?? "",
            style: TextStyle(font: font, fontFallback: fontFallback)
              ..merge(customStyles.paragraphStyle)));
      }
    }
    // Create a column with wrapped text and child nodes
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Wrap(children: delta), ...childNodes]);
  }

  // Utility function to convert a CSS string to a map of CSS properties
  static Map<String, String> _cssStringToMap(String? cssString) {
    final result = <String, String>{};
    if (cssString == null) {
      return result;
    }
// Split the CSS string into key-value pairs and add them to the result map
    final entries = cssString.split(";");
    for (final entry in entries) {
      final tuples = entry.split(":");
      if (tuples.length < 2) {
        continue;
      }
      result[tuples[0].trim()] = tuples[1].trim();
    }

    return result;
  }

// Function to extract text styles from HTML attributes
  TextStyle _getDeltaAttributesFromHtmlAttributes(
      LinkedHashMap<Object, String> htmlAttributes) {
    TextStyle style = const TextStyle();
    //extract styls from the inline css
    final styleString = htmlAttributes["style"];
    final cssMap = _cssStringToMap(styleString);
//get font weight
    final fontWeightStr = cssMap["font-weight"];
    if (fontWeightStr != null) {
      if (fontWeightStr == "bold") {
        style = style.copyWith(fontWeight: FontWeight.bold)
          ..merge(customStyles.boldStyle);
      } else {
        int? weight = int.tryParse(fontWeightStr);
        if (weight != null && weight > 500) {
          style = style.copyWith(fontWeight: FontWeight.bold)
            ..merge(customStyles.boldStyle);
        }
      }
    }
//apply different text decorations like undrline line through
    final textDecorationStr = cssMap["text-decoration"];
    if (textDecorationStr != null) {
      style = style.merge(_assignTextDecorations(style, textDecorationStr));
    }
//apply background color on text
    final backgroundColorStr = cssMap["background-color"];
    final backgroundColor = backgroundColorStr == null
        ? null
        : ColorExtension.tryFromRgbaString(backgroundColorStr);
    if (backgroundColor != null) {
      style = style.copyWith(color: backgroundColor);
    }
    //apply italic tag

    if (cssMap["font-style"] == "italic") {
      style = style.copyWith(fontStyle: FontStyle.italic)
        ..merge(customStyles.italicStyle);
    }

    return style;
  }

//this function apply thee text decorations from html inline style css
  static TextStyle _assignTextDecorations(
      TextStyle style, String decorationStr) {
    final decorations = decorationStr.split(" ");
    final textdecorations = <TextDecoration>[];
    for (final d in decorations) {
      if (d == "line-through") {
        textdecorations.add(TextDecoration.overline);
      } else if (d == "underline") {
        textdecorations.add(TextDecoration.underline);
      }
    }
    return style.copyWith(decoration: TextDecoration.combine(textdecorations));
  }
}
