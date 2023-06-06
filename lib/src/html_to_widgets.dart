import 'dart:collection';
import 'dart:convert';
import 'dart:ui';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:htmltopdfwidgets/src/attributes.dart';
import 'package:printing/printing.dart';

import '../htmltopdfwidgets.dart';

class WidgetsHTMLDecoder extends Converter<String, List<Widget>> {
  WidgetsHTMLDecoder();

  @override
  List<Widget> convert(String input) {
    final document = parse(input);
    final body = document.body;
    if (body == null) {
      return [];
    }
    List<Widget> nodes = [];
    _parseElement(body.nodes).then((value) => {nodes.addAll(value)});
    return nodes;
  }

  Future<List<Widget>> _parseElement(Iterable<dom.Node> domNodes) async {
    List<TextSpan> delta = [];
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
        delta.add(TextSpan(text: domNode.text));
      } else {
        assert(false, 'Unknown node type: $domNode');
      }
    }
    if (delta.isNotEmpty) {
      result.add(RichText(text: TextSpan(children: delta)));
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
        //if list than default type will be blulleted because paragraph node will not be the part of the list
        return await _parseListElement(
          element,
          type: type,
        );
      case HTMLTags.paragraph:
        return [await _parseParagraphElement(element)];
      case HTMLTags.blockQuote:
        return _parseBlockQuoteElement(element);
      case HTMLTags.image:
        return [await _parseImageElement(element)];
      default:
        return [paragraphNode(text: element.text)];
    }
  }

  Text paragraphNode({required String text}) {
    return Text(text);
  }

  Future<TextStyle> _parserFormattingElementAttributes(
      dom.Element element) async {
    final localName = element.localName;
    TextStyle attributes = const TextStyle();
    switch (localName) {
      case HTMLTags.bold:
        attributes = attributes.copyWith(fontWeight: FontWeight.bold);
        break;
      case HTMLTags.strong:
        attributes = attributes.copyWith(fontWeight: FontWeight.bold);
        break;
      case HTMLTags.em:
        attributes = attributes.copyWith(
            fontItalic: await PdfGoogleFonts.openSansItalic());
        break;
      case HTMLTags.italic:
        attributes = attributes.copyWith(
            fontItalic: await PdfGoogleFonts.openSansItalic());
        break;
      case HTMLTags.underline:
        attributes = attributes.copyWith(decoration: TextDecoration.underline);
        break;
      case HTMLTags.del:
        attributes =
            attributes.copyWith(decoration: TextDecoration.lineThrough);
        break;

      case HTMLTags.span:
        final deltaAttributes = _getDeltaAttributesFromHtmlAttributes(
          element.attributes,
        );
        if (deltaAttributes != null) {
          attributes = attributes.merge(deltaAttributes);
        }
        break;
      case HTMLTags.anchor:
        final href = element.attributes['href'];
        if (href != null) {
          attributes = attributes.copyWith(
            decoration: TextDecoration.underline,
            color: PdfColors.blue,
          );
        }
        break;
      case HTMLTags.paragraph:
        attributes = attributes;
        break;
      default:
        assert(false, 'Unknown formatting element: $element');
        break;
    }
    for (final child in element.children) {
      final nattributes = await _parserFormattingElementAttributes(child);
      attributes = attributes.merge(nattributes);
    }
    return attributes;
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
        delta.add(TextSpan(
            text: child.text,
            style: attributes.copyWith(
                fontSize: await getHeadingSize(level),
                fontWeight: FontWeight.bold)));
      } else {
        delta.add(TextSpan(text: child.text));
      }
    }
    return RichText(text: TextSpan(children: delta));
  }

  Future<double> getHeadingSize(int level) async {
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

    if (src != null) {
      final netImage = await networkImage(src);
      return Image(netImage);
    } else {
      return Text("");
    }
  }

  Future<Widget> _parseDeltaElement(dom.Element element) async {
    final delta = <TextSpan>[];
    final children = element.nodes.toList();
    for (final child in children) {
      if (child is dom.Element) {
        final attributes = await _parserFormattingElementAttributes(child);
        delta.add(TextSpan(text: child.text, style: attributes));
      } else {
        delta.add(TextSpan(text: child.text));
      }
    }
    return RichText(text: TextSpan(children: delta));
  }

  Map<String, String> _cssStringToMap(String? cssString) {
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

  TextStyle? _getDeltaAttributesFromHtmlAttributes(
      LinkedHashMap<Object, String> htmlAttributes) {
    var style = const TextStyle();
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
      _assignTextDecorations(style, textDecorationStr);
    }

    final backgroundColorStr = cssMap["background-color"];
    final backgroundColor = backgroundColorStr == null
        ? null
        : ColorExtension.tryFromRgbaString(backgroundColorStr);
    if (backgroundColor != null) {
      style = style.copyWith(color: PdfColor.fromInt(backgroundColor.value));
      // attrs[BuiltInAttributeKey.backgroundColor] =
      //     '0x${backgroundColor.value.toRadixString(16)}';
    }

    if (cssMap["font-style"] == "italic") {
      style = style.copyWith(fontStyle: FontStyle.italic);
      // attrs[BuiltInAttributeKey.italic] = true;
    }

    return style;
  }

  void _assignTextDecorations(TextStyle style, String decorationStr) {
    final decorations = decorationStr.split(" ");
    for (final d in decorations) {
      if (d == "line-through") {
        style = style.copyWith(decoration: TextDecoration.lineThrough);
        // attrs[BuiltInAttributeKey.strike] = true;
      } else if (d == "underline") {
        style = style.copyWith(decoration: TextDecoration.underline);
      }
    }
  }
}

Widget defaultIndex(int index) {
  return Container(
    width: 20,
    padding: const EdgeInsets.only(right: 5.0),
    child: Text(
      '$index.',
    ),
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

class _BulletedListIcon extends StatelessWidget {
  _BulletedListIcon();

  static final bulletedListIcons = [
    '●',
    '◯',
    '□',
  ];

  String get icon => bulletedListIcons[0];

  @override
  Widget build(Context context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: Center(
          child: Text(
            icon,
            textScaleFactor: 0.5,
          ),
        ),
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
    HTMLTags.unorderedList,
    HTMLTags.orderedList,
    HTMLTags.list,
    HTMLTags.paragraph,
    HTMLTags.blockQuote,
    HTMLTags.checkbox,
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
