import 'dart:async';
import 'dart:collection';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:htmltopdfwidgets/src/attributes.dart';
import 'package:htmltopdfwidgets/src/legacy/css_styles.dart';
import 'package:htmltopdfwidgets/src/extension/int_extensions.dart';
import 'package:htmltopdfwidgets/src/legacy/html_default_styles.dart';
import 'package:htmltopdfwidgets/src/utils/app_assets.dart';

import '../../htmltopdfwidgets.dart';
import '../extension/color_extension.dart';
import '../html_tags.dart';
import '../pdfwidgets/bullet_list.dart';
import '../pdfwidgets/image_element_io.dart'
    if (dart.library.html) '../pdfwidgets/image_element_web.dart';
import '../pdfwidgets/number_list.dart';
import '../pdfwidgets/quote_widget.dart';

////html deocoder that deocde html and convert it into pdf widgets
class WidgetsHTMLDecoder {
  final double defaultFontSize;
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
              preTag: preTag);

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
        String text = domNode.text;
        // Normalize whitespace
        text = text.replaceAll(RegExp(r'\s+'), ' ');

        if (delta.isNotEmpty && text.trim().isNotEmpty) {
          final newlist = List<TextSpan>.from(delta);
          result.add((SizedBox(
              width: double.infinity,
              child: RichText(
                  textAlign: textAlign,
                  text: TextSpan(
                      children: newlist
                        ..add(TextSpan(text: text, style: baseTextStyle)))))));

          textAlign = null;

          delta.clear();
        } else if (text.trim().isNotEmpty) {
          result.add(Text(text.trim(), style: baseTextStyle));
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
        return [await _parseTable(element, baseTextStyle)];

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
  /// [inheritBase] determines whether to inherit base text style or start fresh
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
  Future<Widget> _parseTable(
      dom.Element element, TextStyle baseTextStyle) async {
    final cssStyles = await _parseAllCssProperties(element.attributes);

    final headerRows = <TableRow>[];
    final bodyRows = <TableRow>[];
    final footerRows = <TableRow>[];

    ///iterate over html table tag sections
    for (final child in element.children) {
      switch (child.localName) {
        case 'thead':
          for (final tr in child.children) {
            if (tr.localName == 'tr') {
              headerRows
                  .add(await _parseTableRow(tr, baseTextStyle, isHeader: true));
            }
          }
          break;
        case 'tbody':
          for (final tr in child.children) {
            if (tr.localName == 'tr') {
              bodyRows.add(await _parseTableRow(tr, baseTextStyle));
            }
          }
          break;
        case 'tfoot':
          for (final tr in child.children) {
            if (tr.localName == 'tr') {
              footerRows.add(await _parseTableRow(tr, baseTextStyle));
            }
          }
          break;
        case 'tr':
          // Direct tr without tbody
          bodyRows.add(await _parseTableRow(child, baseTextStyle));
          break;
      }
    }

    final allRows = [...headerRows, ...bodyRows, ...footerRows];

    // Determine border style
    TableBorder? tableBorder;

    if (cssStyles.border != null ||
        cssStyles.borderTop != null ||
        cssStyles.borderRight != null ||
        cssStyles.borderBottom != null ||
        cssStyles.borderLeft != null) {
      // Use CSS border if specified
      final border =
          cssStyles.border ?? BorderInfo(width: 1.0, color: PdfColors.black);

      if (cssStyles.borderCollapse == 'collapse') {
        tableBorder = TableBorder.all(
          color: border.color,
          width: border.width,
          style: border.style,
        );
      }
    } else if (cssStyles.borderCollapse != 'none') {
      // Default border if no CSS border specified
      tableBorder = TableBorder.all(
        color: PdfColors.black,
        width: 1.0,
      );
    }

    // Smart layout detection for legacy engine
    final maxColChars = <int, int>{};

    // Scan the element children to determine column weights
    for (final section in element.children) {
      final rows = (['thead', 'tbody', 'tfoot'].contains(section.localName))
          ? section.children
          : [section];
      for (final tr in rows) {
        if (tr.localName == 'tr') {
          for (int i = 0; i < tr.children.length; i++) {
            final cell = tr.children[i];
            final len = cell.text.length;
            maxColChars[i] =
                (maxColChars[i] ?? 0) < len ? len : maxColChars[i]!;
          }
        }
      }
    }

    Map<int, TableColumnWidth> columnWidths = {};
    for (var entry in maxColChars.entries) {
      final weight = entry.value > 1500 ? 3.0 : 1.0;
      columnWidths[entry.key] = FlexColumnWidth(weight);
    }

    Widget table = Table(
      border: tableBorder,
      defaultVerticalAlignment: TableCellVerticalAlignment.full,
      columnWidths: columnWidths.isEmpty ? null : columnWidths,
      defaultColumnWidth: const FlexColumnWidth(),
      children: allRows,
    );

    // Apply margin/padding if specified
    if (cssStyles.margin != null || cssStyles.padding != null) {
      table = Container(
        margin: cssStyles.margin,
        padding: cssStyles.padding,
        child: table,
      );
    }

    return table;
  }

  /// Parse table row element
  Future<TableRow> _parseTableRow(
    dom.Element element,
    TextStyle baseTextStyle, {
    bool isHeader = false,
  }) async {
    final cssStyles = await _parseAllCssProperties(element.attributes);
    final cells = <Widget>[];

    for (final cell in element.children) {
      if (cell.localName == 'td' || cell.localName == 'th') {
        final isHeaderCell = cell.localName == 'th' || isHeader;
        cells.add(
            await _parseTableCell(cell, baseTextStyle, isHeader: isHeaderCell));
      }
    }

    return TableRow(
      decoration: cssStyles.backgroundColor != null
          ? BoxDecoration(color: cssStyles.backgroundColor)
          : null,
      children: cells,
    );
  }

  /// Parse table cell element (td or th)
  Future<Widget> _parseTableCell(
    dom.Element element,
    TextStyle baseTextStyle, {
    bool isHeader = false,
  }) async {
    final cssStyles = await _parseAllCssProperties(element.attributes);

    // Parse cell content
    final content = await _parseTableCellContent(element, baseTextStyle,
        isHeader: isHeader);

    // Determine cell padding
    EdgeInsets cellPadding;
    if (cssStyles.padding != null) {
      cellPadding = cssStyles.padding!;
    } else if (customStyles.tableCellPadding != null && !isHeader) {
      cellPadding = customStyles.tableCellPadding!;
    } else if (customStyles.tableHeaderPadding != null && isHeader) {
      cellPadding = customStyles.tableHeaderPadding!;
    } else if (customStyles.useDefaultStyles) {
      cellPadding = isHeader
          ? HtmlDefaultStyles.thCellPadding
          : HtmlDefaultStyles.tableCellPadding;
    } else {
      cellPadding = const EdgeInsets.all(2.0);
    }

    // Determine text alignment
    final textAlign =
        cssStyles.textAlign ?? (isHeader ? TextAlign.center : TextAlign.left);

    // Apply cell style with border
    Widget cell = Container(
      padding: cellPadding,
      decoration: cssStyles.backgroundColor != null
          ? BoxDecoration(
              color: cssStyles.backgroundColor,
              border: cssStyles.border != null
                  ? Border.all(
                      color: cssStyles.border!.color,
                      width: cssStyles.border!.width,
                      style: cssStyles.border!.style,
                    )
                  : null,
            )
          : null,
      child: Align(
        alignment: _alignmentFromTextAlign(textAlign),
        child: content,
      ),
    );

    return cell;
  }

  /// Parse table cell content
  Future<Widget> _parseTableCellContent(
    dom.Element element,
    TextStyle baseTextStyle, {
    bool isHeader = false,
  }) async {
    // Apply bold style for headers
    final cellBaseStyle = isHeader
        ? baseTextStyle.copyWith(fontWeight: FontWeight.bold)
        : baseTextStyle;

    if (element.children.isEmpty) {
      return Text(element.text, style: cellBaseStyle);
    }

    final widgets = await _parseElement(element.nodes, cellBaseStyle);

    if (widgets.length == 1) {
      return widgets.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Convert TextAlign to Alignment
  Alignment _alignmentFromTextAlign(TextAlign textAlign) {
    switch (textAlign) {
      case TextAlign.left:
        return Alignment.centerLeft;
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.justify:
        return Alignment.centerLeft;
      default:
        return Alignment.centerLeft;
    }
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

    // Extract spacing from inline style
    final spacing = _extractSpacing(element.attributes);

    // Build heading text style with fallback chain
    final headingBaseStyle = baseTextStyle
        .copyWith(fontSize: level.getHeadingSize, fontWeight: FontWeight.bold)
        .merge(level.getHeadingStyle(customStyles));

    for (final child in children) {
      if (child is dom.Element) {
        // Parse with inheritBase=false to avoid overriding heading-level styles
        final attributes = await _parserFormattingElementAttributes(
            child, headingBaseStyle,
            inheritBase: false);
        textAlign = attributes.$1;

        delta.add(TextSpan(
            text: child.text,
            style: attributes.$2,
            annotation:
                attributes.$3 == null ? null : AnnotationUrl(attributes.$3!)));
      } else {
        delta.add(TextSpan(text: child.text, style: headingBaseStyle));
      }
    }

    /// Create heading widget
    Widget headingWidget = SizedBox(
        width: double.infinity,
        child: RichText(
            textAlign: textAlign,
            text: TextSpan(children: delta, style: headingBaseStyle)));

    // Apply spacing if specified
    if (spacing > 0) {
      headingWidget = Padding(
        padding: EdgeInsets.only(bottom: spacing),
        child: headingWidget,
      );
    }

    return headingWidget;
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
      dom.Element element, TextStyle baseTextStyle,
      {int depth = 0}) async {
    final result = <Widget>[];

    // Extract spacing from inline style
    final spacing = _extractSpacing(element.attributes);

    if (element.children.isNotEmpty) {
      for (final child in element.children) {
        result.addAll(await _parseListElement(child, baseTextStyle,
            type: BuiltInAttributeKey.bulletedList, depth: depth));
      }
    } else {
      result.add(
          buildBulletwidget(Text(element.text), customStyles: customStyles));
    }

    // Apply spacing if specified
    if (spacing > 0 && result.isNotEmpty) {
      final lastIndex = result.length - 1;
      result[lastIndex] = Padding(
        padding: EdgeInsets.only(bottom: spacing),
        child: result[lastIndex],
      );
    }

    return result;
  }

  /// Function to parse an ordered list element and return a list of widgets
  Future<Iterable<Widget>> _parseOrderListElement(
      dom.Element element, TextStyle baseTextStyle,
      {int depth = 0}) async {
    final result = <Widget>[];

    // Extract spacing from inline style
    final spacing = _extractSpacing(element.attributes);

    if (element.children.isNotEmpty) {
      for (var i = 0; i < element.children.length; i++) {
        final child = element.children[i];
        result.addAll(await _parseListElement(child, baseTextStyle,
            type: BuiltInAttributeKey.numberList, index: i + 1, depth: depth));
      }
    } else {
      result.add(buildNumberwdget(Text(element.text),
          baseTextStyle: baseTextStyle, customStyles: customStyles, index: 1));
    }

    // Apply spacing if specified
    if (spacing > 0 && result.isNotEmpty) {
      final lastIndex = result.length - 1;
      result[lastIndex] = Padding(
        padding: EdgeInsets.only(bottom: spacing),
        child: result[lastIndex],
      );
    }

    return result;
  }

  /// Function to parse a list element (unordered or ordered) and return a list of widgets
  /// [depth] tracks nesting level for proper indentation
  Future<Iterable<Widget>> _parseListElement(
    dom.Element element,
    TextStyle baseTextStyle, {
    required String type,
    int? index,
    int depth = 0,
  }) async {
    // Check for nested lists within this list item
    final nestedLists = <Widget>[];
    final nonListChildren = <dom.Node>[];

    for (final child in element.nodes) {
      if (child is dom.Element) {
        if (child.localName == HTMLTags.unorderedList) {
          // Recursively parse nested unordered list
          final nested = await _parseUnOrderListElement(child, baseTextStyle,
              depth: depth + 1);
          nestedLists.addAll(nested);
        } else if (child.localName == HTMLTags.orderedList) {
          // Recursively parse nested ordered list
          final nested = await _parseOrderListElement(child, baseTextStyle,
              depth: depth + 1);
          nestedLists.addAll(nested);
        } else {
          nonListChildren.add(child);
        }
      } else {
        nonListChildren.add(child);
      }
    }

    // Create a temporary element with only non-list children for delta parsing
    final tempElement = dom.Element.tag(element.localName ?? 'li');
    tempElement.attributes.addAll(element.attributes);
    for (final child in nonListChildren) {
      tempElement.append(child.clone(true));
    }

    final delta = await _parseDeltaElement(tempElement, baseTextStyle);

    Widget listItem;
    final indentation = depth * 20.0; // 20px indentation per level

    /// Build a bullet list widget
    if (type == BuiltInAttributeKey.bulletedList) {
      listItem = buildBulletwidget(delta, customStyles: customStyles);

      /// Build a numbered list widget
    } else if (type == BuiltInAttributeKey.numberList) {
      listItem = buildNumberwdget(delta,
          index: index!,
          customStyles: customStyles,
          baseTextStyle: baseTextStyle);

      /// Build a quote  widget
    } else if (type == BuiltInAttributeKey.quote) {
      listItem = buildQuotewidget(delta, customStyles: customStyles);
    } else {
      listItem = delta;
    }

    // Apply indentation for nested lists
    if (depth > 0) {
      listItem = Padding(
        padding: EdgeInsets.only(left: indentation),
        child: listItem,
      );
    }

    // If there are nested lists, wrap them with the list item
    if (nestedLists.isNotEmpty) {
      return [
        listItem,
        ...nestedLists.map((nested) => Padding(
              padding: EdgeInsets.only(left: indentation + 20.0),
              child: nested,
            )),
      ];
    }

    return [listItem];
  }

  /// Function to parse a paragraph element and return a widget
  Future<Widget> _parseParagraphElement(
      dom.Element element, TextStyle baseTextStyle) async {
    final delta = await _parseDeltaElement(element, baseTextStyle);

    // Extract spacing from inline style
    final spacing = _extractSpacing(element.attributes);

    // Apply spacing if specified
    if (spacing > 0) {
      return Padding(
        padding: EdgeInsets.only(bottom: spacing),
        child: delta,
      );
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
                  child, baseTextStyle);
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
        String text = child.text?.replaceAll(RegExp(r'\n+$'), ' ') ?? "";
        text = text.replaceAll(RegExp(r'\s+'), ' ');

        // Trim leading space if it's the first element in the paragraph
        if (delta.isEmpty) {
          text = text.trimLeft();
        }

        if (text.isNotEmpty) {
          delta.add(TextSpan(
              text: text,
              style: baseTextStyle
                  .merge(attributes.$2.merge(customStyles.paragraphStyle))));
        }
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

    /// Parse font-size (supports px, pt, and numeric values)
    final fontSizeStr = cssMap["font-size"];
    if (fontSizeStr != null) {
      final fontSize = _parseFontSize(fontSizeStr);
      if (fontSize != null) {
        style = style.copyWith(fontSize: fontSize);
      }
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

    ///apply text color
    final colorstr = cssMap["color"];
    final color = colorstr == null ? null : ColorExtension.parse(colorstr);
    if (color != null) {
      style = style.copyWith(color: color);
    }

    ///apply italic tag
    if (cssMap["font-style"] == "italic") {
      style = style
          .copyWith(fontStyle: FontStyle.italic)
          .merge(customStyles.italicStyle);
    }

    ///apply text alignment
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

  /// Parse font-size from CSS string (supports px, pt, and numeric values)
  static double? _parseFontSize(String fontSizeStr) {
    final trimmed = fontSizeStr.trim().toLowerCase();

    // Handle px units
    if (trimmed.endsWith('px')) {
      final value = trimmed.substring(0, trimmed.length - 2);
      return double.tryParse(value);
    }

    // Handle pt units
    if (trimmed.endsWith('pt')) {
      final value = trimmed.substring(0, trimmed.length - 2);
      return double.tryParse(value);
    }

    // Handle numeric values without units
    return double.tryParse(trimmed);
  }

  /// Extract spacing (padding-bottom or margin-bottom) from HTML attributes
  double _extractSpacing(LinkedHashMap<Object, String> htmlAttributes) {
    final styleString = htmlAttributes["style"];
    final cssMap = _cssStringToMap(styleString);

    // Try padding-bottom first, then margin-bottom
    final paddingBottom = cssMap["padding-bottom"];
    if (paddingBottom != null) {
      final spacing =
          _parseFontSize(paddingBottom); // Reuse font-size parser for spacing
      if (spacing != null) return spacing;
    }

    final marginBottom = cssMap["margin-bottom"];
    if (marginBottom != null) {
      final spacing = _parseFontSize(marginBottom);
      if (spacing != null) return spacing;
    }

    return 0.0;
  }

  /// Parse all CSS properties from HTML attributes
  Future<CssStyles> _parseAllCssProperties(
    LinkedHashMap<Object, String> attributes,
  ) async {
    final styleString = attributes["style"];
    final cssMap = _cssStringToMap(styleString);

    return CssStyles(
      width: _parseSizeProperty(cssMap["width"]),
      height: _parseSizeProperty(cssMap["height"]),
      display: cssMap["display"],
      margin: _parseSpacingProperty(cssMap, "margin"),
      padding: _parseSpacingProperty(cssMap, "padding"),
      fontSize: _parseFontSize(cssMap["font-size"] ?? ""),
      fontWeight: _parseFontWeightProp(cssMap["font-weight"]),
      fontStyle: _parseFontStyleProperty(cssMap["font-style"]),
      fontFamily: cssMap["font-family"],
      color: ColorExtension.parse(cssMap["color"] ?? "") ?? PdfColors.black,
      textAlign: _parseTextAlign(cssMap["text-align"]),
      textDecoration: _parseTextDecorationProperty(cssMap["text-decoration"]),
      backgroundColor: ColorExtension.parse(cssMap["background-color"] ?? "") ??
          PdfColors.white,
      border: _parseBorderProperty(cssMap, "border"),
      borderTop: _parseBorderProperty(cssMap, "border-top"),
      borderRight: _parseBorderProperty(cssMap, "border-right"),
      borderBottom: _parseBorderProperty(cssMap, "border-bottom"),
      borderLeft: _parseBorderProperty(cssMap, "border-left"),
      borderCollapse: cssMap["border-collapse"],
      borderSpacing: _parseSizeProperty(cssMap["border-spacing"]),
      verticalAlign: cssMap["vertical-align"],
      colspan: int.tryParse(attributes["colspan"] ?? ""),
      rowspan: int.tryParse(attributes["rowspan"] ?? ""),
      listStyleType: cssMap["list-style-type"],
    );
  }

  /// Parse size properties
  double? _parseSizeProperty(String? value) {
    if (value == null) return null;
    return _parseFontSize(value);
  }

  /// Parse spacing property with CSS shorthand support
  EdgeInsets? _parseSpacingProperty(
      Map<String, String> cssMap, String property) {
    final top = _parseSizeProperty(cssMap["$property-top"]);
    final right = _parseSizeProperty(cssMap["$property-right"]);
    final bottom = _parseSizeProperty(cssMap["$property-bottom"]);
    final left = _parseSizeProperty(cssMap["$property-left"]);

    if (top != null || right != null || bottom != null || left != null) {
      return EdgeInsets.only(
        top: top ?? 0,
        right: right ?? 0,
        bottom: bottom ?? 0,
        left: left ?? 0,
      );
    }

    final value = cssMap[property];
    if (value != null) {
      final parts = value.trim().split(RegExp(r'\s+'));
      final values = parts.map(_parseFontSize).whereType<double>().toList();
      if (values.isEmpty) return null;

      switch (values.length) {
        case 1:
          return EdgeInsets.all(values[0]);
        case 2:
          return EdgeInsets.symmetric(
              vertical: values[0], horizontal: values[1]);
        case 3:
          return EdgeInsets.only(
              top: values[0],
              left: values[1],
              right: values[1],
              bottom: values[2]);
        case 4:
          return EdgeInsets.fromLTRB(
              values[3], values[0], values[1], values[2]);
      }
    }
    return null;
  }

  /// Parse font-weight property
  FontWeight? _parseFontWeightProp(String? value) {
    if (value == null) return null;
    if (value == "bold" || value == "bolder") return FontWeight.bold;
    if (value == "normal") return FontWeight.normal;
    final weight = int.tryParse(value);
    return (weight != null && weight > 500) ? FontWeight.bold : null;
  }

  /// Parse font-style property
  FontStyle? _parseFontStyleProperty(String? value) {
    if (value == null) return null;
    return value.toLowerCase() == "italic" || value.toLowerCase() == "oblique"
        ? FontStyle.italic
        : (value == "normal" ? FontStyle.normal : null);
  }

  /// Parse text-align property
  TextAlign? _parseTextAlign(String? value) {
    return value == null ? null : _alignText(value);
  }

  /// Parse text-decoration property
  TextDecoration? _parseTextDecorationProperty(String? value) {
    if (value == null) return null;
    if (value.contains("underline")) return TextDecoration.underline;
    if (value.contains("line-through")) return TextDecoration.lineThrough;
    if (value == "none") return TextDecoration.none;
    return null;
  }

  /// Parse border property
  BorderInfo? _parseBorderProperty(
      Map<String, String> cssMap, String property) {
    final borderValue = cssMap[property];
    if (borderValue != null) return BorderInfo.fromString(borderValue);

    final widthValue = cssMap["$property-width"];
    final styleValue = cssMap["$property-style"];
    final colorValue = cssMap["$property-color"];

    if (widthValue != null || styleValue != null || colorValue != null) {
      return BorderInfo(
        width: _parseSizeProperty(widthValue) ?? 1.0,
        color: ColorExtension.parse(colorValue ?? "") ?? PdfColors.black,
        style: _parseBorderStyle(styleValue),
      );
    }
    return null;
  }

  /// Parse border-style value
  BorderStyle _parseBorderStyle(String? value) {
    if (value == null) return BorderStyle.solid;
    switch (value.toLowerCase()) {
      case "dashed":
        return BorderStyle.dashed;
      case "dotted":
        return BorderStyle.dotted;
      case "none":
        return BorderStyle.none;
      default:
        return BorderStyle.solid;
    }
  }
}
