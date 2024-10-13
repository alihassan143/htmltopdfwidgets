import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:htmltopdfwidgets/src/attributes.dart';
import 'package:htmltopdfwidgets/src/extension/int_extensions.dart';
import 'package:htmltopdfwidgets/src/utils/utils.dart';
import 'package:http/http.dart';
import 'package:pdf/widgets.dart';
import 'package:printing/printing.dart';

import '../htmltopdfwidgets.dart';
import 'extension/color_extension.dart';
import 'html_tags.dart';
import 'pdfwidgets/bullet_list.dart';
import 'pdfwidgets/number_list.dart';
import 'pdfwidgets/quote_widget.dart';

class WidgetsHTMLDecoder {

  final Font? font;

  final HtmlTagStyle customStyles;

  final List<Font> fontFallback;

  WidgetsHTMLDecoder({
    this.font,
    required this.fontFallback,
    this.customStyles = const HtmlTagStyle(),
  });

  Future<List<Widget>> convert(String html) async {

    final document = parse(html.trim());
    final body = document.body;
    if (body == null) return [];

    return await _parseComplexElement(body);
  }

  Future<List<Widget>> _parseComplexElement(dom.Element element) async {
    List<Widget> children = [];
    List<(TextSpan, TextAlign?)> delta = [];

    List<Object> items = await _parseDeltaElement(element);

    for(var item in items){

      if(item is Widget){
        children.addAll(_mergeDeltaSpans(delta));
        delta.clear();
        children.add(item);
        continue;
      }

      if(item is (TextSpan, TextAlign?)){
        delta.add(item);
        continue;
      }

    }

    children.addAll(_mergeDeltaSpans(delta));

    return children;
  }

  /// Function to parse special HTML elements (e.g., headings, lists, images)
  Future<List<Widget>> _parseSpecialElements(dom.Element element) async {
    final localName = element.localName;
    switch (localName) {
      /// Handle heading level 1
      case HTMLTags.h1:
        return [_parseHeadingElement(element, level: 1)];

      /// Handle heading level 2
      case HTMLTags.h2:
        return [_parseHeadingElement(element, level: 2)];

      /// Handle heading level 3
      case HTMLTags.h3:
        return [_parseHeadingElement(element, level: 3)];

      /// Handle heading level 4
      case HTMLTags.h4:
        return [_parseHeadingElement(element, level: 4)];

      /// Handle heading level 5
      case HTMLTags.h5:
        return [_parseHeadingElement(element, level: 5)];

      /// Handle heading level 6
      case HTMLTags.h6:
        return [_parseHeadingElement(element, level: 6)];

      /// Handle unordered list
      case HTMLTags.unorderedList:
        return await _parseUnOrderListElement(element);

      /// Handle ordered list and converts its children to widgets
      case HTMLTags.orderedList:
        return await _parseOrderListElement(element);

      /// Handle table
      case HTMLTags.table:
        return [await _parseTable(element)];

      ///if simple list is found it will handle accordingly
      case HTMLTags.listItem:
        return await _parseListItemElement(
          element,
          listTag: nearestParent(element, [HTMLTags.unorderedList, HTMLTags.orderedList])?.localName ?? HTMLTags.unorderedList,
          nestedList: hasInParent(element, [HTMLTags.listItem]),
        );

      /// Handle block quote tag
      case HTMLTags.blockQuote:
        return [await _parseBlockQuoteElement(element)];

      /// Handle the image tag
      case HTMLTags.image:
        return [await _parseImageElement(element)];

      /// if no special element is found it treated as simple paragraph
      default:  // E.g. HTMLTags.paragraph
        return [await _parseParagraphElement(element)];
    }
  }

  //// Parses the attributes of a formatting element and returns a TextStyle.
  (TextAlign?, TextStyle) _parseFormattingElement(dom.Element element) {

    // Check if the element is a simple formatting tag like <span>, <bold>,
    // or <italic> as well as formatting tags or attributes in all of its parent
    // elements and return the corresponding text alignment and style.

    final List<TextDecoration> decoration = [];
    var (align, style) = _getDeltaAttributesFromHtmlAttributes(
      element.attributes,
    );

    switch (element.localName) {

      /// Handle <bold> element
      case HTMLTags.bold || HTMLTags.strong:
        style = style
            .copyWith(fontWeight: FontWeight.bold)
            .merge(customStyles.boldStyle);
        break;

      /// Handle <em> <i> element
      case HTMLTags.italic || HTMLTags.em:
        style = style
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

      /// Handle <span> and <mark> element
      case HTMLTags.span || HTMLTags.mark:
        // Nothing to do here
        break;

      /// Handle <a> element
      case HTMLTags.anchor:
        final href = element.attributes['href'];
        if (href != null) {
          decoration.add(TextDecoration.underline);
          style = style
              .copyWith(color: PdfColors.blue)
              .merge(customStyles.linkStyle);
        }
        break;

      /// Handle <code> element
      case HTMLTags.code:
        style = style
            .copyWith(background: const BoxDecoration(color: PdfColors.red))
            .merge(customStyles.codeStyle);
        break;
      default:
        break;
    }

    style = style.copyWith(decoration: TextDecoration.combine(decoration));

    if(element.parent == null)
      return (align, style);

    var (parentAlign, parentStyle) = _parseFormattingElement(element.parent!);

    ///will combine style get from the children
    return (align ??= parentAlign, parentStyle.merge(style));
  }

  ///convert table tag into the table pdf widget
  Future<Widget> _parseTable(dom.Element element) async {
    final List<TableRow> tableRows = [];

    dom.Element tbody = element.children.first;

    for (final child in tbody.children)
      tableRows.add(await _parseTableRow(child));

    return Table(
          border: TableBorder.all(color: PdfColors.black),
          children: tableRows
      );
  }

  Future<TableRow> _parseTableRow(dom.Element element) async {
    final List<Widget> tableDataList = [];

    for (final data in element.children)
      tableDataList.add(await _parseTableData(data));

    return TableRow(
      decoration: BoxDecoration(border: Border.all(color: PdfColors.black)),
      children: tableDataList
    );
  }

  ///parse html data and convert to table row
  Future<Widget> _parseTableData(
    dom.Element element,
  ) async {

    List<Widget> children = [];
    for (dom.Element child in element.children)
      children.addAll(await _parseSpecialElements(child));

    Widget result = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
    );

    if(!element.attributes.containsKey('style'))
      return result;

    double? paddingLeft;
    double? paddingRight;
    double? paddingTop;
    double? paddingBottom;

    List<String> styleElements = element.attributes['style']!.split(';');

    for(String styleElement in styleElements) {

      List<String> styleElementParts = styleElement.split(':');

      if(styleElementParts.length != 2) continue;

      String styleName = styleElementParts[0].trim();
      String styleValue = styleElementParts[1].trim();

      // Replace 'px' with '' is inacurate - should consider other units like 'pt', 'em', 'rem', '%', etc.
      if(styleName == 'padding-left')
        paddingLeft = double.tryParse(styleValue.replaceAll('px', ''));
      else if(styleName == 'padding-right')
        paddingRight = double.tryParse(styleValue.replaceAll('px', ''));
      else if(styleName == 'padding-top')
        paddingTop = double.tryParse(styleValue.replaceAll('px', ''));
      else if(styleName == 'padding-bottom')
        paddingBottom = double.tryParse(styleValue.replaceAll('px', ''));
    }

    return Padding(
      padding: customStyles.tablePadding.copyWith(
        left: paddingLeft,
        right: paddingRight,
        top: paddingTop,
        bottom: paddingBottom
      ),
      child: result
    );

  }

  Widget _parseHeadingElement(
    dom.Element element, {
    required int level,
  }) {
    TextAlign? textAlign;
    final delta = <TextSpan>[];
    final children = element.nodes.toList();
    for (final child in children) {
      if (child is dom.Element) {
        TextStyle style;
        (textAlign, style) = _parseFormattingElement(child);
        delta.add(TextSpan(text: child.text, style: style));
      } else {
        delta.add(
          TextSpan(
            text: child.text,
            style: TextStyle(
              font: font,
              fontFallback: fontFallback,
            )
          )
        );
      }
    }

    bool isPreviousHeader = isPreviousElement(
      element,
      [HTMLTags.h1, HTMLTags.h2, HTMLTags.h3, HTMLTags.h4, HTMLTags.h5, HTMLTags.h6]
    );

    bool isNextHeader = isNextElement(
      element,
      [HTMLTags.h1, HTMLTags.h2, HTMLTags.h3, HTMLTags.h4, HTMLTags.h5, HTMLTags.h6]
    );

    Widget widget = SizedBox(
      width: double.infinity,
      child: RichText(
        textAlign: textAlign,
        text: TextSpan(
          children: delta,
          style: level.getHeadingStyle(customStyles)
        )
      )
    );


    return Padding(
      padding: EdgeInsets.only(
        top: isPreviousHeader?0:customStyles.headingTopSpacing,
        bottom: isNextHeader?0:customStyles.headingBottomSpacing
      ),
      child: widget
    );
  }

  /// Function to parse a block quote element and return a list of widgets
  Future<Widget> _parseBlockQuoteElement(dom.Element element) async {

    final child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: await _parseComplexElement(element)
    );

    return buildQuoteWidget(child, customStyles: customStyles);

  }

  /// Function to parse an unordered list element and return a list of widgets
  Future<List<Widget>> _parseUnOrderListElement(dom.Element element) async {

    // Check if the list is nested within another list
    bool nestedList = hasInParent(element, [HTMLTags.listItem]);

    // If the list has no children, return a single bullet widget
    if (element.children.isEmpty)
      return [
        BulletListItemWidget(
            child: Text(
              element.text,
              style: customStyles.paragraphStyle,
            ),
            customStyles: customStyles,
            nestedList: nestedList
        )
      ];

    final result = <Widget>[];

    if(customStyles.listTopPadding > 0 && hasPreviousElement(element) || nestedList)
      result.add(SizedBox(height: customStyles.listTopPadding));

    // Parse each list item and add it to the result
    for (int i=0; i<element.children.length; i++) {
      result.addAll(
          await _parseListItemElement(
            element.children[i],
              listTag: HTMLTags.unorderedList,
              nestedList: nestedList,
          )
      );

      // Add vertical space between list items
      if(i < element.children.length - 1 && customStyles.listItemVerticalSeparatorSize > 0)
        result.add(SizedBox(height: customStyles.listItemVerticalSeparatorSize));

    }

    if(customStyles.listTopPadding > 0 && hasNextElement(element))
      result.add(SizedBox(height: customStyles.listBottomPadding));

    return result;

  }

  /// Function to parse an ordered list element and return a list of widgets
  Future<List<Widget>> _parseOrderListElement(dom.Element element) async {

    // Check if the list is nested within another list
    bool nestedList = hasInParent(element, [HTMLTags.listItem]);

    // If the list has no children, return a single number widget
    if (element.children.isEmpty)
      return [
        NumberListItemWidget(
            child: Text(
              element.text,
              style: customStyles.paragraphStyle,
            ),
            index: 1,
            customStyles: customStyles
        )
      ];

    final result = <Widget>[];

    if(customStyles.listTopPadding > 0 && hasPreviousElement(element) || nestedList)
      result.add(SizedBox(height: customStyles.listTopPadding));

    // Parse each list item and add it to the result
    for (var i = 0; i < element.children.length; i++) {
      final childElement = element.children[i];

      // Parse the list item element and add it to the result
      result.addAll(
          await _parseListItemElement(
            childElement,
            listTag: HTMLTags.orderedList,
            index: i + 1,
            nestedList: nestedList,
          )
      );

      // Add vertical space between list items
      if(i < element.children.length - 1 && customStyles.listItemVerticalSeparatorSize > 0)
        result.add(SizedBox(height: customStyles.listItemVerticalSeparatorSize));

    }

    if(customStyles.listTopPadding > 0  && hasNextElement(element))
      result.add(SizedBox(height: customStyles.listBottomPadding));

    return result;
  }

  /// Function to parse a list element (unordered or ordered) and return a list of widgets
  Future<List<Widget>> _parseListItemElement(
    dom.Element element, {
    required String listTag,
    bool withIndicator = true,
    int? index,
    required bool nestedList,
  }) async {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: await _parseComplexElement(element)
    );

    /// Build a bullet list widget
    if (listTag == HTMLTags.unorderedList) {
      return [
        BulletListItemWidget(
            child: child,
            customStyles: customStyles,
            nestedList: nestedList,
            withIndicator: withIndicator
        )
      ];

      /// Build a numbered list widget
    } else if (listTag == HTMLTags.orderedList) {
      return [
        NumberListItemWidget(
            child: child,
            index: index!,
            customStyles: customStyles,
            withIndicator: withIndicator
        )
      ];

    } else {
      return [child];
    }
  }

  List<Widget> _mergeDeltaSpans(List<(TextSpan, TextAlign?)> delta){
    /// `TextSpan`s have to be grouped together if they have the same alignment.
    /// This function merges such groups into a single `RichText` widgets.
    /// This function is a helper function for `_parseParagraphElement(...)`.

    if (delta.isEmpty) return [];

    TextAlign? currentAlignment = delta[0].$2;
    List<Widget> result = [];

    /// Temporary list to hold subsequent spans with the same align values.
    List<TextSpan> subDelta = [];

    void subDeltaToResult(){
      if (subDelta.isEmpty) return;
      result.add(
        // SizedBox expands the RichText widget to the full width of the
        // parent. This way the text is able to be aligned properly.
        SizedBox(
          width: double.infinity,
          child: RichText(
            textAlign: currentAlignment,
            text: TextSpan(children: List.of(subDelta)),
          ),
        )
      );
      subDelta.clear();
    }

    for((TextSpan, TextAlign?) item in delta){
      TextSpan span = item.$1;
      TextAlign? align = item.$2;

      if(align != currentAlignment){
        subDeltaToResult();
        currentAlignment = align;
      }

      subDelta.add(span);
    }
    subDeltaToResult();

    return result;
  }

  /// Function to parse a paragraph element and return a widget
  Future<Widget> _parseParagraphElement(dom.Element element) async {
    return Wrap(children: await _parseComplexElement(element));
  }

  /// Function to parse an image element and return an Image widget
  Future<Widget> _parseImageElement(dom.Element element) async {
    final src = element.attributes["src"];
    try {
      if (src == null) return Text("");

      // Handle base64 image provided as string
      if (src.startsWith("data:image/")) {
        // Separate from the base64 metadata, if there is any
        final List<String> components = src.split(",");

        if (components.length > 1) {
          var base64Encoded = components.last;
          Uint8List listData = base64Decode(base64Encoded);
          return Image(
            MemoryImage(listData),
            alignment: customStyles.imageAlignment,
          );
        }
        return Text("");
      }

      // Handle svg image provided as an asset
      if (src.startsWith("asset:") && src.endsWith(".svg")) {
        String? svgData = await readStringFromAssets(src.substring("asset:".length));
        if(svgData == null) return Text("");
        return SvgImage(
            svg: svgData,
            alignment: customStyles.imageAlignment
        );
        
      // Handle raster (pixel) image provided as an asset
      } else if (src.startsWith("asset:")) {
        return Image(
            await imageFromAssetBundle(src.substring("asset:".length)),
            alignment: customStyles.imageAlignment
        );
      }

      final netImage = await _saveImage(src);

      // Handle svg image provided as a web URL
      if(src.endsWith(".svg")) {
        return SvgImage(
            svg: utf8.decode(netImage),
            alignment: customStyles.imageAlignment
        );
      }

      // Handle raster (pixel) image provided as a web URL
      return Image(
          MemoryImage(netImage),
          alignment: customStyles.imageAlignment
      );

    } catch (e) {
      return Text("");
    }
  }

  /// Function to download and save an image from a URL
  Future<Uint8List> _saveImage(String url) async {
    try {
      /// Download image
      final Response response = await get(Uri.parse(url));

      /// Get temporary directory

      return response.bodyBytes;
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<List<Object>> _parseDeltaElement(dom.Element element) async {

    var (align, style) = _parseFormattingElement(element);

    // This list holds only of of two types:
    // - (`TextSpan`, 'TextAlign?`) tuples
    // - `Widget`s.
    //
    // The idea is to collect all neighbouring text spans and later display them
    // in a single RichText. Of course widgets will be displayed as well.
    final List<Object> result = [];

    for (final dom.Node node in element.nodes) {

      // Not of type `Element` - convert to text and add to delta.
      if(node is! dom.Element){
        TextSpan textSpan = TextSpan(
            text: node.text?.replaceAll(RegExp(r'\n+$'), '') ?? "",
            style: style
        );
        result.add((textSpan, align));
        continue;
      }

      // Handle new line breaks within the paragraph
      if (node.localName == HTMLTags.br) {
        result.add((TextSpan(text: "\n", style: style), align));
        continue;
      }

      // Handle special elements (e.g., headings, lists) within a paragraph
      if(HTMLTags.specialElements.contains(node.localName)) {
        result.addAll(
          await _parseSpecialElements(node)
        );
        continue;
      }

      // No match for irregular elements so far.
      // Parse the children of the currently handled node and add the result.
      result.addAll(await _parseDeltaElement(node));

    }

    return result;
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

  /// Function to extract text styles from HTML attributes
  (TextAlign?, TextStyle) _getDeltaAttributesFromHtmlAttributes(LinkedHashMap<Object, String> htmlAttributes) {
    TextStyle style = customStyles.paragraphStyle??TextStyle(font: font, fontFallback: fontFallback);
    TextAlign? textAlign;

    ///extract styls from the inline css
    final styleString = htmlAttributes["style"];
    final cssMap = _cssStringToMap(styleString);

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
        : ColorExtension.tryFromRgbaString(backgroundColorStr);
    if (backgroundColor != null) {
      style = style.copyWith(color: backgroundColor);
    }

    ///apply background color on text
    final colorstr = cssMap["color"];
    final color =
        colorstr == null ? null : ColorExtension.tryFromRgbaString(colorstr);
    if (color != null) {
      style = style.copyWith(color: color);
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
        return TextAlign.left;
      case "justify":
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  ///this function apply thee text decorations from html inline style css
  static TextStyle _assignTextDecorations(TextStyle style, String decorationStr) {
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
