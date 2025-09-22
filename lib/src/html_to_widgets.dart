import 'dart:async';
import 'dart:collection';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:htmltopdfwidgets/src/attributes.dart';
import 'package:htmltopdfwidgets/src/extension/int_extensions.dart';
import 'package:htmltopdfwidgets/src/utils/app_assets.dart';

import '../htmltopdfwidgets.dart';
import 'extension/color_extension.dart';
import 'html_tags.dart';
import 'pdfwidgets/bullet_list.dart';
import 'pdfwidgets/image_element_io.dart'
    if (dart.library.html) 'pdfwidgets/image_element_web.dart';
import 'pdfwidgets/number_list.dart';
import 'pdfwidgets/quote_widget.dart';

////html deocoder that deocde html and convert it into pdf widgets
class WidgetsHTMLDecoder {
  final double defaultFontSize;
  final double defaultFontHeight;
  final String defaultFontFamily;

  /// Resolve the font for the PDF based on (font family, bold, italic)
  final FutureOr<Font> Function(String, bool, bool)? fontResolver;

  /// Font for the PDF, if not provided, use default
  final HtmlTagStyle customStyles;
  final bool wrapInParagraph;

  /// Custom styles for HTML tags
  final List<Font> fontFallback;

  /// Constructor for the HTML decoder
  WidgetsHTMLDecoder({
    this.fontResolver,
    required this.fontFallback,
    this.customStyles = const HtmlTagStyle(),
    this.defaultFontFamily = "Roboto",
    this.wrapInParagraph = false,
    this.defaultFontSize = 12.0,
    this.defaultFontHeight = 1.2,
  });

  //// The class takes an HTML string as input and returns a list of Widgets. The Widgets
  //// are created based on the tags and attributes in the HTML string.
  Future<List<Widget>> convert(String html) async {
    String text = html.trim();
    if (wrapInParagraph) {
      text = '<p>$text</p>';
    }

    /// Parse the HTML document using the html package
    final document = parse(text);
    final body = document.body;
    if (body == null) {
      return [];
    }

    final font = await fontResolver?.call(defaultFontFamily, false, false);
    final fontBold = await fontResolver?.call(defaultFontFamily, true, false);
    final fontItalic = await fontResolver?.call(defaultFontFamily, false, true);
    final fontBoldItalic =
        await fontResolver?.call(defaultFontFamily, true, true);
    final baseTextStyle = TextStyle(
        fontSize: defaultFontSize,
        height: defaultFontHeight,
        font: font,
        fontNormal: font,
        fontBold: fontBold,
        fontItalic: fontItalic,
        fontBoldItalic: fontBoldItalic,
        fontFallback: fontFallback);

    /// Call the private _parseElement function to process the HTML nodes
    List<Widget> nodes = await _parseElement(body.nodes, baseTextStyle);

    return nodes;
  }

  //// Converts the given HTML string to a list of Widgets.
  //// and returns the list of widgets

  Future<List<Widget>> _parseElement(
    Iterable<dom.Node> domNodes,
    TextStyle baseTextStyle, {
    bool preTag = false,
  }) async {
    final result = <Widget>[];
    final delta = <TextSpan>[];
    TextAlign? textAlign;
    bool checkbox = false;
    bool alreadyChecked = false;

    ///find dom node in and check if its element or not than convert it according to its specs
    for (final domNode in domNodes) {
      if (domNode is dom.Element) {
        final localName = domNode.localName;
        if (localName == HTMLTags.br) {
          delta.add(const TextSpan(
            text: "\n",
          ));
        } else if (localName == HTMLTags.pre) {
          final childrens =
              await _parseElement(domNode.nodes, baseTextStyle, preTag: true);
          delta.add(TextSpan(children: [
            WidgetSpan(
                child: Container(
                    width: double.infinity,
                    decoration: customStyles.codeDecoration ??
                        BoxDecoration(color: customStyles.codeblockColor),
                    child: Column(children: childrens)))
          ]));
        } else if (HTMLTags.formattingElements.contains(localName)) {
          /// Check if the element is a simple formatting element like <span>, <bold>, or <italic>
          final attributes = await _parserFormattingElementAttributes(
              domNode, baseTextStyle,
              preTag: preTag, inheritBase: true);

          textAlign = attributes.$1;

          delta.add(TextSpan(
              text: "${domNode.text.replaceAll(RegExp(r'\n+$'), '')} ",
              style: attributes.$2,
              annotation: attributes.$3 == null
                  ? null
                  : AnnotationUrl(attributes.$3!)));
        } else if (HTMLTags.specialElements.contains(localName)) {
          if (delta.isNotEmpty) {
            final newlist = List<TextSpan>.from(delta);
            result.add((SizedBox(
                width: double.infinity,
                child: RichText(
                    textAlign: textAlign, text: TextSpan(children: newlist)))));

            textAlign = null;
            delta.clear();
          }
          if (checkbox) {
            checkbox = false;

            result.add(Row(children: [
              SvgImage(
                  svg: alreadyChecked
                      ? AppAssets.checkedIcon
                      : AppAssets.unCheckedIcon),
              ...await _parseSpecialElements(
                domNode,
                baseTextStyle,
                type: BuiltInAttributeKey.bulletedList,
              ),
            ]));
            alreadyChecked = false;
          } else {
            if (localName == HTMLTags.checkbox) {
              final checked = domNode.attributes["type"];
              if (checked != null && checked == "checkbox") {
                checkbox = true;

                alreadyChecked = domNode.attributes.keys.contains("checked");
              }
            }
            result.addAll(
              await _parseSpecialElements(
                domNode,
                baseTextStyle,
                type: BuiltInAttributeKey.bulletedList,
              ),
            );
          }

          /// Handle special elements (e.g., headings, lists, images)
        } else if (localName == HTMLTags.horizontalDivider) {
          result.add(Divider(
              color: customStyles.dividerColor,
              thickness: customStyles.dividerthickness,
              height: customStyles.dividerHight,
              borderStyle: customStyles.dividerBorderStyle));
        }
      } else if (domNode is dom.Text) {
        if (delta.isNotEmpty && domNode.text.trim().isNotEmpty) {
          final newlist = List<TextSpan>.from(delta);
          result.add((SizedBox(
              width: double.infinity,
              child: RichText(
                  textAlign: textAlign,
                  text: TextSpan(
                      children: newlist
                        ..add(TextSpan(
                            text: domNode.text, style: baseTextStyle)))))));

          textAlign = null;

          delta.clear();
        } else {
          result.add(Text(domNode.text, style: baseTextStyle));
        }

        /// Process text nodes and add them to delta
      } else {
        assert(false, 'Unknown node type: $domNode');
      }
    }
    if (delta.isNotEmpty) {
      final newlist = List<TextSpan>.from(delta);
      result.add((SizedBox(
          width: double.infinity,
          child: RichText(
              textAlign: textAlign, text: TextSpan(children: newlist)))));
    }

    /// If there are text nodes in delta, wrap them in a Wrap widget and add to the result

    return result;
  }

  /// Function to parse special HTML elements (e.g., headings, lists, images)
  Future<Iterable<Widget>> _parseSpecialElements(
    dom.Element element,
    TextStyle baseTextStyle, {
    required String type,
  }) async {
    final localName = element.localName;
    switch (localName) {
      /// Handle heading level 1
      case HTMLTags.h1:
        return [await _parseHeadingElement(element, baseTextStyle, level: 1)];

      /// Handle heading level 2
      case HTMLTags.h2:
        return [await _parseHeadingElement(element, baseTextStyle, level: 2)];

      /// Handle heading level 3
      case HTMLTags.h3:
        return [await _parseHeadingElement(element, baseTextStyle, level: 3)];

      /// Handle heading level 4
      case HTMLTags.h4:
        return [await _parseHeadingElement(element, baseTextStyle, level: 4)];

      /// Handle heading level 5
      case HTMLTags.h5:
        return [await _parseHeadingElement(element, baseTextStyle, level: 5)];

      /// Handle heading level 6
      case HTMLTags.h6:
        return [await _parseHeadingElement(element, baseTextStyle, level: 6)];

      /// Handle unorder list
      case HTMLTags.unorderedList:
        return await _parseUnOrderListElement(element, baseTextStyle);

      /// Handle ordered list and converts its childrens to widgets
      case HTMLTags.orderedList:
        return await _parseOrderListElement(element, baseTextStyle);
      case HTMLTags.table:
        return await _parseTable(element, baseTextStyle);

      ///if simple list is found it will handle accoridingly
      case HTMLTags.list:
        return await _parseListElement(
          element,
          baseTextStyle,
          type: type,
        );

      /// it handles the simple paragraph element
      case HTMLTags.paragraph:
        return [await _parseParagraphElement(element, baseTextStyle)];

      /// Handle block quote tag
      case HTMLTags.blockQuote:
        return await _parseBlockQuoteElement(element, baseTextStyle);

      /// Handle the image tag
      case HTMLTags.image:
        return [await parseImageElement(element, customStyles: customStyles)];

      /// Handle the line break tag

      /// if no special element is found it treated as simple parahgraph
      default:
        return [await _parseParagraphElement(element, baseTextStyle)];
    }
  }

  Text paragraphNode({required String text}) {
    return Text(text);
  }

  //// Parses the attributes of a formatting element and returns a TextStyle.
  Future<(TextAlign?, TextStyle, String?)> _parserFormattingElementAttributes(
      dom.Element element, TextStyle baseTextStyle,
      {bool preTag = false, bool inheritBase = true}) async {
    final localName = element.localName;
    TextAlign? textAlign;
    String? link;
    TextStyle attributes = inheritBase ? baseTextStyle : const TextStyle();
    final List<TextDecoration> decoration = [];

    switch (localName) {
      /// Handle <bold> element
      case HTMLTags.bold || HTMLTags.strong:
        attributes = attributes
            .copyWith(fontWeight: FontWeight.bold)
            .merge(customStyles.boldStyle);
        break;

      /// Handle <em> <i> element
      case HTMLTags.italic || HTMLTags.em:
        attributes = attributes
            .copyWith(fontStyle: FontStyle.italic)
            .merge(customStyles.italicStyle);

        break;

      /// Handle <u> element
      case HTMLTags.underline:
        decoration.add(TextDecoration.underline);
        break;

      /// Handle <del> element
      case HTMLTags.del:
        decoration.add(TextDecoration.lineThrough);

        break;

      /// Handle <span>  <mark> element
      case HTMLTags.span || HTMLTags.mark:
        final deltaAttributes = await _getDeltaAttributesFromHtmlAttributes(
          element.attributes,
        );
        textAlign = deltaAttributes.$1;
        attributes = attributes.merge(deltaAttributes.$2);
        if (deltaAttributes.$2.decoration != null) {
          decoration.add(deltaAttributes.$2.decoration!);
        }
        break;

      /// Handle <a> element
      case HTMLTags.anchor:
        final href = element.attributes['href'];
        if (href != null) {
          decoration.add(
            TextDecoration.underline,
          );
          attributes = attributes
              .copyWith(color: PdfColors.blue)
              .merge(customStyles.linkStyle);
          link = href;
        }
        break;

      /// Handle <code> element
      case HTMLTags.code:
        if (!preTag) {
          attributes = attributes
              .copyWith(
                  background: BoxDecoration(
                      color: customStyles.codeBlockBackgroundColor))
              .merge(customStyles.codeStyle);
        }

        break;
      default:
        break;
    }

    for (final child in element.children) {
      final nattributes = await _parserFormattingElementAttributes(
          child, baseTextStyle,
          preTag: preTag, inheritBase: inheritBase);
      attributes = attributes.merge(nattributes.$2);
      if (nattributes.$2.decoration != null) {
        decoration.add(nattributes.$2.decoration!);
      }
      textAlign = nattributes.$1;
      if (nattributes.$3 != null) {
        link = nattributes.$3;
      }
    }

    ///will combine style get from the children
    return (
      textAlign,
      attributes.copyWith(decoration: TextDecoration.combine(decoration)),
      link
    );
  }

  ///convert table tag into the table pdf widget
  Future<Iterable<Widget>> _parseTable(
      dom.Element element, TextStyle baseTextStyle) async {
    final List<TableRow> tablenodes = [];

    ///iterate over html table tag body
    for (final data in element.children) {
      final rwdata = await _parsetableRows(data, baseTextStyle);

      tablenodes.addAll(rwdata);
    }

    return [
      Table(
          border: TableBorder.all(color: PdfColors.black),
          children: tablenodes),
    ];
  }

  ///converts html table tag body to table row widgets
  Future<List<TableRow>> _parsetableRows(
      dom.Element element, TextStyle baseTextStyle) async {
    final List<TableRow> nodes = [];

    ///iterate over <tr> tag and convert its children to related pdf widget
    for (final data in element.children) {
      final tabledata = await _parsetableData(data, baseTextStyle);

      nodes.add(tabledata);
    }
    return nodes;
  }

  ///parse html data and convert to table row
  Future<TableRow> _parsetableData(
    dom.Element element,
    TextStyle baseTextStyle,
  ) async {
    final List<Widget> nodes = [];

    ///iterate over <tr>children
    for (final data in element.children) {
      if (data.nodes.isEmpty) {
        ///if single <th> or<td> tag found
        final node = paragraphNode(text: data.text);

        nodes.add(node);
      } else {
        ///if nested <p><br> in <tag> found
        final newnodes = await _parseTableSpecialNodes(data, baseTextStyle);

        nodes.addAll(newnodes);
      }
    }

    ///returns the tale row
    return TableRow(
        decoration: BoxDecoration(border: Border.all(color: PdfColors.black)),
        children: nodes);
  }

  ///parse the nodes and handle theem accordingly
  Future<Iterable<Widget>> _parseTableSpecialNodes(
      dom.Element node, TextStyle baseTextStyle) async {
    final List<Widget> nodes = [];

    ///iterate over multiple childrens
    if (node.nodes.isNotEmpty) {
      ///parse them according to their widget
      nodes.addAll(await _parseElement(node.nodes, baseTextStyle));
    } else {
      nodes.addAll(await _parseTableDataElementsData(node, baseTextStyle));
    }
    return nodes;
  }

  ///check if children contains the <p> <li> or any other tag

  Future<List<Widget>> _parseTableDataElementsData(
      dom.Element element, TextStyle baseTextStyle) async {
    final List<Widget> delta = [];
    final result = <Widget>[];

    ///find dom node in and check if its element or not than convert it according to its specs

    final localName = element.localName;

    /// Check if the element is a simple formatting element like <span>, <bold>, or <italic>
    if (localName == HTMLTags.br) {
      result.add(Text('\n'));
    } else if (HTMLTags.formattingElements.contains(localName)) {
      final attributes =
          await _parserFormattingElementAttributes(element, baseTextStyle);
      result.add(RichText(
          text: TextSpan(
              text: element.text,
              style: attributes.$2,
              annotation: attributes.$3 == null
                  ? null
                  : AnnotationUrl(attributes.$3!))));
      result.add(Text(element.text, style: attributes.$2));
    } else if (HTMLTags.specialElements.contains(localName)) {
      /// Handle special elements (e.g., headings, lists, images)
      result.addAll(
        await _parseSpecialElements(
          element,
          baseTextStyle,
          type: BuiltInAttributeKey.bulletedList,
        ),
      );
    } else if (element is dom.Text) {
      /// Process text nodes and add them to delta
      delta.add(Text(element.text, style: baseTextStyle));
    } else {
      assert(false, 'Unknown node type: $element');
    }

    /// If there are text nodes in delta, wrap them in a Wrap widget and add to the result
    if (delta.isNotEmpty) {
      result.add(Wrap(children: delta));
    }
    return result;
  }

  /// Function to parse a heading element and return a RichText widget
  Future<Widget> _parseHeadingElement(
    dom.Element element,
    TextStyle baseTextStyle, {
    required int level,
  }) async {
    TextAlign? textAlign;
    final delta = <TextSpan>[];
    final children = element.nodes.toList();
    for (final child in children) {
      if (child is dom.Element) {
        final attributes = await _parserFormattingElementAttributes(
            child, baseTextStyle,
            inheritBase: false);
        textAlign = attributes.$1;

        delta.add(TextSpan(
            text: child.text,
            style: attributes.$2,
            annotation:
                attributes.$3 == null ? null : AnnotationUrl(attributes.$3!)));
      } else {
        delta.add(TextSpan(text: child.text));
      }
    }

    // Parse possible block-level spacing (margin-bottom/padding-bottom)
    final cssMap = _cssStringToMap(element.attributes['style']);
    final bottomPadding = _parseBottomSpacing(cssMap);

    /// Return a RichText widget with the parsed text and styles
    return SizedBox(
        width: double.infinity,
        child: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding ?? 0),
            child: RichText(
                textAlign: textAlign,
                text: TextSpan(
                    children: delta,
                    style: baseTextStyle
                        .copyWith(
                            fontSize: level.getHeadingSize,
                            fontWeight: FontWeight.bold)
                        .merge(level.getHeadingStyle(customStyles))))));
  }

  /// Function to parse a block quote element and return a list of widgets
  Future<List<Widget>> _parseBlockQuoteElement(
      dom.Element element, TextStyle baseTextStyle) async {
    final result = <Widget>[];
    if (element.children.isNotEmpty) {
      for (final child in element.children) {
        result.addAll(await _parseListElement(child, baseTextStyle,
            type: BuiltInAttributeKey.quote));
      }
    } else {
      result.add(
          buildQuotewidget(Text(element.text), customStyles: customStyles));
    }
    return result;
  }

  /// Function to parse an unordered list element and return a list of widgets
  Future<Iterable<Widget>> _parseUnOrderListElement(
      dom.Element element, TextStyle baseTextStyle) async {
    final result = <Widget>[];

    if (element.children.isNotEmpty) {
      for (final child in element.children) {
        result.addAll(await _parseListElement(child, baseTextStyle,
            type: BuiltInAttributeKey.bulletedList));
      }
    } else {
      result.add(
          buildBulletwidget(Text(element.text), customStyles: customStyles));
    }
    return result;
  }

  /// Function to parse an ordered list element and return a list of widgets
  Future<Iterable<Widget>> _parseOrderListElement(
      dom.Element element, TextStyle baseTextStyle) async {
    final result = <Widget>[];

    if (element.children.isNotEmpty) {
      for (var i = 0; i < element.children.length; i++) {
        final child = element.children[i];
        result.addAll(await _parseListElement(child, baseTextStyle,
            type: BuiltInAttributeKey.numberList, index: i + 1));
      }
    } else {
      result.add(buildNumberwdget(Text(element.text),
          baseTextStyle: baseTextStyle, customStyles: customStyles, index: 1));
    }
    return result;
  }

  /// Function to parse a list element (unordered or ordered) and return a list of widgets
  Future<Iterable<Widget>> _parseListElement(
    dom.Element element,
    TextStyle baseTextStyle, {
    required String type,
    int? index,
  }) async {
    final delta = await _parseDeltaElement(element, baseTextStyle);

    /// Build a bullet list widget
    if (type == BuiltInAttributeKey.bulletedList) {
      return [buildBulletwidget(delta, customStyles: customStyles)];

      /// Build a numbered list widget
    } else if (type == BuiltInAttributeKey.numberList) {
      return [
        buildNumberwdget(delta,
            index: index!,
            customStyles: customStyles,
            baseTextStyle: baseTextStyle)
      ];

      /// Build a quote  widget
    } else if (type == BuiltInAttributeKey.quote) {
      return [buildQuotewidget(delta, customStyles: customStyles)];
    } else {
      return [delta];
    }
  }

  /// Function to parse a paragraph element and return a widget
  Future<Widget> _parseParagraphElement(
      dom.Element element, TextStyle baseTextStyle) async {
    final delta = await _parseDeltaElement(element, baseTextStyle);
    // Apply block-level bottom spacing if provided
    final cssMap = _cssStringToMap(element.attributes['style']);
    final bottomPadding = _parseBottomSpacing(cssMap);
    if (bottomPadding != null && bottomPadding > 0) {
      return Padding(padding: EdgeInsets.only(bottom: bottomPadding), child: delta);
    }
    return delta;
  }

  /// Function to parse a complex HTML element and return a widget
  Future<Widget> _parseDeltaElement(
      dom.Element element, TextStyle baseTextStyle) async {
    final delta = <TextSpan>[];
    final children = element.nodes.toList();
    final childNodes = <Widget>[];
    TextAlign? textAlign;
    for (final child in children) {
      /// Recursively parse child elements
      if (child is dom.Element) {
        if (child.children.isNotEmpty &&
            HTMLTags.formattingElements.contains(child.localName) == false) {
          childNodes.addAll(await _parseElement(child.nodes, baseTextStyle));
        } else {
          if (child.localName == HTMLTags.pre) {
            final childrens =
                await _parseElement(child.nodes, baseTextStyle, preTag: true);
            delta.add(TextSpan(children: [
              WidgetSpan(
                  child: Container(
                      width: double.infinity,
                      decoration: customStyles.codeDecoration ??
                          BoxDecoration(color: customStyles.codeblockColor),
                      child: Column(children: childrens)))
            ]));
          } else

          /// Handle special elements (e.g., headings, lists) within a paragraph
          if (HTMLTags.specialElements.contains(child.localName)) {
            childNodes.addAll(
              await _parseSpecialElements(
                child,
                baseTextStyle,
                type: BuiltInAttributeKey.bulletedList,
              ),
            );
          } else if (child.localName == HTMLTags.horizontalDivider) {
            childNodes.add(Divider(
                color: customStyles.dividerColor,
                thickness: customStyles.dividerthickness,
                height: customStyles.dividerHight,
                borderStyle: customStyles.dividerBorderStyle));
          } else {
            if (child.localName == HTMLTags.br) {
              delta.add(const TextSpan(
                text: "\n",
              ));
            } else {
              /// Parse text and attributes within the paragraph
              final attributes = await _parserFormattingElementAttributes(
                  child, baseTextStyle,
                  inheritBase: true);
              textAlign = attributes.$1;

              delta.add(TextSpan(
                  text: "${child.text.replaceAll(RegExp(r'\n+$'), ' ')} ",
                  style: attributes.$2.merge(customStyles.paragraphStyle),
                  annotation: attributes.$3 == null
                      ? null
                      : AnnotationUrl(attributes.$3!)));
            }
          }
        }
      } else {
        final attributes =
            await _getDeltaAttributesFromHtmlAttributes(element.attributes);
        textAlign = attributes.$1;

        /// Process text nodes and add them to delta variable
        delta.add(TextSpan(
            text: child.text?.replaceAll(RegExp(r'\n+$'), '') ?? "",
            style: baseTextStyle
                .merge(attributes.$2.merge(customStyles.paragraphStyle))));
      }
    }

    /// Create a column with wrapped text and child nodes
    return Wrap(children: [
      SizedBox(
        width: double.infinity,
        child: RichText(textAlign: textAlign, text: TextSpan(children: delta)),
      ),
      ...childNodes
    ]);
  }

  /// Utility function to convert a CSS string to a map of CSS properties
  static Map<String, String> _cssStringToMap(String? cssString) {
    final Map<String, String> result = {};
    if (cssString == null) {
      return result;
    }
    final entries = cssString.split(';');
    for (final entry in entries) {
      final tuples = entry.split(':');
      if (tuples.length < 2) {
        continue;
      }
      result[tuples[0].trim()] = tuples[1].trim();
    }
    return result;
  }

  /// Parse bottom spacing from CSS map. Prefers padding-bottom, then margin-bottom.
  static double? _parseBottomSpacing(Map<String, String> cssMap) {
    double? parseLength(String? value) {
      if (value == null) return null;
      final s = value.trim().toLowerCase();
      if (s.endsWith('px')) {
        return double.tryParse(s.replaceAll('px', '').trim());
      }
      if (s.endsWith('pt')) {
        return double.tryParse(s.replaceAll('pt', '').trim());
      }
      return double.tryParse(s);
    }

    final padding = parseLength(cssMap['padding-bottom']);
    final margin = parseLength(cssMap['margin-bottom']);
    return padding ?? margin;
  }

  /// Function to extract text styles from HTML attributes
  Future<(TextAlign?, TextStyle)> _getDeltaAttributesFromHtmlAttributes(
      LinkedHashMap<Object, String> htmlAttributes) async {
    TextStyle style = const TextStyle();
    TextAlign? textAlign;

    ///extract styls from the inline css
    final styleString = htmlAttributes["style"];
    final cssMap = _cssStringToMap(styleString);

    ///get font family
    final fontFamily = cssMap["font-family"];
    if (fontFamily != null) {
      final font = await fontResolver?.call(fontFamily, false, false);
      final fontBold = await fontResolver?.call(fontFamily, true, false);
      final fontItalic = await fontResolver?.call(fontFamily, false, true);
      final fontBoldItalic = await fontResolver?.call(fontFamily, true, true);
      style = style.copyWith(
        font: font,
        fontNormal: font,
        fontBold: fontBold,
        fontItalic: fontItalic,
        fontBoldItalic: fontBoldItalic,
      );
    }

    ///get font weight
    final fontWeightStr = cssMap["font-weight"];
    if (fontWeightStr != null) {
      if (fontWeightStr == "bold") {
        style = style
            .copyWith(fontWeight: FontWeight.bold)
            .merge(customStyles.boldStyle);
      } else {
        int? weight = int.tryParse(fontWeightStr);
        if (weight != null && weight > 500) {
          style = style
              .copyWith(fontWeight: FontWeight.bold)
              .merge(customStyles.boldStyle);
        }
      }
    }

    ///apply different text decorations like undrline line through
    final textDecorationStr = cssMap["text-decoration"];
    if (textDecorationStr != null) {
      style = style.copyWith(
          decoration:
              _assignTextDecorations(style, textDecorationStr).decoration);
    }

    ///apply background color on text
    final backgroundColorStr = cssMap["background-color"];
    final backgroundColor = backgroundColorStr == null
        ? null
        : ColorExtension.parse(backgroundColorStr);
    if (backgroundColor != null) {
      style = style.copyWith(background: BoxDecoration(color: backgroundColor));
    }

    ///apply background color on text
    final colorstr = cssMap["color"];

    final color = colorstr == null ? null : ColorExtension.parse(colorstr);
    if (color != null) {
      style = style.copyWith(color: color);
    }

    /// apply font-size
    final fontSizeStr = cssMap["font-size"];
    if (fontSizeStr != null) {
      double? parsedSize;
      final s = fontSizeStr.trim().toLowerCase();
      if (s.endsWith('px')) {
        parsedSize = double.tryParse(s.replaceAll('px', '').trim());
      } else if (s.endsWith('pt')) {
        parsedSize = double.tryParse(s.replaceAll('pt', '').trim());
      } else {
        parsedSize = double.tryParse(s);
      }
      if (parsedSize != null) {
        style = style.copyWith(fontSize: parsedSize);
      }
    }

    ///apply italic tag

    if (cssMap["font-style"] == "italic") {
      style = style
          .copyWith(fontStyle: FontStyle.italic)
          .merge(customStyles.italicStyle);
    }
    final align = cssMap["text-align"];
    if (align != null) {
      textAlign = _alignText(align);
    }

    return (textAlign, style);
  }

  static TextAlign _alignText(String alignmentString) {
    switch (alignmentString) {
      case "right":
        return TextAlign.right;
      case "center":
        return TextAlign.center;
      case "left":
        return TextAlign.right;

      case "justify":
        return TextAlign.justify;

      default:
        return TextAlign.left;
    }
  }

  ///this function apply thee text decorations from html inline style css
  static TextStyle _assignTextDecorations(
      TextStyle style, String decorationStr) {
    final decorations = decorationStr.split(" ");
    final textdecorations = <TextDecoration>[];
    for (final d in decorations) {
      if (d == "line-through") {
        textdecorations.add(TextDecoration.lineThrough);
      } else if (d == "underline") {
        textdecorations.add(TextDecoration.underline);
      }
    }
    return style.copyWith(decoration: TextDecoration.combine(textdecorations));
  }
}
