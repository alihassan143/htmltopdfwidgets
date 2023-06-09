import 'dart:collection';
import 'dart:ui';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:htmltopdfwidgets/src/attributes.dart';
import 'package:printing/printing.dart';

import '../htmltopdfwidgets.dart';

class WidgetsHTMLDecoder {
  final Font? font;
  final List<Font> fontFallback;
  const WidgetsHTMLDecoder({this.font, required this.fontFallback});

  Future<List<Widget>> convert(
    String html,
  ) async {
    final emoji = await PdfGoogleFonts.notoColorEmoji();
    fontFallback.add(emoji);
    final document = parse(html);
    final body = document.body;
    if (body == null) {
      return [];
    }
    List<Widget> nodes = await _parseElement(
      body.nodes,
    );

    return nodes;
  }

  Future<List<Widget>> _parseElement(
    Iterable<dom.Node> domNodes,
  ) async {
    final List<Widget> delta = [];
    final result = <Widget>[];
    for (final domNode in domNodes) {
      if (domNode is dom.Element) {
        final localName = domNode.localName;
        if (HTMLTags.formattingElements.contains(localName)) {
          final attributes = await _parserFormattingElementAttributes(domNode);

          result.add(Text(domNode.text, style: attributes));
        } else if (HTMLTags.specialElements.contains(localName)) {
          result.addAll(
            await _parseSpecialElements(
              domNode,
              type: BuiltInAttributeKey.bulletedList,
            ),
          );
        }
      } else if (domNode is dom.Text) {
        delta.add(Text(domNode.text,
            style: TextStyle(font: font, fontFallback: fontFallback)));
      } else {
        assert(false, 'Unknown node type: $domNode');
      }
    }
    if (delta.isNotEmpty) {
      result.add(Wrap(children: delta));
    }
    return result;
  }

  Future<Iterable<Widget>> _parseSpecialElements(
    dom.Element element, {
    required String type,
  }) async {
    final localName = element.localName;
    switch (localName) {
      case HTMLTags.h1:
        return [await _parseHeadingElement(element, level: 1)];
      case HTMLTags.h2:
        return [await _parseHeadingElement(element, level: 2)];
      case HTMLTags.h3:
        return [await _parseHeadingElement(element, level: 3)];
      case HTMLTags.unorderedList:
        return await _parseUnOrderListElement(element);
      case HTMLTags.orderedList:
        return await _parseOrderListElement(element);
      case HTMLTags.list:
        return await _parseListElement(
          element,
          type: type,
        );
      case HTMLTags.paragraph:
        return [await _parseParagraphElement(element)];
      case HTMLTags.blockQuote:
        return await _parseBlockQuoteElement(element);
      case HTMLTags.image:
        return [await _parseImageElement(element)];
      default:
        return [await _parseParagraphElement(element)];
    }
  }

  Text paragraphNode({required String text}) {
    return Text(text);
  }

  Future<TextStyle> _parserFormattingElementAttributes(
      dom.Element element) async {
    final localName = element.localName;

    TextStyle attributes = TextStyle(fontFallback: fontFallback, font: font);
    final List<TextDecoration> decoration = [];
    switch (localName) {
      case HTMLTags.bold:
        attributes = attributes.copyWith(fontWeight: FontWeight.bold);
        break;
      case HTMLTags.strong:
        attributes = attributes.copyWith(fontWeight: FontWeight.bold);
        break;
      case HTMLTags.em:
        attributes = attributes.copyWith(fontStyle: FontStyle.italic);
        break;
      case HTMLTags.italic:
        attributes = attributes.copyWith(fontStyle: FontStyle.italic);
        break;
      case HTMLTags.underline:
        decoration.add(TextDecoration.underline);
        break;
      case HTMLTags.del:
        decoration.add(TextDecoration.lineThrough);

        break;

      case HTMLTags.span:
        final deltaAttributes = _getDeltaAttributesFromHtmlAttributes(
          element.attributes,
        );
        attributes = attributes.merge(deltaAttributes);
        if (deltaAttributes.decoration != null) {
          decoration.add(deltaAttributes.decoration!);
        }
        break;
      case HTMLTags.anchor:
        final href = element.attributes['href'];
        if (href != null) {
          decoration.add(TextDecoration.underline);
        }
        break;
      case HTMLTags.paragraph:
        attributes = attributes;
        break;
      case HTMLTags.code:
        attributes = attributes;
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

    return attributes.copyWith(decoration: TextDecoration.combine(decoration));
  }

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
    return RichText(
        text: TextSpan(
            children: delta,
            style: TextStyle(
                fontSize: await getHeadingSize(level),
                fontWeight: FontWeight.bold)));
  }

  static Future<double> getHeadingSize(int level) async {
    if (level == 1) {
      return 32;
    } else if (level == 2) {
      return 28;
    } else if (level == 3) {
      return 22;
    } else {
      return 20;
    }
  }

  Future<List<Widget>> _parseBlockQuoteElement(dom.Element element) async {
    final result = <Widget>[];
    for (final child in element.children) {
      result.addAll(
          await _parseListElement(child, type: BuiltInAttributeKey.quote));
    }
    return result;
  }

  Future<Iterable<Widget>> _parseUnOrderListElement(dom.Element element) async {
    final result = <Widget>[];
    for (final child in element.children) {
      result.addAll(await _parseListElement(child,
          type: BuiltInAttributeKey.bulletedList));
    }
    return result;
  }

  Future<Iterable<Widget>> _parseOrderListElement(dom.Element element) async {
    final result = <Widget>[];
    for (var i = 0; i < element.children.length; i++) {
      final child = element.children[i];
      result.addAll(await _parseListElement(child,
          type: BuiltInAttributeKey.numberList, index: i + 1));
    }
    return result;
  }

  Future<Iterable<Widget>> _parseListElement(
    dom.Element element, {
    required String type,
    int? index,
  }) async {
    final delta = await _parseDeltaElement(element);
    if (type == BuiltInAttributeKey.bulletedList) {
      return [buildBulletwidget(delta)];
    } else if (type == BuiltInAttributeKey.numberList) {
      return [buildNumberwdget(delta, index: index!)];
    } else if (type == BuiltInAttributeKey.quote) {
      return [buildQuotewidget(delta)];
    } else {
      return [delta];
    }
  }

  Future<Widget> _parseParagraphElement(dom.Element element) async {
    final delta = await _parseDeltaElement(element);
    return delta;
  }

  Future<Widget> _parseImageElement(dom.Element element) async {
    final src = element.attributes["src"];
    try {
      if (src != null) {
        final netImage = await networkImage(src);
        return Image(netImage);
      } else {
        return Text("");
      }
    } catch (e) {
      return Text("");
    }
  }

  Future<Widget> _parseDeltaElement(dom.Element element) async {
    final delta = <Widget>[];
    final children = element.nodes.toList();
    for (final child in children) {
      if (child is dom.Element) {
        final attributes = await _parserFormattingElementAttributes(child);

        delta.add(Text(child.text, style: attributes));
      } else {
        delta.add(Text(child.text ?? "",
            style: TextStyle(font: font, fontFallback: fontFallback)));
      }
    }
    return Wrap(children: delta);
  }

  static Map<String, String> _cssStringToMap(String? cssString) {
    final result = <String, String>{};
    if (cssString == null) {
      return result;
    }

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

  static TextStyle _getDeltaAttributesFromHtmlAttributes(
      LinkedHashMap<Object, String> htmlAttributes) {
    TextStyle style = const TextStyle();
    final styleString = htmlAttributes["style"];
    final cssMap = _cssStringToMap(styleString);

    final fontWeightStr = cssMap["font-weight"];
    if (fontWeightStr != null) {
      if (fontWeightStr == "bold") {
        style = style.copyWith(fontWeight: FontWeight.bold);
      } else {
        int? weight = int.tryParse(fontWeightStr);
        if (weight != null && weight > 500) {
          style = style.copyWith(fontWeight: FontWeight.bold);
        }
      }
    }

    final textDecorationStr = cssMap["text-decoration"];
    if (textDecorationStr != null) {
      style = style.merge(_assignTextDecorations(style, textDecorationStr));
    }

    final backgroundColorStr = cssMap["background-color"];
    final backgroundColor = backgroundColorStr == null
        ? null
        : ColorExtension.tryFromRgbaString(backgroundColorStr);
    if (backgroundColor != null) {
      style = style.copyWith(color: PdfColor.fromInt(backgroundColor.value));
    }

    if (cssMap["font-style"] == "italic") {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }

    return style;
  }

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

  Widget defaultIndex(int index) {
    return Container(
      width: 20,
      padding: const EdgeInsets.only(right: 5.0),
      child: Text('$index.',
          style: TextStyle(font: font, fontFallback: fontFallback)),
    );
  }

  Widget buildNumberwdget(Widget childValue, {required int index}) {
    Widget child = Container(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          defaultIndex(index),
          Flexible(child: childValue),
        ],
      ),
    );
    return child;
  }

  Widget buildQuotewidget(
    Widget childValue,
  ) {
    Widget child = Container(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 20,
              height: 20,
              child: VerticalDivider(color: PdfColors.black)),
          Flexible(child: childValue),
        ],
      ),
    );
    return child;
  }

  Widget buildBulletwidget(Widget childValue) {
    Widget child = Container(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _BulletedListIcon(),
          Flexible(child: childValue),
        ],
      ),
    );
    return child;
  }
}

class _BulletedListIcon extends StatelessWidget {
  _BulletedListIcon();

  @override
  Widget build(Context context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: Center(
            child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: PdfColors.black))),
      ),
    );
  }
}

class HTMLTags {
  static const h1 = 'h1';
  static const h2 = 'h2';
  static const h3 = 'h3';
  static const orderedList = 'ol';
  static const unorderedList = 'ul';
  static const list = 'li';
  static const paragraph = 'p';
  static const image = 'img';
  static const anchor = 'a';
  static const italic = 'i';
  static const em = 'em';
  static const bold = 'b';
  static const underline = 'u';
  static const del = 'del';
  static const strong = 'strong';
  static const checkbox = 'input';
  static const span = 'span';
  static const code = 'code';
  static const blockQuote = 'blockquote';
  static const div = 'div';
  static const divider = 'hr';

  static List<String> formattingElements = [
    HTMLTags.anchor,
    HTMLTags.italic,
    HTMLTags.em,
    HTMLTags.bold,
    HTMLTags.underline,
    HTMLTags.del,
    HTMLTags.strong,
    HTMLTags.span,
    HTMLTags.code,
  ];

  static List<String> specialElements = [
    HTMLTags.h1,
    HTMLTags.h2,
    HTMLTags.h3,
    HTMLTags.div,
    HTMLTags.unorderedList,
    HTMLTags.orderedList,
    HTMLTags.list,
    HTMLTags.paragraph,
    HTMLTags.blockQuote,
    HTMLTags.checkbox,
    HTMLTags.image
  ];

  static bool isTopLevel(String tag) {
    return tag == h1 ||
        tag == h2 ||
        tag == h3 ||
        tag == checkbox ||
        tag == paragraph ||
        tag == div ||
        tag == blockQuote;
  }
}

extension ColorExtension on Color {
  /// Try to parse the `rgba(red, greed, blue, alpha)`
  /// from the string.
  static Color? tryFromRgbaString(String colorString) {
    final reg = RegExp(r'rgba\((\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)');
    final match = reg.firstMatch(colorString);
    if (match == null) {
      return null;
    }

    if (match.groupCount < 4) {
      return null;
    }
    final redStr = match.group(1);
    final greenStr = match.group(2);
    final blueStr = match.group(3);
    final alphaStr = match.group(4);

    final red = redStr != null ? int.tryParse(redStr) : null;
    final green = greenStr != null ? int.tryParse(greenStr) : null;
    final blue = blueStr != null ? int.tryParse(blueStr) : null;
    final alpha = alphaStr != null ? int.tryParse(alphaStr) : null;

    if (red == null || green == null || blue == null || alpha == null) {
      return null;
    }

    return Color.fromARGB(alpha, red, green, blue);
  }

  String toRgbaString() {
    return 'rgba($red, $green, $blue, $alpha)';
  }
}
